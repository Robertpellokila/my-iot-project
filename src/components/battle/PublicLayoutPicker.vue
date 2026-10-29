<script setup>
import { PUBLIC_BATTLE_LAYOUTS } from '../../utils/publicBattleLayouts.js';
import TbcEmblem from './TbcEmblem.vue';

defineProps({ modelValue: { type: String, default: 'center_duel' }, disabled: Boolean });
const emit = defineEmits(['update:modelValue']);
</script>

<template>
  <fieldset class="public-layout-picker" :disabled="disabled">
    <legend>Public battle layout</legend>
    <p class="layout-intro">Pilih tampilan untuk penonton. Semua layout mengikuti giliran dan aksi pemain secara live.</p>
    <div class="layout-options">
      <label v-for="layout in PUBLIC_BATTLE_LAYOUTS" :key="layout.id" class="layout-option" :class="{ selected: modelValue === layout.id }">
        <input type="radio" name="public-battle-layout" :value="layout.id" :checked="modelValue === layout.id" @change="emit('update:modelValue', layout.id)" />
        <span class="layout-preview" :class="`preview-${layout.id}`" aria-hidden="true">
          <span class="mini-header">PUBLIC SPECTATOR <b>BATTLE VIEW</b></span>
          <span class="mini-scoreboard"></span>
          <span class="mini-brand"><TbcEmblem /><b>TBC</b><small>ROUND 3</small></span>
          <span v-for="(side, index) in ['p1', 'p2']" :key="side" :class="side">
            <span class="mini-hud"><span class="mini-portrait"></span><strong>Player {{ index + 1 }}</strong><i></i><small>AP ● ● ● ○ ○</small></span>
            <span class="mini-roster"><i v-for="card in 4" :key="card"></i></span>
            <span class="mini-hero"><small>{{ index ? 'VECTOR WOLF' : 'CACHE TURTLE' }}</small><svg viewBox="0 0 50 60"><path v-if="!index" d="M25 5 8 13v18c0 12 17 23 17 23s17-11 17-23V13Z"/><path v-else d="M28 3c4 14-18 23-13 32l5-6c0 9 14 11 14 19 0 6-4 9-10 9C3 57 1 38 13 25c-1 10 4 12 4 12C11 23 28 17 28 3Z"/></svg><b>{{ index ? 'Burn!' : 'Shield!' }}</b></span>
          </span>
          <span class="mini-log"><i></i><span>Cache Turtle gains <b>Shield!</b><br>Vector Wolf inflicts <em>Burn!</em></span></span>
        </span>
        <span class="layout-option-title"><strong>{{ layout.name }}</strong><span class="layout-radio-mark">{{ modelValue === layout.id ? '✓' : '' }}</span></span>
        <span class="layout-description">{{ layout.description }}</span>
        <span class="layout-detail">{{ layout.detail }}</span>
      </label>
    </div>
  </fieldset>
</template>

<style scoped>
.public-layout-picker { min-width:0; padding:0; margin:0; border:0; color:#253b30; }
.public-layout-picker legend { padding:0; font-size:20px; font-weight:800; letter-spacing:-.02em; }
.layout-intro { margin:8px 0 20px; max-width:58ch; font-size:13px; line-height:1.6; color:#69786d; }
.layout-options { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:16px; }
.layout-option { position:relative; display:flex; flex-direction:column; min-width:0; padding:8px 8px 14px; border:1px solid #d8e2d9; border-radius:12px; background:#fff; cursor:pointer; transition:border-color .15s,box-shadow .15s; }
.layout-option:hover { border-color:#829b88; }
.layout-option.selected { border-color:#24794e; box-shadow:0 0 0 2px #24794e; background:#f8fcf8; }
.layout-option:has(input:focus-visible) { outline:3px solid #1777bf; outline-offset:4px; }
.layout-option input { position:absolute; width:1px; height:1px; clip-path:inset(50%); overflow:hidden; }
.layout-option-title { display:flex; align-items:center; justify-content:space-between; gap:8px; padding:12px 6px 0; }
.layout-option-title > strong { font-size:15px; font-weight:800; color:#203d2e; }
.layout-radio-mark { display:grid; place-items:center; flex:none; width:20px; height:20px; border:1.5px solid #bacabb; border-radius:50%; font-size:12px; font-weight:900; }
.selected .layout-radio-mark { background:#24794e; color:white; border-color:#24794e; }
.layout-description { padding:7px 6px 0; color:#5e6e62; font-size:12px; line-height:1.55; }
.layout-detail { margin-top:auto; padding:12px 6px 0; color:#7b6b43; font-size:10px; font-weight:700; letter-spacing:.02em; }
.public-layout-picker:disabled { opacity:.65; }
.public-layout-picker:disabled .layout-option { cursor:wait; }
.layout-preview { display:block; position:relative; isolation:isolate; aspect-ratio:1540 / 810; overflow:hidden; border-radius:6px; border:2px solid #cbb171; background:#16314c url('/images/battle-arena/stadium-v1.webp') center / cover; container-type:inline-size; color:white; font-family:Arial,sans-serif; }
.layout-preview * { box-sizing:border-box; }
.mini-header { position:absolute; top:3%; left:21%; width:58%; height:9%; display:flex; gap:1cqw; align-items:center; justify-content:center; background:#091a37f2; border:.4cqw solid #dcc27e; font-size:2.3cqw; font-weight:900; }
.mini-header b { color:#c5ed7c; }
.mini-brand { position:absolute; top:7%; left:41%; width:18%; height:24%; display:flex; flex-direction:column; align-items:center; justify-content:flex-end; color:#f5db8d; background:#0b2747; border:.5cqw solid #e1c078; clip-path:polygon(0 8%,50% 0,100% 8%,90% 100%,10% 100%); }
.mini-brand > svg { position:absolute; width:8cqw; height:8cqw; top:-.5cqw; }
.mini-brand > b { position:relative; font:bold 6cqw Georgia,serif; margin-top:2cqw; }
.mini-brand > small { font-size:1.6cqw; padding:1cqw 0; }
.mini-hud { position:absolute; left:2%; top:9%; width:32%; height:24%; padding:3cqw 1cqw 1cqw 15cqw; background:linear-gradient(110deg,#1970a6,#061d49); border:.5cqw solid #5acffa; clip-path:polygon(0 0,85% 10%,100% 80%,97% 100%,0 100%); }
.p2 .mini-hud { left:auto; right:2%; padding:3cqw 15cqw 1cqw 1cqw; border-color:#ad65fa; background:linear-gradient(110deg,#241245,#6b32a1); clip-path:polygon(15% 10%,100% 0,100% 100%,3% 100%,0 80%); }
.mini-hud > strong { display:block; font-size:2.7cqw; white-space:nowrap; }
.mini-hud > i { display:block; margin:1cqw 0; width:100%; height:1.6cqw; border:.2cqw solid #fff4cf; border-radius:.4cqw; background:#78f144; }
.p2 .mini-hud > i { background:#ff596d; }
.mini-hud > small { display:block; font-size:1.7cqw; color:#7beaff; white-space:nowrap; }
.p2 .mini-hud > small { color:#da9dff; }
.mini-portrait { position:absolute; left:0; top:0; width:42%; height:100%; background:url('/images/tbc-trainers.png') left center / 200% 100%; }
.p2 .mini-portrait { left:auto; right:0; background-position:right center; }
.mini-roster { position:absolute; left:2%; top:36%; width:12%; height:35%; display:grid; grid-template-columns:1fr 1fr; gap:.6cqw; padding:.6cqw; border:.4cqw solid #5acffa; background:#0c2544e8; }
.p2 .mini-roster { left:auto; right:2%; border-color:#ad65fa; }
.mini-roster > i { min-height:0; background:linear-gradient(145deg,#6bd0cd,#2c5a82 50%,#071f3a); border:.4cqw solid #dabd72; border-radius:.6cqw; }
.mini-roster > i:nth-child(even) { background:linear-gradient(145deg,#9ed564,#347e56 50%,#0e2a36); }
.mini-hero { position:absolute; left:24%; top:38%; width:17%; height:43%; display:flex; flex-direction:column; align-items:center; border:.6cqw solid #f2db8d; border-radius:1cqw; background:radial-gradient(ellipse at 45% 40%,#62eaff,#153e97 60%,#071a43); box-shadow:0 0 4cqw #30d9ff; transform:rotate(-4deg); }
.p2 .mini-hero { left:auto; right:24%; background:radial-gradient(ellipse at 45% 40%,#ffd26a,#db481a 60%,#2b0e16); box-shadow:0 0 4cqw #ff9a3c; transform:rotate(4deg); }
.mini-hero > small { font-size:1.3cqw; padding:.8cqw 0; background:#061731d9; width:100%; text-align:center; }
.mini-hero > svg { width:70%; height:70%; fill:#58d1f6; stroke:#e7faff; stroke-width:2; filter:drop-shadow(0 0 1cqw #a1f0ff); }
.p2 .mini-hero > svg { fill:#ff6c2a; stroke:#fff0c0; }
.mini-hero > b { position:absolute; bottom:2%; right:-18%; font-size:3.6cqw; font-style:italic; text-shadow:.4cqw .4cqw #073795; }
.p2 .mini-hero > b { text-shadow:.4cqw .4cqw #b52816; }
.mini-log { position:absolute; left:25%; bottom:2%; width:50%; height:13%; padding:1cqw 2cqw; display:flex; align-items:center; gap:2cqw; background:#091d43ef; border:.4cqw solid #e0c47e; font-size:2cqw; line-height:1.6; }
.mini-log > i { width:1.5cqw; height:5cqw; border-top:1.5cqw solid #66deff; border-bottom:1.5cqw solid #ff8c3e; }
.mini-log b { color:#63deff; }.mini-log em { color:#ffbd61; font-weight:800; }
.preview-center_duel .mini-header { display:none; }
.preview-top_bottom .mini-brand { left:77%; top:15%; width:19%; height:12%; justify-content:center; }
.preview-top_bottom .mini-brand > b,.preview-top_bottom .mini-brand > svg { display:none; }
.preview-top_bottom .mini-brand > small { font-size:2.4cqw; }
.preview-top_bottom .mini-hud { top:85%; left:3%; right:auto; width:67%; height:13%; padding:.6cqw 1cqw .5cqw 9cqw; clip-path:none; }
.preview-top_bottom .p2 .mini-hud { top:14%; }
.preview-top_bottom .mini-portrait { width:11%; left:0; right:auto; }
.preview-top_bottom .mini-hud > strong { font-size:2.1cqw; }.preview-top_bottom .mini-hud > i { width:42%; height:1cqw; margin:.5cqw 0; }
.preview-top_bottom .mini-hud > small { position:absolute; right:3%; top:40%; font-size:2cqw; }
.preview-top_bottom .mini-roster { left:7%; right:auto; top:64%; width:86%; height:17%; grid-template-columns:repeat(5,1fr); gap:2cqw; }
.preview-top_bottom .mini-roster > i:nth-child(3) { grid-column:4; }
.preview-top_bottom .p2 .mini-roster { top:30%; }
.preview-top_bottom .mini-hero { left:45%; right:auto; top:60%; width:10%; height:25%; transform:none; }
.preview-top_bottom .p2 .mini-hero { top:26%; }.preview-top_bottom .mini-hero > b { font-size:2.3cqw; }
.preview-top_bottom .mini-hero > small { font-size:.75cqw; }
.preview-top_bottom .mini-log { top:52%; bottom:auto; height:6%; font-size:1.15cqw; padding:.4cqw 2cqw; }.preview-top_bottom .mini-log > i { height:2.5cqw; border-width:.7cqw; }
.preview-side_panel .mini-brand { top:14%; left:42%; width:16%; height:10%; justify-content:center; }.preview-side_panel .mini-brand > b,.preview-side_panel .mini-brand > svg { display:none; }
.preview-side_panel .mini-hud { top:15%; left:2%; width:20%; height:26%; padding:2cqw 1cqw 1cqw 8cqw; clip-path:none; }.preview-side_panel .p2 .mini-hud { left:auto; right:2%; }
.preview-side_panel .mini-hud > strong { font-size:1.65cqw; }.preview-side_panel .mini-hud > small { font-size:1.2cqw; }
.preview-side_panel .p2 .mini-portrait { left:0; right:auto; }.preview-side_panel .mini-roster { top:41%; width:20%; height:40%; padding:1cqw; gap:1cqw; }
.preview-side_panel .mini-hero { left:30%; top:32%; width:15%; height:41%; }.preview-side_panel .p2 .mini-hero { left:auto; right:30%; }
.preview-side_panel .mini-log { bottom:4%; height:14%; }
.preview-stadium .mini-scoreboard { position:absolute; left:10%; top:15%; width:80%; height:25%; background:#0c2343; border:.6cqw solid #d6ba75; }
.preview-stadium .mini-hud { top:17%; left:12%; width:29%; height:21%; padding:2.5cqw 1cqw 1cqw 12cqw; }.preview-stadium .p2 .mini-hud { left:auto; right:12%; padding:2.5cqw 12cqw 1cqw 1cqw; }
.preview-stadium .mini-hud > strong { font-size:2.1cqw; }.preview-stadium .mini-hud > small { font-size:1.4cqw; }
.preview-stadium .mini-brand { top:15%; height:24%; }.preview-stadium .mini-hero { left:31%; top:43%; width:14%; height:36%; }.preview-stadium .p2 .mini-hero { left:auto; right:31%; }
.preview-stadium .mini-roster { top:82%; left:3%; width:26%; height:15%; grid-template-columns:repeat(4,1fr); }.preview-stadium .p2 .mini-roster { left:auto; right:3%; }
.preview-stadium .mini-log { left:31%; width:38%; height:15%; bottom:3%; font-size:1.5cqw; }
@media(max-width:560px) { .layout-options { grid-template-columns:1fr; } }
@media(prefers-reduced-motion:reduce) { .layout-option { transition:none; } }
</style>

<style scoped>
.layout-preview{border-color:#b6d8eb;color:#123968}.mini-header,.mini-scoreboard{display:none}.mini-brand{top:4%;height:17%;width:19%;left:40.5%;background:#f3fbff;border:1px solid white;border-radius:0 0 2cqw 2cqw;color:#0e4a81;box-shadow:0 1cqw 2cqw #123d6633}.mini-brand>svg{display:none}.mini-brand>b{font:900 3cqw Inter,sans-serif}.mini-brand>small{font-size:1.8cqw;color:#1b5d8a}.mini-hud{top:4%;height:18%;width:35%;left:2%;padding:1.2cqw 1.2cqw 1cqw 7.5cqw;background:#f0fafff5;border:.3cqw solid white;border-radius:2cqw;clip-path:none;box-shadow:0 1cqw 2cqw #174e6933;color:#163e70}.p2 .mini-hud{left:auto;right:2%;padding:1.2cqw 7.5cqw 1cqw 1.2cqw;background:#f0fafff5;clip-path:none}.mini-hud>strong{font-size:2.1cqw}.mini-hud>small{font-size:1.3cqw;color:#137cbb}.mini-hud>i{background:#15c68a;height:.8cqw}.mini-portrait{left:1cqw;top:1.6cqw;width:5.6cqw;height:5.6cqw;border-radius:50%;background:#e7f6ff;border:.35cqw solid #62bfe3;clip-path:none}.p2 .mini-portrait{left:auto;right:1cqw;background:#e8fff7;border-color:#35b4a2}.mini-hero{background:linear-gradient(140deg,#fff,#e4faff);box-shadow:0 .5cqw 2cqw #0f4d6c33;border:.4cqw solid #e7c35c;top:32%;height:47%;left:29%;width:17%}.p2 .mini-hero{background:linear-gradient(140deg,#fff,#fff1de);box-shadow:0 .5cqw 2cqw #0f4d6c33;left:auto;right:29%}.mini-hero>small{background:#ecfaff;color:#193e67;font-weight:800}.mini-hero>b{font-size:2.2cqw;color:#07599e;text-shadow:0 .3cqw white}.p2 .mini-hero>b{color:#ac4911;text-shadow:0 .3cqw white}.mini-roster{top:27%;height:66%;width:19%;left:2%;border:.3cqw solid white;border-radius:1.5cqw;background:#f0fafff2;padding:1cqw;gap:1cqw}.p2 .mini-roster{left:auto;right:2%}.mini-roster>i{background:linear-gradient(150deg,#e0f9ff,#38aed7);border-color:#d8bc65;border-radius:.5cqw}.mini-log{height:9%;bottom:3%;left:25%;width:50%;background:#f2fbfff2;border:.3cqw solid white;border-radius:1cqw;font-size:1.4cqw;color:#205785;line-height:1.3}.mini-log b{color:#147cae}.mini-log em{color:#ad5419}.mini-log>i{height:3cqw;border-width:1cqw}.preview-side_panel .mini-hud{top:3%;width:20%;height:24%;padding:1cqw 1cqw 1cqw 7cqw}.preview-side_panel .p2 .mini-hud{left:auto;right:2%;padding:1cqw 1cqw 1cqw 7cqw}.preview-side_panel .p2 .mini-portrait{left:1cqw;right:auto}.preview-side_panel .mini-roster{top:27%;height:66%;width:20%}.preview-side_panel .mini-hud>strong{font-size:1.8cqw}.preview-side_panel .mini-hud>small{font-size:1.1cqw}.preview-side_panel .mini-brand{top:4%}.preview-top_bottom .mini-hud{top:80%;height:17%;width:28%;left:2%;padding:1cqw 1cqw 1cqw 7cqw}.preview-top_bottom .p2 .mini-hud{top:3%;left:2%;right:auto;padding:1cqw 1cqw 1cqw 7cqw}.preview-top_bottom .p2 .mini-portrait{left:1cqw;right:auto}.preview-top_bottom .mini-hud>small{position:static;font-size:1.2cqw}.preview-top_bottom .mini-roster{top:80%;height:17%;left:48%;width:50%;grid-template-columns:repeat(4,1fr)}.preview-top_bottom .p2 .mini-roster{top:3%;left:48%;right:auto}.preview-top_bottom .mini-roster>i:nth-child(3){grid-column:auto}.preview-top_bottom .mini-brand{left:33%;top:3%;width:13%;height:16%}.preview-top_bottom .mini-hero{left:30%;top:32%;width:16%;height:42%;transform:rotate(-4deg)}.preview-top_bottom .p2 .mini-hero{left:auto;right:30%;top:32%;transform:rotate(4deg)}.preview-top_bottom .mini-log{left:32%;width:15%;top:80%;height:17%;font-size:1cqw}.preview-stadium .mini-hud{top:4%;left:2%;width:35%;height:18%;background:#0e69a7;color:white;padding:1cqw 1cqw 1cqw 8cqw}.preview-stadium .p2 .mini-hud{left:auto;right:2%;padding:1cqw 8cqw 1cqw 1cqw}.preview-stadium .mini-hud>small{color:#dcf6ff}.preview-stadium .mini-roster{left:2%;width:39%;top:77%;height:20%}.preview-stadium .p2 .mini-roster{left:auto;right:2%}.preview-stadium .mini-brand{top:3%;height:18%}.preview-stadium .mini-hero{top:30%;left:31%;width:15%;height:39%}.preview-stadium .p2 .mini-hero{left:auto;right:31%}.preview-stadium .mini-log{left:42%;width:16%;height:20%;top:77%;font-size:1cqw}
</style>
