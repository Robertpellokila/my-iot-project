// Runs the real SQL effect executor in an isolated Postgres database. Does not
// replace effect handlers with mocks. API credentials/AP authorization are
// covered separately by skillDatabase.mjs; this suite asserts mechanical results.
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
import { PGlite } from '@electric-sql/pglite';
import { PILOT } from '../../src/lib/card-generator/cardSchema.js';
import { compileStudioSkill } from '../../src/lib/card-generator/cardSkillBattleRules.js';
const db = new PGlite();
const migration = name => readFile(new URL(`../../supabase/migrations/${name}`, import.meta.url), 'utf8');
function sqlFunction(sql, name) {
  const start = sql.indexOf(`CREATE OR REPLACE FUNCTION public.${name}(`);
  assert.ok(start >= 0, `SQL function ${name} exists`);
  const body = sql.slice(start), tag = body.match(/AS\s+(\$\w*\$)/i)[1];
  return body.slice(0, body.indexOf(tag + ';', body.indexOf(tag) + tag.length) + tag.length + 1);
}
let scenarios = 0;
try {
  await db.exec(await readFile(new URL('./schema.sql', import.meta.url), 'utf8'));
  await db.exec(`ALTER TABLE battle_sessions ADD COLUMN player1_owner_turn int DEFAULT 1, ADD COLUMN player2_owner_turn int DEFAULT 0;
    CREATE TABLE battle_status_effects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), battle_id uuid, source_player text, source_card_id uuid, target_player text, target_card_id uuid, scope text, status_key text, value jsonb, stacks int, max_stacks int, active boolean DEFAULT true, remaining_turns int, remaining_rounds int, consume_on text[], metadata jsonb DEFAULT '{}', created_at timestamptz DEFAULT now());
    CREATE FUNCTION tcg_try_uuid(text) RETURNS uuid LANGUAGE plpgsql AS $$ BEGIN RETURN $1::uuid; EXCEPTION WHEN others THEN RETURN NULL; END $$;`);
  const elemental = await migration('006_elemental_one_turn_and_question_fallback.sql');
  await db.exec(sqlFunction(elemental, 'tcg_status_rule'));
  const combo = await migration('024_configurable_active_only_tcg_combos.sql');
  await db.exec(sqlFunction(combo, 'tcg_battle_card_can_attack'));
  await db.exec(sqlFunction(combo, 'tcg_apply_combo_status'));
  const sql = await migration('036_studio_executable_card_skills.sql');
  // The pre-Studio action guard lives in the historical DB baseline. This
  // fixture has no legacy freeze/stun; exercise the real Studio guard below.
  await db.exec('CREATE FUNCTION tcg_card_block_pre_studio(uuid,uuid,text) RETURNS text LANGUAGE sql AS $$ SELECT NULL::text $$;');
  await db.exec(sqlFunction(sql, 'tcg_card_action_block_reason'));
  await db.exec(sql.slice(sql.indexOf('CREATE OR REPLACE FUNCTION public.tcg_studio_owner_turn'), sql.indexOf('DO $patch$')));
  await db.exec(sql.slice(sql.indexOf('CREATE OR REPLACE FUNCTION public.tcg_studio_restore_status'), sql.indexOf('-- BEGIN GENERATED STUDIO REGISTRY')));
  const status = async (f, target, key, amount = 1, expiry = 'next_end') => db.query('SELECT tcg_studio_status($1,$2,$3,$4,$5,$6)', [f.b, f.src, target, key, amount, expiry]);
  async function setup() {
    const f = Object.fromEntries(['b', 'src', 'enemy', 'enemy2', 'ally', 'bench', 'dead'].map(k => [k, randomUUID()]));
    await db.query(`INSERT INTO battle_sessions(id,ruleset,status,current_turn,round,turn_index,max_bench,max_attacks_per_card,player1_hp,player2_hp,player1_max_hp,player2_max_hp,player1_skill,player2_skill) VALUES($1,'tcg_v1','battle','p1',1,1,4,1,200,200,200,200,0,0)`, [f.b]);
    for (const [key, player, zone, hp] of [['src','p1','active',150],['enemy','p2','active',200],['enemy2','p2','active',200],['ally','p1','active',50],['bench','p1','bench',50],['dead','p1','graveyard',0]]) {
      await db.query(`INSERT INTO battle_cards(id,battle_id,player,name,zone,slot,current_hp,hp,base_hp,attack,defense,exhausted,card_kind,origin_type,battle_metadata) VALUES($1,$2,$3,$4,$5,$6,$7,200,200,30,10,false,'normal','rfid','{}')`, [f[key], f.b, player, key, zone, zone === 'active' ? (key === 'ally' || key === 'enemy2' ? 2 : 1) : null, hp]);
    }
    return f;
  }
  const row = async id => (await db.query('SELECT * FROM battle_cards WHERE id=$1', [id])).rows[0];
  const statuses = async (f, id, key) => (await db.query('SELECT * FROM battle_status_effects WHERE battle_id=$1 AND target_card_id=$2 AND status_key=$3 AND active', [f.b, id, key])).rows;
  const execute = async (f, program, extra = {}) => {
    const target = program.target === 'self_card' ? f.src : program.target === 'enemy_active' ? f.enemy : program.target === 'ally_graveyard' ? f.dead : f.ally;
    const context = { target_card_id: target, bench_card_id: f.bench, ...(program.max_targets === 2 ? { target_card_ids: [f.enemy, f.enemy2] } : {}), ...extra };
    return (await db.query('SELECT tcg_execute_studio_skill($1,$2,$3,$4,$5) r', [f.b, 'p1', f.src, program, context])).rows[0].r;
  };
  async function exercise(skill, label) {
    const p = skill.effects[0].program;
    for (const choice of p.choices?.length ? p.choices : [{ id: '', operations: p.operations }]) {
      const f = await setup();
      const tid = p.target === 'self_card' ? f.src : p.target === 'enemy_active' ? f.enemy : p.target === 'ally_graveyard' ? f.dead : f.ally;
      await status(f, f.enemy, 'root');
      await status(f, f.enemy, 'burn');
      await status(f, f.ally, 'burn');
      await status(f, f.src, 'studio_shield', 5);
      await db.query("UPDATE battle_cards SET battle_metadata=battle_metadata||'{\"studio_switched_turn\":1}' WHERE id IN ($1,$2)", [f.src, f.ally]);
      const before = await row(tid);
      const result = await execute(f, p, { skill_option: choice.id });
      assert.equal(result.ok, true, label);
      assert.ok(result.effect_count > 0, `${label} executes a real effect`);
      for (const op of choice.operations) {
        const id = op.target === 'self' ? f.src : tid;
        const after = await row(id), amount = Number(op.amount ?? 0);
        if (op.type === 'attack') {
          // The fixture satisfies every supported bonus condition, independently
          // of the implementation's condition result.
          assert.equal(after.current_hp, before.current_hp - Math.max(1, Math.round(30 * op.multiplier) + amount - 10), label);
          if (p.max_targets === 2) assert.equal((await row(f.enemy2)).current_hp, after.current_hp, `${label} second target`);
          assert.equal((await row(f.src)).attacks_this_turn, 1);
        } else if (op.type === 'heal') assert.equal(after.current_hp, Math.min(200, before.current_hp + amount), label);
        else if (op.type === 'cleanse') assert.equal((await statuses(f, id, 'burn')).length, 0, label);
        else if (op.type === 'switch') { assert.equal(after.zone, 'bench'); assert.equal((await row(f.bench)).zone, 'active'); }
        else if (op.type === 'revive') { assert.equal(after.zone, 'bench'); assert.equal(after.current_hp, Math.round(200 * amount)); assert.equal((await statuses(f, id, 'studio_revival_lock')).length, 1); }
        else if (op.type === 'burn') assert.equal((await statuses(f, id, 'burn')).length, 1);
        else if (op.type === 'team_defense') {
          for (const key of ['src','ally','bench']) assert.equal((await row(f[key])).defense, 10 + amount, label);
        } else {
          const key = op.type === 'root' ? 'root' : `studio_${op.type}`;
          assert.equal((await statuses(f, id, key)).length, 1, `${label} ${key}`);
          if (op.type === 'attack_buff') assert.equal(after.attack, 30 + amount);
          if (op.type === 'attack_debuff') assert.equal(after.attack, Math.max(0, 30 - amount));
          if (op.type === 'defense_debuff') assert.equal(after.defense, Math.max(0, 10 - amount));
          if (op.type === 'defense') assert.equal(after.defense, 10 + amount);
          if (op.type === 'delayed_heal') {
            await db.query("UPDATE battle_sessions SET player1_owner_turn=2,current_turn='p2' WHERE id=$1", [f.b]);
            await db.query("UPDATE battle_sessions SET current_turn='p1' WHERE id=$1", [f.b]);
            await db.query("UPDATE battle_sessions SET current_turn='p2' WHERE id=$1", [f.b]);
            const immediate = choice.operations.find(o => o.type === 'heal')?.amount ?? 0;
            assert.equal((await row(id)).current_hp, Math.min(200, before.current_hp + immediate + amount), label);
          }
        }
      }
      scenarios++;
    }
  }
  for (const card of PILOT.cards) for (const skill of card.skills) await exercise(compileStudioSkill(skill), `${card.card_code} ${skill.name}`);
  console.log(`PASS: ${scenarios} canonical skill/choice executions across all 84 slots, actual SQL HP/stat/status/zone results.`);
  if (process.argv[2]) {
    const snapshot = JSON.parse(await readFile(process.argv[2], 'utf8'));
    const pilots = new Set(snapshot.cards.filter(c => !c.uid && c.metadata?.studio_card?.source_pilot_code).map(c => c.id));
    const ids = new Set(snapshot.links.filter(l => pilots.has(l.game_card_id)).map(l => l.special_skill_id));
    const saved = snapshot.skills.filter(s => ids.has(s.id) && s.is_active && s.effects?.[0]?.type === 'studio_skill');
    const start = scenarios;
    for (const skill of saved) await exercise(skill, `Saved ${skill.name}`);
    console.log(`PASS: ${scenarios-start} executions from ${saved.length} current saved pilot skills; inactive/empty skills excluded explicitly.`);
  }
  const necro = compileStudioSkill(PILOT.cards.flatMap(c => c.skills).find(s => s.name === 'Necro Recall')).program;
  for (const alteration of ["is_fusion_result=true", "fusion_consumed=true", "origin_type='fusion'", "card_kind='fusion'"]) {
    const f = await setup(); await db.query(`UPDATE battle_cards SET ${alteration} WHERE id=$1`, [f.dead]);
    await assert.rejects(execute(f, necro), /Base non-Fusion/); assert.equal((await row(f.dead)).zone, 'graveyard');
  }
  const f = await setup(); await db.query('UPDATE battle_sessions SET max_bench=1 WHERE id=$1', [f.b]);
  await assert.rejects(execute(f, necro), /Bench penuh/);
  console.log('PASS: Necro rejects Fusion, consumed cards and full Bench without reviving them.');
} catch (error) { console.error(error.message, error.where ?? '', error.position ?? ''); process.exitCode = 1; }
finally { await db.close(); }
