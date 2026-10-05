<template>
  <!-- Visual only. All damage, duration and status logic remain on the server. -->
  <div class="burn-vfx" aria-hidden="true">
    <span class="burn-vfx__heat" />
    <span class="burn-vfx__edge burn-vfx__edge--left" />
    <span class="burn-vfx__edge burn-vfx__edge--right" />
    <span class="burn-vfx__flame flame-1" />
    <span class="burn-vfx__flame flame-2" />
    <span class="burn-vfx__flame flame-3" />
    <span class="burn-vfx__flame flame-4" />
    <span class="burn-vfx__flame flame-5" />
    <span class="burn-vfx__flame flame-6" />
    <span class="burn-vfx__ember ember-1" />
    <span class="burn-vfx__ember ember-2" />
    <span class="burn-vfx__ember ember-3" />
    <span class="burn-vfx__ember ember-4" />
    <span class="burn-vfx__ember ember-5" />
    <span class="burn-vfx__smoke" />
  </div>
</template>

<style scoped>
/* GPU-friendly transform/opacity animation; no square masks, borders or labels. */
.burn-vfx {
  position: absolute;
  inset: 0;
  overflow: hidden;
  border-radius: inherit;
  pointer-events: none;
  isolation: isolate;
  contain: paint;
}
.burn-vfx__heat {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(ellipse 46% 26% at 50% 101%, rgba(255,160,38,.29), transparent 93%),
    radial-gradient(ellipse 17% 32% at 2% 79%, rgba(255,102,20,.21), transparent 88%),
    radial-gradient(ellipse 17% 32% at 99% 76%, rgba(255,95,18,.22), transparent 88%);
  mix-blend-mode: screen;
  animation: burn-heat 2.7s ease-in-out infinite alternate;
}
.burn-vfx__edge {
  position: absolute;
  bottom: 3%;
  width: 19%;
  height: 61%;
  background:
    radial-gradient(ellipse at 24% 88%, rgba(255,231,134,.43), transparent 38%),
    linear-gradient(to top, rgba(255,83,9,.24), rgba(255,146,30,.37) 35%, rgba(255,70,12,.16) 67%, transparent 95%);
  filter: blur(2.2px);
  opacity: .58;
  clip-path: polygon(0 100%,0 35%,22% 13%,40% 38%,56% 0,87% 45%,47% 54%,95% 78%,55% 100%);
  mix-blend-mode: screen;
  transform-origin: bottom center;
  animation: burn-side 1.85s ease-in-out infinite alternate;
}
.burn-vfx__edge--left { left:-2%; }
.burn-vfx__edge--right { right:-2%; transform:scaleX(-1); animation-delay:-.94s; }
.burn-vfx__flame {
  position: absolute;
  bottom: -3%;
  left: var(--x);
  width: var(--w);
  height: var(--h);
  opacity: .77;
  transform-origin: 50% 100%;
  border-radius: 60% 55% 15% 15%;
  clip-path: polygon(
    48% 0%, 60% 13%, 66% 31%, 61% 43%, 77% 32%,
    83% 49%, 100% 77%, 95% 100%, 3% 100%, 0 80%,
    22% 51%, 30% 30%, 38% 57%, 42% 28%
  );
  background:
    radial-gradient(ellipse 65% 54% at 50% 91%, rgba(255,252,200,.91), transparent 82%),
    radial-gradient(ellipse 75% 96% at 50% 84%, rgba(255,193,62,.86) 0%, rgba(255,101,22,.68) 48%, rgba(255,53,8,.13) 77%, transparent 100%);
  filter: blur(.65px);
  mix-blend-mode: screen;
  animation: burn-flame var(--time) ease-in-out infinite alternate;
  animation-delay: var(--delay);
}
.flame-1 { --x:-9%;  --w:33%; --h:31%; --time:1.12s; --delay:-.18s; }
.flame-2 { --x:8%;   --w:26%; --h:19%; --time:.91s; --delay:-.71s; opacity:.67; }
.flame-3 { --x:24%;  --w:29%; --h:29%; --time:1.26s; --delay:-.48s; opacity:.63; }
.flame-4 { --x:43%;  --w:25%; --h:22%; --time:1.04s; --delay:-.91s; opacity:.68; }
.flame-5 { --x:65%;  --w:28%; --h:25%; --time:1.38s; --delay:-.2s; opacity:.75; }
.flame-6 { --x:81%;  --w:26%; --h:35%; --time:1.15s; --delay:-.84s; opacity:.75; }
.burn-vfx__ember {
  position: absolute;
  bottom: var(--bottom);
  left: var(--x);
  height: var(--diameter);
  width: var(--diameter);
  border-radius: 50%;
  background: #ffe1a0;
  box-shadow: 0 0 3px 1px #ffac42, 0 0 8px 2px rgba(255,82,6,.38);
  opacity: 0;
  will-change: transform, opacity;
  animation: burn-ember var(--duration) linear infinite;
  animation-delay: var(--delay);
}
.ember-1 { --x:8%;  --bottom:11%; --diameter:2px; --duration:2.9s; --delay:-1.1s; --drift:14px; }
.ember-2 { --x:24%; --bottom:4%;  --diameter:3px; --duration:3.6s; --delay:-2.6s; --drift:-13px; }
.ember-3 { --x:53%; --bottom:12%; --diameter:2px; --duration:3.1s; --delay:-.9s; --drift:11px; }
.ember-4 { --x:76%; --bottom:2%;  --diameter:2px; --duration:3.8s; --delay:-3.1s; --drift:-12px; }
.ember-5 { --x:91%; --bottom:9%;  --diameter:3px; --duration:2.7s; --delay:-1.9s; --drift:7px; }
.burn-vfx__smoke {
  position: absolute;
  left: 15%; bottom: 12%; width: 68%; height: 24%;
  background: radial-gradient(ellipse at 50% 100%, rgba(82,42,33,.09), transparent 70%);
  filter: blur(11px);
  animation: burn-smoke 4.5s ease-out infinite;
}
@keyframes burn-side {
  from { opacity:.4; filter:blur(3px); }
  to { opacity:.72; filter:blur(1.7px); }
}
@keyframes burn-heat {
  from { opacity:.62; transform:scale(1); }
  to { opacity:1; transform:scale(1.045); }
}
@keyframes burn-flame {
  0%   { transform:translate3d(-2px, 3px,0) rotate(-5deg) scaleX(.86) scaleY(.87); opacity:.52; }
  40%  { transform:translate3d(1px,-2px,0) rotate(4deg) scaleX(1.08) scaleY(1.08); opacity:.87; }
  100% { transform:translate3d(3px, 1px,0) rotate(-3deg) scaleX(.92) scaleY(.96); opacity:.67; }
}
@keyframes burn-ember {
  0% { transform:translate3d(0,0,0) scale(.3); opacity:0; }
  12% { opacity:.95; }
  63% { opacity:.65; }
  100% { transform:translate3d(var(--drift),-125px,0) scale(.1); opacity:0; }
}
@keyframes burn-smoke {
  0% { transform: translate3d(0,8px,0) scale(.7); opacity:0; }
  32% { opacity:.35; }
  100% { transform: translate3d(10px,-55px,0) scale(1.3); opacity:0; }
}
@media (prefers-reduced-motion: reduce) {
  .burn-vfx__heat, .burn-vfx__edge, .burn-vfx__flame, .burn-vfx__ember, .burn-vfx__smoke {
    animation: none !important;
  }
  .burn-vfx__ember, .burn-vfx__smoke { display:none; }
}
</style>
