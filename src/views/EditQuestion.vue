<script setup>
import { useRoute } from 'vue-router';
import QuestionEditor from '../components/questions/QuestionEditor.vue';
const route = useRoute();
</script>
<template><QuestionEditor :key="route.params.id" :question-id="String(route.params.id)" /></template>
