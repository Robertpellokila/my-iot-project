export function quizClockState(round, seconds, now = Date.now()) {
  const limit = Math.max(0, Number(seconds) || 0);
  const start = Date.parse(round?.timer_started_at ?? round?.created_at ?? '');
  if (!Number.isFinite(start)) return { remaining:null, elapsed:0, label:'Menyiapkan timer…', progress:100 };
  const stop = Date.parse(round?.won_at ?? round?.timer_paused_at ?? '');
  const elapsed = Math.max(0, Math.floor(((Number.isFinite(stop) ? stop : now) - start) / 1000));
  if (!limit) return { remaining:null, elapsed, label:`${round?.timer_paused_at?'Dijeda · ':''}${Math.floor(elapsed/60)}:${String(elapsed%60).padStart(2,'0')} · tanpa batas`, progress:100 };
  const remaining = Math.max(0, Math.min(limit, Math.ceil((start + limit*1000 - (Number.isFinite(stop) ? stop : now))/1000)));
  return { remaining, elapsed, label:round?.timer_paused_at?`Dijeda · ${remaining} detik`:remaining===0?'Waktu habis':`${remaining} detik`, progress:remaining/limit*100 };
}
