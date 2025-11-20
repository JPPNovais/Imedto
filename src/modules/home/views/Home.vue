<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { supabase } from '@/lib/supabaseClient'
import { useFeedbackStore } from '@/stores/feedback'

const auth = useAuthStore()
const router = useRouter()
const feedback = useFeedbackStore()

const dashboard = reactive({
  cadastroUsuarioPercentual: 0,
  cadastroProfissionalPercentual: 0,
  cadastroEstabelecimentoPercentual: 0,
  profissionalCompleto: false,
  tarefasPendentes: 0,
})

const isLoadingDashboard = ref(false)
const showTutorial = ref(false)
const isOwnerEstabelecimento = ref(false)
const hasDismissedTutorial = ref(false)
const pendingInvites = ref<
  {
    id: string
    estabelecimentoId: string | null
    estabelecimento_nome: string | null
    estabelecimento_foto: string | null
  }[]
>([])
const scheduleSummary = reactive({
  totalHoje: 0,
  totalSemana: 0,
  totalMes: 0,
  proximoHorario: null as string | null,
  proximoTitulo: '' as string,
})

async function loadDashboard() {
  isLoadingDashboard.value = true
  try {
    const { data, error } = await supabase.rpc('dashboard_resumo_usuario')
    if (error) {
      console.error(error)
      return
    }

    const row = Array.isArray(data) ? data[0] : data
    if (row) {
      dashboard.cadastroUsuarioPercentual =
        row.cadastro_usuario_percentual ?? 0
      dashboard.cadastroProfissionalPercentual =
        row.cadastro_profissional_percentual ?? 0
      dashboard.cadastroEstabelecimentoPercentual =
        row.cadastro_estabelecimento_percentual ?? 0
      dashboard.profissionalCompleto = !!row.profissional_completo
      dashboard.tarefasPendentes = row.tarefas_pendentes ?? 0
    }
  } finally {
    isLoadingDashboard.value = false
  }
}

async function loadTutorialState() {
  if (!auth.currentUser?.id) return

  // Se o usuário já ocultou o tutorial nesta máquina, não mostra mais automaticamente
  if (window.localStorage.getItem('imedto_tutorial_dismissed') === '1') {
    hasDismissedTutorial.value = true
    showTutorial.value = false
    return
  }

  const [usuarioResp, estabResp] = await Promise.all([
    supabase
      .from('usuarios')
      .select('tutorial_visto')
      .eq('id', auth.currentUser.id)
      .maybeSingle(),
    supabase
      .from('estabelecimentos')
      .select('id')
      .eq('owner_usuario_id', auth.currentUser.id)
      .limit(1)
      .maybeSingle(),
  ])

  showTutorial.value = !usuarioResp.data?.tutorial_visto
  isOwnerEstabelecimento.value = !!estabResp.data?.id
}

async function loadPendingInvites() {
  if (!auth.currentUser?.email) return

  const { data, error } = await supabase
    .from('solicitacao_vinculo_profissional_estabelecimento')
    .select(
      `
      id,
      status,
      estabelecimento_id,
      estabelecimento:estabelecimentos (
        nome_fantasia,
        razao_social,
        foto_url
      )
    `,
    )
    .eq('email_profissional', auth.currentUser.email.toLowerCase())
    .eq('status', 'pendente')

  if (error) {
    console.error('Erro ao carregar convites pendentes', error)
    return
  }

  pendingInvites.value =
    data?.map((s: any) => ({
      id: s.id,
      estabelecimentoId: s.estabelecimento_id ?? null,
      estabelecimento_nome:
        s.estabelecimento?.nome_fantasia ??
        s.estabelecimento?.razao_social ??
        null,
      estabelecimento_foto: s.estabelecimento?.foto_url ?? null,
	    })) ?? []
}

async function loadScheduleSummary() {
  const { data, error } = await supabase.rpc('agenda_resumo_profissional')
  if (error) {
    console.error('Erro ao carregar resumo da agenda', error)
    return
  }

  const row = Array.isArray(data) ? data[0] : data
  if (row) {
    scheduleSummary.totalHoje = row.total_hoje ?? 0
    scheduleSummary.totalSemana = row.total_semana ?? 0
    scheduleSummary.totalMes = row.total_mes ?? 0
    scheduleSummary.proximoHorario = row.proximo_horario ?? null
    scheduleSummary.proximoTitulo = row.proximo_titulo ?? ''
  }
}

function openTutorial() {
  showTutorial.value = true
}

async function finishTutorial() {
  showTutorial.value = false
  window.localStorage.setItem('imedto_tutorial_dismissed', '1')
  hasDismissedTutorial.value = true
  if (!auth.currentUser?.id) return
  await supabase
    .from('usuarios')
    .update({ tutorial_visto: true })
    .eq('id', auth.currentUser.id)
}

function dismissTutorialForNow() {
  showTutorial.value = false
  window.localStorage.setItem('imedto_tutorial_dismissed', '1')
  hasDismissedTutorial.value = true
}

function goToProfessionalSetup() {
  router.push({ name: 'professional-profile' })
}

function goToEstablishmentSetup() {
  router.push({ name: 'establishment-settings' })
}

async function updateInviteStatus(inviteId: string, status: 'recusado') {
  const { error } =
    await supabase
      .from('solicitacao_vinculo_profissional_estabelecimento')
      .update({ status })
      .eq('id', inviteId)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível atualizar o convite.')
    return
  }

  feedback.success(
    status === 'aceito'
      ? 'Convite aceito. O estabelecimento será notificado.'
      : 'Convite recusado. O estabelecimento será notificado.',
  )
  await loadPendingInvites()
  await loadDashboard()
}

function acceptInvite(inviteId: string) {
  // Usa RPC para aceitar e criar vínculo automaticamente
  supabase
    .rpc('aceitar_convite_profissional', { solicitacao_id: inviteId })
    .then(({ error }) => {
      if (error) {
        console.error(error)
        feedback.error('Não foi possível aceitar o convite.')
        return
      }

      feedback.success(
        'Convite aceito e vínculo com o estabelecimento criado com sucesso.',
      )
      loadPendingInvites()
      loadDashboard()
    })
}

function rejectInvite(inviteId: string) {
  return updateInviteStatus(inviteId, 'recusado')
}

const tutorialSteps = computed(() => {
  if (isOwnerEstabelecimento.value) {
    return [
      {
        title: 'Complete seu cadastro profissional',
        description:
          'Informe sua profissão, CRM/registro, conselho e UF. Essas informações aparecerão na agenda e para os pacientes.',
      },
      {
        title: 'Configure o estabelecimento',
        description:
          'Preencha dados básicos do estabelecimento e cadastre as salas de atendimento onde você e sua equipe irão trabalhar.',
      },
      {
        title: 'Cadastre e convide profissionais',
        description:
          'Convide outros profissionais para o estabelecimento e defina as permissões de acesso de cada um.',
      },
      {
        title: 'Organize a agenda',
        description:
          'Use a Gestão de atendimento para criar, confirmar e acompanhar os agendamentos do dia.',
      },
      {
        title: 'Registre os prontuários',
        description:
          'Para cada atendimento, registre as evoluções de prontuário com segurança e em conformidade com a LGPD.',
      },
    ]
  }

  return [
    {
      title: 'Complete seu cadastro profissional',
      description:
        'Informe sua profissão e, se você for médico, seu CRM, conselho e UF.',
    },
    {
      title: 'Escolha o estabelecimento onde irá atuar',
      description:
        'Aceite convites de estabelecimentos ou aguarde o administrador vincular seu usuário à unidade.',
    },
    {
      title: 'Organize sua agenda',
      description:
        'Acesse a Gestão de atendimento para visualizar seus agendamentos e o fluxo de pacientes.',
    },
    {
      title: 'Registre os prontuários',
      description:
        'Lance evoluções somente para pacientes que você atendeu, mantendo os dados em segurança.',
    },
  ]
})

onMounted(async () => {
  await Promise.all([
    loadDashboard(),
    loadTutorialState(),
    loadPendingInvites(),
    loadScheduleSummary(),
  ])
})
</script>

<template>
  <section class="relative p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">Painel inicial</h1>
        <p class="text-sm text-gray-500">
          Olá, aproveite para completar seu cadastro e começar a usar todas as
          funcionalidades da plataforma.
        </p>
      </div>

      <div class="flex items-center gap-3">
        <button
          class="text-xs text-primary-600 underline"
          type="button"
          @click="openTutorial"
        >
          Ver tutorial
        </button>
        <button
          class="text-xs text-gray-500 underline"
          type="button"
          @click="auth.logout"
        >
          Sair
        </button>
      </div>
    </header>

    <div class="space-y-4 max-w-5xl">
      <div
        v-if="pendingInvites.length"
        class="bg-white shadow-sm rounded-xl p-5 border border-primary-light"
      >
        <div class="flex items-center justify-between mb-3 gap-4">
          <div>
            <h2 class="text-sm font-semibold text-primary-700">
              Você tem convites pendentes
            </h2>
            <p class="text-xs text-gray-500">
              Aceite os convites para se vincular aos estabelecimentos que
              solicitaram sua participação.
            </p>
          </div>
        </div>
        <ul class="space-y-2 text-sm">
          <li
            v-for="invite in pendingInvites"
            :key="invite.id"
            class="flex items-start gap-3"
          >
            <div
              class="h-8 w-8 rounded-full bg-primary-light flex items-center justify-center text-primary-dark text-xs font-semibold overflow-hidden"
            >
              <img
                v-if="invite.estabelecimento_foto"
                :src="invite.estabelecimento_foto"
                alt="Logo do estabelecimento"
                class="h-full w-full object-cover"
              />
              <span v-else>
                {{ invite.estabelecimento_nome?.[0] ?? 'E' }}
              </span>
            </div>
            <div>
              <p class="text-gray-800">
                {{ invite.estabelecimento_nome || 'Estabelecimento' }}
              </p>
              <p class="text-xs text-gray-500">
                Este estabelecimento convidou você para atuar como
                profissional. Você pode aceitar ou recusar o convite abaixo.
              </p>
              <div class="mt-1 flex gap-3 text-xs">
                <button
                  class="text-primary-600 hover:underline font-semibold"
                  type="button"
                  @click="acceptInvite(invite.id)"
                >
                  Aceitar convite
                </button>
                <button
                  class="text-gray-500 hover:underline"
                  type="button"
                  @click="rejectInvite(invite.id)"
                >
                  Recusar
                </button>
              </div>
            </div>
          </li>
        </ul>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div
          class="bg-white shadow-sm rounded-xl p-4 border border-gray-100 flex flex-col gap-1"
        >
          <p class="text-xs text-gray-500">
            Agendamentos de hoje
          </p>
          <p class="text-2xl font-bold text-primary-dark">
            {{ scheduleSummary.totalHoje }}
          </p>
          <p class="text-[11px] text-gray-500">
            Atendimentos marcados para o dia atual.
          </p>
        </div>
        <div
          class="bg-white shadow-sm rounded-xl p-4 border border-gray-100 flex flex-col gap-1"
        >
          <p class="text-xs text-gray-500">
            Semana atual
          </p>
          <p class="text-2xl font-bold text-primary-dark">
            {{ scheduleSummary.totalSemana }}
          </p>
          <p class="text-[11px] text-gray-500">
            Total de agendamentos entre segunda e domingo.
          </p>
        </div>
        <div
          class="bg-white shadow-sm rounded-xl p-4 border border-gray-100 flex flex-col gap-1"
        >
          <p class="text-xs text-gray-500">
            Mês atual
          </p>
          <p class="text-2xl font-bold text-primary-dark">
            {{ scheduleSummary.totalMes }}
          </p>
          <p class="text-[11px] text-gray-500">
            Quantidade de atendimentos previstos neste mês.
          </p>
        </div>
      </div>
      <div
        v-if="!dashboard.profissionalCompleto"
        class="bg-white shadow-sm rounded-xl p-5 border border-gray-100"
      >
        <div class="flex items-center justify-between mb-2">
          <div>
            <h2 class="text-sm font-semibold text-primary-700">
              Complete seu cadastro e comece a usar.
            </h2>
            <p class="text-xs text-gray-500">
              Aproveite todas as funcionalidades preenchendo os dados que
              faltam.
            </p>
          </div>
          <button
            class="inline-flex items-center rounded-lg bg-primary-600 text-white text-xs font-semibold px-3 py-1.5"
            type="button"
            @click="goToProfessionalSetup"
          >
            Completar cadastro
          </button>
        </div>

        <div class="flex items-center justify-between mt-3">
	          <div class="flex items-center gap-2 text-xs text-gray-600">
	            <span class="font-medium text-primary-700">
	              {{ dashboard.cadastroProfissionalPercentual }}% cadastro do
	              profissional
	            </span>
	            <span>• {{ dashboard.tarefasPendentes }} tarefas pendentes</span>
          </div>
        </div>

        <div class="mt-2 h-2 w-full bg-gray-100 rounded-full overflow-hidden">
	          <div
	            class="h-full bg-green-500 rounded-full transition-all"
	            :style="{
	              width: `${dashboard.cadastroProfissionalPercentual}%`,
	            }"
          />
        </div>

        <div class="mt-4 flex justify-end">
          <button
            class="btn-primary max-w-xs text-xs font-semibold py-2"
            type="button"
            @click="goToProfessionalSetup"
          >
            Completar cadastro de profissional
          </button>
        </div>
      </div>

      <div
        v-if="isOwnerEstabelecimento && dashboard.cadastroEstabelecimentoPercentual < 100"
        class="bg-white shadow-sm rounded-xl p-5 border border-gray-100"
      >
        <div class="flex items-center justify-between mb-2">
          <div>
            <h2 class="text-sm font-semibold text-primary-700">
              Conclua o cadastro do seu estabelecimento.
            </h2>
            <p class="text-xs text-gray-500">
              Configure os dados básicos do estabelecimento para começar a
              atender.
            </p>
          </div>
          <button
            class="inline-flex items-center rounded-lg bg-primary-600 text-white text-xs font-semibold px-3 py-1.5"
            type="button"
            @click="goToEstablishmentSetup"
          >
            Configurar estabelecimento
          </button>
        </div>

        <div class="flex items-center justify-between mt-3">
          <div class="flex items-center gap-2 text-xs text-gray-600">
            <span class="font-medium text-primary-700">
              {{ dashboard.cadastroEstabelecimentoPercentual }}% cadastro do
              estabelecimento
            </span>
          </div>
        </div>

        <div class="mt-2 h-2 w-full bg-gray-100 rounded-full overflow-hidden">
          <div
            class="h-full bg-green-500 rounded-full transition-all"
            :style="{
              width: `${dashboard.cadastroEstabelecimentoPercentual}%`,
            }"
          />
        </div>

        <div class="mt-4 flex justify-end">
          <button
            class="btn-primary max-w-xs text-xs font-semibold py-2"
            type="button"
            @click="goToEstablishmentSetup"
          >
            Completar cadastro do estabelecimento
          </button>
        </div>
      </div>

      <div
        v-if="dashboard.tarefasPendentes === 0"
        class="bg-white shadow-sm rounded-xl p-5 border border-gray-100"
      >
        <div class="flex items-center justify-between mb-2">
          <div>
            <h2 class="text-sm font-semibold text-primary-700">
              Visão geral do dia
            </h2>
            <p class="text-xs text-gray-500">
              Aqui você verá seus próximos atendimentos, pacientes e alertas
              importantes para o dia.
            </p>
          </div>
        </div>
        <p class="text-sm text-gray-500">
          Em breve, este painel trará indicadores de agenda, pacientes e
          faturamento do seu estabelecimento.
        </p>
      </div>
    </div>

    <!-- Tutorial -->
    <div
      v-if="showTutorial"
      class="fixed inset-0 z-30 flex items-center justify-center bg-black/40 px-4"
    >
      <div
        class="w-full max-w-2xl bg-white rounded-2xl shadow-lg p-6 border border-primary-light"
      >
        <div class="flex items-start justify-between gap-4 mb-4">
          <div>
            <p class="text-xs font-semibold text-primary-medium uppercase">
              Passo a passo
            </p>
            <h2 class="text-lg font-bold text-primary-dark">
              Como começar a usar o imedto
            </h2>
            <p class="text-xs text-gray-600 mt-1">
              Siga os passos abaixo para deixar seu ambiente pronto para
              atendimento.
            </p>
          </div>
          <span
            class="inline-flex items-center rounded-full bg-primary-light text-primary-dark text-[10px] font-semibold px-3 py-1"
          >
            {{
              isOwnerEstabelecimento
                ? 'Perfil administrador de estabelecimento'
                : 'Perfil profissional'
            }}
          </span>
        </div>

        <ol class="space-y-3 mt-2">
          <li
            v-for="(step, index) in tutorialSteps"
            :key="step.title"
            class="flex gap-3 items-start"
          >
            <div
              class="mt-0.5 flex h-6 w-6 items-center justify-center rounded-full bg-primary text-white text-xs font-semibold"
            >
              {{ index + 1 }}
            </div>
            <div>
              <p class="text-sm font-semibold text-primary-dark">
                {{ step.title }}
              </p>
              <p class="text-xs text-gray-600">
                {{ step.description }}
              </p>
            </div>
          </li>
        </ol>

        <div class="flex justify-between items-center mt-6 gap-3">
          <button
            class="text-xs text-gray-500 underline"
            type="button"
            @click="dismissTutorialForNow"
          >
            Ver depois
          </button>
          <button
            class="inline-flex items-center rounded-lg bg-primary-600 text-white text-xs font-semibold px-4 py-2"
            type="button"
            @click="finishTutorial"
          >
            Entendi, começar a usar
          </button>
        </div>
      </div>
    </div>

    <div
      v-if="isLoadingDashboard"
      class="absolute inset-0 pointer-events-none flex items-start justify-center pt-4"
    >
      <span class="text-xs text-gray-400 bg-white/80 rounded-full px-3 py-1">
        Carregando painel...
      </span>
    </div>
  </section>
</template>
