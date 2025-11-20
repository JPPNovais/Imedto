<template>
  <div class="flex min-h-screen bg-gray-50">
    <aside
      class="flex flex-col w-60 bg-gradient-to-b from-[#241554] via-[#452B97] to-[#241554] text-white py-6 px-4"
    >
      <div class="flex items-center gap-2 mb-6 px-2">
        <div
          class="flex items-center justify-center w-8 h-8 rounded-full border border-white/40"
        >
          <span class="text-xs font-semibold">i</span>
        </div>
        <span class="text-lg font-bold tracking-wide">imedto</span>
      </div>

      <div class="flex items-center gap-3 mb-6 px-2">
        <div
          class="h-12 w-12 rounded-full border-2 border-white overflow-hidden flex items-center justify-center bg-white/10 text-white text-lg font-semibold"
        >
          <span>{{ userInitial }}</span>
        </div>
        <div class="flex flex-col leading-tight">
          <span class="text-sm font-semibold text-white">
            {{ userName || 'Profissional' }}
          </span>
          <span class="text-[11px] text-primary-medium/90">
            {{ userRole }}
          </span>
          <span
            v-if="userClinic"
            class="text-[11px] text-[#7BA14B]"
          >
            {{ userClinic }}
          </span>
        </div>
      </div>

      <nav class="space-y-1 text-sm font-medium flex-1 text-white/80">
        <RouterLink
          class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
          active-class="bg-white/15"
          to="/home"
        >
          <span class="w-5 text-center">🏠</span>
          <span>Painel inicial</span>
        </RouterLink>
        <template v-if="canSeeMenus">
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
            to="/perfil-profissional"
          >
            <span class="w-5 text-center">👤</span>
            <span>Meu cadastro profissional</span>
          </RouterLink>
          <template v-if="isOwnerEstabelecimento">
            <button
              type="button"
              class="mt-4 flex w-full items-center justify-between px-3 py-2 rounded-lg hover:bg-white/10 text-[13px] font-medium"
              @click="isProfessionalsOpen = !isProfessionalsOpen"
            >
              <div class="flex items-center gap-2">
                <span class="w-5 text-center">👥</span>
                <span>Profissionais</span>
              </div>
              <span class="text-xs text-white/70">
                {{ isProfessionalsOpen ? '▾' : '▸' }}
              </span>
            </button>

            <div v-if="isProfessionalsOpen" class="mt-1 space-y-1">
              <RouterLink
                class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
                active-class="bg-white/15"
                to="/profissionais"
              >
                <span class="w-5 text-center">👥</span>
                <span>Gestão de profissionais</span>
              </RouterLink>
              <RouterLink
                class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
                active-class="bg-white/15"
                to="/permissoes"
              >
                <span class="w-5 text-center">🔑</span>
                <span>Permissões</span>
              </RouterLink>
            </div>
          </template>
        </template>
      </nav>

      <div class="mt-4 border-t border-white/10 pt-4 text-xs text-white/70">
        <button
          type="button"
          class="flex items-center gap-2 w-full px-3 py-2 hover:text-white/90"
        >
          <span class="w-5 text-center">?</span>
          <span>Suporte</span>
        </button>
        <RouterLink
          v-if="isOwnerEstabelecimento"
          class="flex items-center gap-2 w-full px-3 py-2 hover:text-white/90"
          active-class="text-white"
          to="/estabelecimento"
        >
          <span class="w-5 text-center">⚙️</span>
          <span>Configuração</span>
        </RouterLink>
      </div>
    </aside>

    <div class="flex-1">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const canSeeMenus = ref(false)
const isOwnerEstabelecimento = ref(false)
const isProfessionalsOpen = ref(true)
const userName = ref('')
const userRole = ref('Profissional')
const userClinic = ref<string | null>(null)
const userInitial = ref('P')

onMounted(async () => {
  if (!auth.currentUser?.id) return

  // Carrega nome do usuário
  const { data: usuario } = await supabase
    .from('usuarios')
    .select('nome_completo')
    .eq('id', auth.currentUser.id)
    .maybeSingle()

  userName.value = usuario?.nome_completo || auth.currentUser.email || ''
  userInitial.value = (userName.value || 'P').charAt(0).toUpperCase()

  // Verifica se é owner de algum estabelecimento
  const { data: estabOwner } = await supabase
    .from('estabelecimentos')
    .select('id, nome_fantasia')
    .eq('owner_usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (estabOwner?.id) {
    isOwnerEstabelecimento.value = true
    canSeeMenus.value = true
    userClinic.value = estabOwner.nome_fantasia ?? null
  }

  // Busca dados profissionais (profissão) para o usuário logado
  const { data: profissional } = await supabase
    .from('profissionais')
    .select(
      `
      id,
      profissao:profissoes ( nome )
    `,
    )
    .eq('usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (profissional?.profissao?.nome) {
    userRole.value = profissional.profissao.nome
  }

  if (!profissional?.id) {
    // sem profissional cadastrado → sem menus adicionais
    if (!isOwnerEstabelecimento.value) {
      canSeeMenus.value = false
    }
    return
  }

  // Se não for owner, verifica vínculo com estabelecimento para liberar menus
  const { data: vinculo } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .select(
      `
      id,
      estabelecimento:estabelecimentos ( nome_fantasia )
    `,
    )
    .eq('profissional_id', profissional.id)
    .limit(1)
    .maybeSingle()

  if (vinculo?.id) {
    canSeeMenus.value = true
    if (!userClinic.value) {
      userClinic.value = vinculo.estabelecimento?.nome_fantasia ?? null
    }
  } else if (!isOwnerEstabelecimento.value) {
    canSeeMenus.value = false
  }
})
</script>
