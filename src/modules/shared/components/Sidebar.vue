<template>
  <div class="flex min-h-screen bg-gray-50">
    <aside
      class="flex flex-col w-60 bg-gradient-to-b from-[#241554] via-[#452B97] to-[#241554] text-white py-6 px-4"
    >
      <div class="flex items-center gap-2 mb-8 px-2">
        <div
          class="flex items-center justify-center w-8 h-8 rounded-full border border-white/40"
        >
          <span class="text-xs font-semibold">i</span>
        </div>
        <span class="text-lg font-bold tracking-wide">imedto</span>
      </div>

      <nav class="space-y-1 text-sm font-medium flex-1">
        <RouterLink
          class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
          active-class="bg-white/15"
          to="/home"
        >
          <span class="w-5 text-center">🏠</span>
          <span>Painel inicial</span>
        </RouterLink>
        <RouterLink
          class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
          active-class="bg-white/15"
          to="/agenda"
        >
          <span class="w-5 text-center">📅</span>
          <span>Gestão de atendimento</span>
        </RouterLink>
        <RouterLink
          class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
          active-class="bg-white/15"
          to="/profissional"
        >
          <span class="w-5 text-center">👤</span>
          <span>Cadastro profissional</span>
        </RouterLink>
        <RouterLink
          class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
          active-class="bg-white/15"
          to="/estabelecimento"
        >
          <span class="w-5 text-center">🏥</span>
          <span>Configurações do estabelecimento</span>
        </RouterLink>
      </nav>

      <div class="mt-4 border-t border-white/10 pt-4 text-xs text-white/70">
        <p>Ajuda e suporte</p>
      </div>
    </aside>

    <div class="flex-1">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>
