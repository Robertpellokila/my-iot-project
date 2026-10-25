<script setup>
import { RouterLink, useRoute } from 'vue-router';
const route = useRoute();
</script>

<template>
  <div class="card-studio-nav">
    <div class="card-studio-label"><strong>Card Studio</strong><span>Buat kartu, atur skill, cetak, dan hubungkan RFID.</span></div>
    <nav aria-label="Alur Card Studio">
      <RouterLink :to="{ name:'card-generator' }" :aria-current="route.name === 'card-generator' ? 'page' : undefined" :class="{ selected:route.name === 'card-generator' }">
        <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="6" y="3" width="13" height="18" rx="2"/><path d="M6 6H3v13a2 2 0 0 0 2 2M10 8h5M10 12h5M10 16h3"/></svg>
        Edit kartu
      </RouterLink>
      <RouterLink :to="{ name:'album-card' }" :aria-current="route.name === 'album-card' ? 'page' : undefined" :class="{ selected:route.name === 'album-card' }">Album &amp; tampilan publik</RouterLink>
    </nav>
  </div>
</template>

<style scoped>
.card-studio-nav { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:16px; padding:18px 26px; border-bottom:1px solid #dce5da; background:#fff; color:#193b2d; font-family:Inter,Arial,sans-serif; }
.card-studio-label { display:flex; flex-direction:column; gap:4px; }
.card-studio-label strong { font-size:16px; font-weight:750; }
.card-studio-label span { color:#718176; font-size:11px; }
nav { display:flex; flex-wrap:wrap; gap:6px; padding:4px; border:1px solid #dce5da; border-radius:9px; background:#f4f7f2; }
a { display:flex; align-items:center; justify-content:center; gap:8px; padding:10px 14px; border:1px solid transparent; border-radius:6px; color:#57725e; font-size:12px; font-weight:650; text-decoration:none; }
a.selected { background:#fff; border-color:#b6cfbc; color:#17623d; box-shadow:0 1px 3px #153f1910; }
a:hover { color:#17623d; background:#edf4e9; }
a:focus-visible { outline:2px solid #2d869b; outline-offset:2px; }
svg { width:18px; height:18px; fill:none; stroke:currentColor; stroke-width:1.5; stroke-linecap:round; stroke-linejoin:round; }
@media(max-width:720px) { .card-studio-nav { padding:14px; gap:12px; } nav { width:100%; } a { flex:1; padding:10px 8px; font-size:11px; } }
</style>
