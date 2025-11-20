<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
const auth = useAuthStore()
</script>

<template>
  <section>
    Home
    <button @click="auth.logout">logout</button>
  </section>
</template>
