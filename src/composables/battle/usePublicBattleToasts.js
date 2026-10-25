import { onUnmounted, ref, watch } from 'vue';
import { describePublicAction, publicActionCardIds, publicActionTypes } from '../../utils/publicBattleActions.js';

export function usePublicBattleToasts({ battle, findCard, fetchCard }) {
  const current = ref(null);
  const seen = new Set();
  const queue = [];
  let timer;
  let chain = Promise.resolve();
  let disposed = false;
  const pendingLookups = new Set();
  let generation = 0;

  const reset = () => {
    generation += 1;
    clearTimeout(timer);
    pendingLookups.forEach(cancel => cancel());
    queue.length = 0;
    seen.clear();
    current.value = null;
    chain = Promise.resolve();
  };
  watch(() => battle.value?.id, reset);

  const advance = () => {
    clearTimeout(timer);
    current.value = null;
    while (queue.length) {
      const next = queue.shift();
      if (Date.now() - next.receivedAt > 15000) continue;
      current.value = next;
      timer = setTimeout(advance, next.duration);
      break;
    }
  };
  const lookup = id => {
    const local = findCard(id);
    if (local) return Promise.resolve(local);
    // A delayed lookup must not hold up the live action feed.
    return new Promise(resolve => {
      let settled = false;
      const finish = value => {
        if (settled) return;
        settled = true;
        clearTimeout(timeout);
        pendingLookups.delete(cancel);
        resolve(value);
      };
      const cancel = () => finish(null);
      const timeout = setTimeout(cancel, 1200);
      pendingLookups.add(cancel);
      Promise.resolve().then(() => fetchCard(id)).then(finish, cancel);
    });
  };
  const receive = event => {
    if (disposed || !event || !publicActionTypes.has(String(event.type).toLowerCase())) return;
    const key = String(event.id ?? `${event.type}:${event.created_at}:${event.source_player}:${event.card_id}`);
    if (seen.has(key)) return;
    seen.add(key);
    if (seen.size > 400) seen.delete(seen.values().next().value);
    const receivedAt = Date.now();
    const battleId = battle.value?.id;
    const eventGeneration = generation;
    chain = chain.then(async () => {
      if (disposed || eventGeneration !== generation) return;
      const cards = (await Promise.all(publicActionCardIds(event).map(lookup))).filter(Boolean);
      if (disposed || eventGeneration !== generation || battle.value?.id !== battleId) return;
      const description = describePublicAction(event, battle.value, cards);
      if (!description) return;
      const notice = { ...description, key, receivedAt, duration: event.type === 'win' ? 5500 : 3600 };
      if (event.type === 'win') { queue.length = 0; queue.push(notice); advance(); return; }
      if (queue.length >= 6) queue.shift();
      queue.push(notice);
      if (!current.value) advance();
    }).catch(error => console.warn('[PUBLIC BATTLE] Action notification:', error));
  };
  onUnmounted(() => {
    disposed = true;
    reset();
  });
  return { current, receive };
}
