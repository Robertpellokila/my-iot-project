import { computed, onUnmounted, provide, ref, watch } from 'vue';
import { supabase } from '../../lib/supabase';
import { battleCardId } from '../../utils/publicBattleActivity.js';

export function usePublicCardSkills(battle, cards) {
  const skills = ref({});
  provide('publicBattleSkills', skills);
  let version = 0;
  // Artwork is a battle snapshot. Fetch once per roster change, not every HP
  // poll, and keep mounted icons stable while a new card's skills are fetched.
  const roster = computed(() => cards.value.map(battleCardId).sort().join(','));
  watch([() => battle.value?.id, roster], async ([id], previous) => {
    const request = ++version;
    if (id !== previous?.[0]) skills.value = {};
    if (!id) return;
    try {
      const { data, error } = await supabase.from('battle_card_skills')
        .select('id,battle_card_id,name,icon,priority,skill_code')
        .eq('battle_id', id).order('priority').order('skill_code');
      if (error || request !== version) return;
      const grouped = {};
      for (const skill of data ?? []) (grouped[skill.battle_card_id] ??= []).push(skill);
      skills.value = grouped;
    } catch { /* Keep the last snapshot or embedded Studio skill artwork. */ }
  }, { immediate: true });
  onUnmounted(() => { version++; });
}
