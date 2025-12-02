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
          <span class="w-5 text-center">
            <i class="fa-solid fa-house text-white" aria-hidden="true"></i>
          </span>
          <span>Painel inicial</span>
        </RouterLink>
        <template v-if="canSeeMenus">
          <RouterLink
            v-if="permissionsStore.hasPermission('agenda')"
            class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
            active-class="bg-white/15"
            to="/agenda"
          >
            <span class="w-5 text-center">
              <i
                class="fa-solid fa-calendar-days text-white"
                aria-hidden="true"
              ></i>
            </span>
            <span>Gestão de atendimento</span>
          </RouterLink>
          <RouterLink
            v-if="permissionsStore.hasPermission('minhas_consultas')"
            class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
            active-class="bg-white/15"
            to="/minhas-consultas"
          >
            <span class="w-5 text-center">
              <i
                class="fa-solid fa-stethoscope text-white"
                aria-hidden="true"
              ></i>
            </span>
            <span>Minhas consultas</span>
          </RouterLink>
          <RouterLink
            v-if="permissionsStore.hasPermission('pacientes')"
            class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
            active-class="bg-white/15"
            to="/pacientes"
          >
            <span class="w-5 text-center">
              <i
                class="fa-solid fa-people-group text-white"
                aria-hidden="true"
              ></i>
            </span>
            <span>Pacientes</span>
          </RouterLink>
          <RouterLink
            v-if="permissionsStore.hasPermission('estoque')"
            class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
            active-class="bg-white/15"
            to="/estoque"
          >
            <span class="w-5 text-center">
              <i class="fa-solid fa-boxes-stacked text-white" aria-hidden="true"></i>
            </span>
            <span>Estoque</span>
          </RouterLink>
          <RouterLink
            class="flex items-center gap-2 rounded-lg px-3 py-2 hover:bg-white/10"
            active-class="bg-white/15"
            to="/perfil-profissional"
          >
            <span class="w-5 text-center">
              <i class="fa-solid fa-id-badge text-white" aria-hidden="true"></i>
            </span>
            <span>Meu cadastro profissional</span>
          </RouterLink>
          <template
            v-if="
              permissionsStore.hasPermission('profissionais') ||
              permissionsStore.hasPermission('permissoes')
            "
          >
            <button
              type="button"
              class="mt-4 flex w-full items-center justify-between px-3 py-2 rounded-lg hover:bg-white/10 text-[13px] font-medium"
              @click="isProfessionalsOpen = !isProfessionalsOpen"
            >
              <div class="flex items-center gap-2">
                <span class="w-5 text-center">
                  <i
                    class="fa-solid fa-user-group text-white"
                    aria-hidden="true"
                  ></i>
                </span>
                <span>Profissionais</span>
              </div>
              <span class="text-xs text-white/70">
                {{ isProfessionalsOpen ? '▾' : '▸' }}
              </span>
            </button>

            <div v-if="isProfessionalsOpen" class="mt-1 space-y-1">
              <RouterLink
                v-if="permissionsStore.hasPermission('profissionais')"
                class="flex items-center rounded-lg pl-9 pr-3 py-1.5 hover:bg-white/10 text-[13px]"
                active-class="bg-white/15"
                to="/profissionais"
              >
                <span>Gestão de profissionais</span>
              </RouterLink>
              <RouterLink
                v-if="permissionsStore.hasPermission('permissoes')"
                class="flex items-center rounded-lg pl-9 pr-3 py-1.5 hover:bg-white/10 text-[13px]"
                active-class="bg-white/15"
                to="/permissoes"
              >
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
          <span class="w-5 text-center">
            <i
              class="fa-regular fa-circle-question text-white"
              aria-hidden="true"
            ></i>
          </span>
          <span>Suporte</span>
        </button>
        <RouterLink
          v-if="permissionsStore.hasPermission('config_estabelecimento')"
          class="flex items-center gap-2 w-full px-3 py-2 hover:text-white/90"
          active-class="text-white"
          to="/estabelecimento"
        >
          <span class="w-5 text-center">
            <i class="fa-solid fa-gear text-white" aria-hidden="true"></i>
          </span>
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
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { usePermissionsStore } from '@/stores/permissions'

const auth = useAuthStore()
const permissionsStore = usePermissionsStore()
const canSeeMenus = computed(
  () =>
    permissionsStore.permissions.length > 0 ||
    permissionsStore.isOwnerEstabelecimento,
)
const isProfessionalsOpen = ref(false)
const userName = ref('')
const userRole = ref('Profissional')
const userClinic = ref<string | null>(null)
const userInitial = ref('P')

const route = useRoute()

function updateSubmenuStateByRoute() {
  const currentPath = route.path
  isProfessionalsOpen.value =
    currentPath.startsWith('/profissionais') ||
    currentPath.startsWith('/permissoes')
}

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

  if (vinculo?.id && !userClinic.value) {
    userClinic.value = vinculo.estabelecimento?.nome_fantasia ?? null
  }

  await permissionsStore.ensureLoaded()

  updateSubmenuStateByRoute()
})

watch(
  () => route.path,
  () => {
    updateSubmenuStateByRoute()
  },
)
</script>
