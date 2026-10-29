<script setup>
defineProps({ name: { type: String, default: 'special' } });
const paths = {
  summon: ['M7 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z', 'M12 8v8M8 12h8'],
  attack: ['m14 4 6-1-1 6-9 9-4-4Z', 'm4 12 8 8M4 20l4-4M3 19l2 2'],
  special: ['m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5Z', 'M20 2v4M18 4h4'],
  more: ['M4 4h6v6H4ZM14 4h6v6h-6ZM4 14h6v6H4ZM14 14h6v6h-6Z'],
  end_turn: ['M4 12h12m-5-5 5 5-5 5M20 4v16'],
  combo: ['m3 4 5 1 9 12-3 3-9-12Z', 'm21 4-5 1-3 4m-4 6-2 2 3 3m-6-1 4-4m8 0 4 4'],
  fusion: ['M5 3c0 8 14 10 14 18M19 3C19 11 5 13 5 21', 'M6 6h12M8 9h8M8 15h8M6 18h12'],
  ultimate: ['m13 2-9 12h7l-1 8 10-13h-7Z'],
  heal: ['M9 3h6v6h6v6h-6v6H9v-6H3V9h6Z'],
  synergy: ['M8 8h8M8 16h8M6 10v4m12-4v4', 'M4 4h4v4H4ZM16 4h4v4h-4ZM4 16h4v4H4ZM16 16h4v4h-4Z'],
  defense: ['m12 3 8 3v6c0 4-4 7-8 9-4-2-8-5-8-9V6Z', 'm8 12 3 3 5-6'],
  check: ['m5 12 4 4L19 6'],
  info: ['M12 8h.01M11 12h1v5', 'M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0'],
  lock: ['M7 10V7a5 5 0 0 1 10 0v3', 'M5 10h14v11H5ZM12 14v3'],
};
</script>

<template>
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">
    <path v-for="(path, index) in paths[name] || paths.special" :key="index" :d="path" />
  </svg>
</template>
