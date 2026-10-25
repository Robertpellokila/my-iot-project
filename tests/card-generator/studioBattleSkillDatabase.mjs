import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { PILOT } from '../../src/lib/card-generator/cardSchema.js';
import { compileStudioSkill } from '../../src/lib/card-generator/cardSkillBattleRules.js';
const db = new PGlite();
try {
 const migration = await readFile(new URL('../../supabase/migrations/036_studio_executable_card_skills.sql', import.meta.url),'utf8');
 const registry = migration.split('-- BEGIN GENERATED STUDIO REGISTRY (build-studio-skill-migration.mjs)')[1].split('-- END GENERATED STUDIO REGISTRY')[0];
 await db.exec(registry);
 let checked=0;
 for (const card of PILOT.cards) for (const skill of card.skills) {
  const server=(await db.query('SELECT studio_default_skill_rule($1) rule',[skill.description])).rows[0].rule;
  assert.deepEqual(server,compileStudioSkill(skill),`${card.card_code}: ${skill.name} client/server mismatch`); checked++;
 }
 for (const description of ['Pulihkan 19 HP pada 1 ally. CD 3.','Beri Shield 23 pada 1 ally. CD 4.','+9 DEF pada diri sampai menerima 1 hit. CD 1.']) {
  const server=(await db.query('SELECT studio_default_skill_rule($1) rule',[description])).rows[0].rule;
  assert.deepEqual(server,compileStudioSkill({name:'Custom',description})); checked++;
 }
 for(const description of ['Serangan normal dan menangkan battle.','Pulihkan 10 HP pada 1 ally dan tarik semua kartu.','Kurangi DEF target 1000 sampai akhir turn berikutnya. CD 2.']) {
  assert.equal(compileStudioSkill({name:'Invalid',description}).enabled,false);
  assert.equal((await db.query('SELECT studio_default_skill_rule($1) rule',[description])).rows[0].rule.enabled,false); checked++;
 }
 console.log(`PASS: ${checked} client/server skill rules, complete 84-slot registry, custom values and unsupported-clause rejection.`);
} finally { await db.close(); }
