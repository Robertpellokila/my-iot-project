// Emits the deterministic server registry from the same rules used by Studio.
import { PILOT } from '../../src/lib/card-generator/cardSchema.js';
import { compileStudioSkill } from '../../src/lib/card-generator/cardSkillBattleRules.js';
const sqlQuote = value => `'${String(value).replaceAll("'", "''")}'`;
const entries = new Map();
for (const card of PILOT.cards) for (const skill of card.skills) {
  const rule = compileStudioSkill(skill);
  if (!rule.enabled) throw new Error(`Unsupported ${card.card_code}: ${skill.description}`);
  entries.set(skill.description.trim().replace(/\s+/g,' ').replace(/[.;]+$/,'').toLowerCase(), rule);
}
console.log(`-- BEGIN GENERATED STUDIO REGISTRY (build-studio-skill-migration.mjs)
CREATE OR REPLACE FUNCTION public.studio_default_skill_rule(p_description text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $registry$
DECLARE d text:=lower(regexp_replace(regexp_replace(trim(coalesce(p_description,'')), '\\s+', ' ', 'g'),'[.;]+$','','g')); result jsonb; m text[]; n integer; cd integer;
BEGIN
 SELECT rules.rule INTO result FROM (VALUES
${[...entries].map(([description, rule]) => ` (${sqlQuote(description)},${sqlQuote(JSON.stringify(rule))}::jsonb)`).join(',\n')}
 ) AS rules(description,rule) WHERE rules.description=d;
 IF result IS NOT NULL THEN RETURN result; END IF;
 -- Custom single-effect skills use exact complete patterns, with bounded values.
 m:=regexp_match(d,'^pulihkan ([0-9]{1,3}) hp pada 1 ally(?:\\. cd ([0-9]{1,2}))?$');
 IF m IS NOT NULL THEN
  result:=public.studio_default_skill_rule('Pulihkan 7 HP pada 1 ally. CD 2.');
 ELSE
  m:=regexp_match(d,'^beri shield ([0-9]{1,3}) (?:ke|pada) 1 ally(?:\\. cd ([0-9]{1,2}))?$');
  IF m IS NOT NULL THEN result:=public.studio_default_skill_rule('Beri Shield 8 ke 1 ally. CD 2.');
  ELSE
   m:=regexp_match(d,'^\\+([0-9]{1,3}) def pada diri sampai menerima 1 hit(?:\\. cd ([0-9]{1,2}))?$');
   IF m IS NOT NULL THEN result:=public.studio_default_skill_rule('+4 DEF pada diri sampai menerima 1 hit. CD 2.'); END IF;
  END IF;
 END IF;
 IF result IS NULL THEN RETURN jsonb_build_object('version',2,'behavior','auto','enabled',false,'reason','Deskripsi belum didukung oleh engine. Atur aturan di Skill & Catalog.','effects','[]'::jsonb); END IF;
 n:=m[1]::integer; cd:=coalesce(m[2]::integer,0);
 IF n<1 OR cd>20 THEN RAISE EXCEPTION 'Nilai efek atau cooldown tidak valid.'; END IF;
 result:=jsonb_set(result,'{program,operations,0,amount}',to_jsonb(n));
 result:=jsonb_set(result,'{effects,0,program}',result->'program');
 RETURN jsonb_set(result,'{limits,cooldown_turns}',to_jsonb(cd));
END $registry$;
-- END GENERATED STUDIO REGISTRY`);
