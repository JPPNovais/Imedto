<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import { onlyDigits } from '@/utils/masks'

type Evento = {
  id: string
  data_hora_inicio: string
  data_hora_fim: string | null
  titulo: string | null
  status: string
  paciente_id: string | null
  paciente_nome: string | null
}

type Periodo = 'dia' | 'semana' | 'mes'

const auth = useAuthStore()
const feedback = useFeedbackStore()

const isLoading = ref(false)
const events = reactive<Evento[]>([])
const activePeriod = ref<Periodo>('dia')
const selectedDate = ref<string>(new Date().toISOString().substring(0, 10))
const profissionalId = ref<string | null>(null)
const estabelecimentoId = ref<string | null>(null)

const isCreating = ref(false)
const createForm = reactive({
  date: new Date().toISOString().substring(0, 10),
  time: '09:00',
  title: '',
})

const isLinkingPatient = ref(false)
const eventToLink = ref<Evento | null>(null)
const patientForm = reactive({
  documento: '',
  nome: '',
  telefone: '',
})
const foundPatientId = ref<string | null>(null)
const isSearchingPatient = ref(false)

function getRange(period: Periodo) {
  const base = selectedDate.value
    ? new Date(selectedDate.value + 'T00:00:00')
    : new Date()
  const start = new Date(base)
  let end = new Date(base)

  if (period === 'dia') {
    end.setDate(start.getDate() + 1)
  } else if (period === 'semana') {
    const day = start.getDay()
    const diffToMonday = (day + 6) % 7
    start.setDate(start.getDate() - diffToMonday)
    end = new Date(start)
    end.setDate(start.getDate() + 7)
  } else if (period === 'mes') {
    start.setDate(1)
    end = new Date(start)
    end.setMonth(start.getMonth() + 1)
  }

  return {
    start: start.toISOString(),
    end: end.toISOString(),
  }
}

async function loadEvents() {
  isLoading.value = true
  events.splice(0, events.length)
  try {
    const { start, end } = getRange(activePeriod.value)

    let query = supabase
      .from('evento_de_agendamento')
      .select(
        `
        id,
        data_hora_inicio,
        data_hora_fim,
        titulo,
        status,
        paciente_id,
        paciente:pacientes ( nome_completo )
      `,
      )
      .gte('data_hora_inicio', start)
      .lt('data_hora_inicio', end)
      .order('data_hora_inicio', { ascending: true })

    if (profissionalId.value) {
      query = query.eq('profissional_id', profissionalId.value)
    }

    const { data, error } = await query

    if (error) {
      console.error(error)
      return
    }

    if (data) {
      data.forEach((e: any) =>
        events.push({
          id: e.id,
          data_hora_inicio: e.data_hora_inicio,
          data_hora_fim: e.data_hora_fim,
          titulo: e.titulo,
          status: e.status,
          paciente_id: e.paciente_id,
          paciente_nome: e.paciente?.nome_completo ?? null,
        }),
      )
    }
  } finally {
    isLoading.value = false
  }
}

const periodLabel = computed(() => {
  if (activePeriod.value === 'dia') return 'Agenda do dia'
  if (activePeriod.value === 'semana') return 'Agenda da semana'
  return 'Agenda do mês'
})

async function loadContext() {
  if (!auth.currentUser?.id) return

  const { data: profissional, error: profError } = await supabase
    .from('profissionais')
    .select('id')
    .eq('usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (profError) {
    console.error(profError)
  }

  if (profissional?.id) {
    profissionalId.value = profissional.id

    const { data: vinculo, error: vincError } = await supabase
      .from('vinculo_profissional_estabelecimento')
      .select('estabelecimento_id')
      .eq('profissional_id', profissional.id)
      .limit(1)
      .maybeSingle()

    if (!vincError && vinculo?.estabelecimento_id) {
      estabelecimentoId.value = vinculo.estabelecimento_id
    }
  }
}

async function createEvent() {
  if (!estabelecimentoId.value || !profissionalId.value) {
    feedback.error(
      'Não foi possível identificar o profissional ou estabelecimento. Verifique seu cadastro.',
    )
    return
  }

  if (!createForm.date || !createForm.time) {
    feedback.error('Informe data e horário para o agendamento.')
    return
  }

  const start = new Date(`${createForm.date}T${createForm.time}:00`)
  const end = new Date(start)
  end.setMinutes(start.getMinutes() + 30)

  const { error } = await supabase.from('evento_de_agendamento').insert({
    estabelecimento_id: estabelecimentoId.value,
    profissional_id: profissionalId.value,
    data_hora_inicio: start.toISOString(),
    data_hora_fim: end.toISOString(),
    titulo: createForm.title || null,
    status: 'agendado',
  })

  if (error) {
    console.error(error)
    feedback.error('Não foi possível criar o agendamento.')
    return
  }

  feedback.success('Agendamento criado com sucesso.')
  isCreating.value = false
  createForm.title = ''
  createForm.date = selectedDate.value
  createForm.time = '09:00'
  await loadEvents()
}

function openCreateModal() {
  isCreating.value = true
  createForm.date = selectedDate.value
}

function openPatientModal(event: Evento) {
  eventToLink.value = event
  isLinkingPatient.value = true
  patientForm.documento = ''
  patientForm.nome = ''
  patientForm.telefone = ''
  foundPatientId.value = null
}

async function searchPatient() {
  if (!patientForm.documento) {
    feedback.error('Informe o CPF ou documento para buscar o paciente.')
    return
  }

  const doc = onlyDigits(patientForm.documento)
  if (!doc) {
    feedback.error('Documento inválido.')
    return
  }

  isSearchingPatient.value = true
  try {
    const { data, error } = await supabase
      .from('pacientes')
      .select('id, nome_completo, cpf_cnpj, telefone')
      .eq('cpf_cnpj', doc)
      .maybeSingle()

    if (error) {
      console.error(error)
      feedback.error('Erro ao buscar paciente.')
      return
    }

    if (data) {
      foundPatientId.value = data.id
      patientForm.nome = data.nome_completo ?? ''
      patientForm.telefone = data.telefone ?? ''
    } else {
      foundPatientId.value = null
      feedback.info(
        'Nenhum paciente encontrado. Preencha os dados para criar um novo.',
      )
    }
  } finally {
    isSearchingPatient.value = false
  }
}

async function savePatientLink() {
  if (!eventToLink.value) return
  if (!estabelecimentoId.value) {
    feedback.error(
      'Não foi possível identificar o estabelecimento para vincular o paciente.',
    )
    return
  }

  if (!patientForm.nome) {
    feedback.error('Informe o nome do paciente.')
    return
  }

  const docDigits = onlyDigits(patientForm.documento)
  let pacienteId = foundPatientId.value

  if (!pacienteId) {
    const { data: novo, error: pacError } = await supabase
      .from('pacientes')
      .insert({
        nome_completo: patientForm.nome,
        cpf_cnpj: docDigits || null,
        telefone: patientForm.telefone || null,
      })
      .select('id')
      .single()

    if (pacError || !novo) {
      console.error(pacError)
      feedback.error('Não foi possível criar o paciente.')
      return
    }
    pacienteId = novo.id
  }

  const { error: vincError } = await supabase
    .from('paciente_estabelecimento')
    .upsert(
      {
        paciente_id: pacienteId,
        estabelecimento_id: estabelecimentoId.value,
      },
      { onConflict: 'paciente_id,estabelecimento_id' },
    )

  if (vincError) {
    console.error(vincError)
    feedback.error('Não foi possível vincular o paciente ao estabelecimento.')
    return
  }

  const { error: evError } = await supabase
    .from('evento_de_agendamento')
    .update({ paciente_id: pacienteId })
    .eq('id', eventToLink.value.id)

  if (evError) {
    console.error(evError)
    feedback.error('Não foi possível vincular o paciente ao agendamento.')
    return
  }

  feedback.success('Paciente vinculado ao agendamento com sucesso.')
  isLinkingPatient.value = false
  await loadEvents()
}

watch([activePeriod, selectedDate], () => {
  loadEvents()
})

onMounted(() => {
  loadContext().then(() => loadEvents())
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Gestão de atendimento
        </h1>
        <p class="text-sm text-gray-500">
          Visualize e organize os seus agendamentos por dia, semana ou mês.
        </p>
      </div>
      <button
        class="inline-flex items-center rounded-lg bg-primary-600 text-white text-xs font-semibold px-4 py-2"
        type="button"
        @click="openCreateModal"
      >
        Novo agendamento
      </button>
    </header>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
      <div
        class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mb-4"
      >
        <div class="flex items-center gap-3">
          <div
            class="inline-flex rounded-full bg-gray-50 p-1 text-xs font-semibold text-gray-600"
          >
            <button
              class="px-3 py-1 rounded-full"
              :class="
                activePeriod === 'dia'
                  ? 'bg-white text-primary-700 shadow-sm'
                  : ''
              "
              type="button"
              @click="activePeriod = 'dia'"
            >
              Dia
            </button>
            <button
              class="px-3 py-1 rounded-full"
              :class="
                activePeriod === 'semana'
                  ? 'bg-white text-primary-700 shadow-sm'
                  : ''
              "
              type="button"
              @click="activePeriod = 'semana'"
            >
              Semana
            </button>
            <button
              class="px-3 py-1 rounded-full"
              :class="
                activePeriod === 'mes'
                  ? 'bg-white text-primary-700 shadow-sm'
                  : ''
              "
              type="button"
              @click="activePeriod = 'mes'"
            >
              Mês
            </button>
          </div>
        </div>
        <div class="flex items-center gap-4 text-xs">
          <div class="flex items-center gap-2">
            <label class="text-gray-600" for="agenda-date">Referência:</label>
            <input
              id="agenda-date"
              v-model="selectedDate"
              class="form-input text-xs py-1 px-2 w-32"
              type="date"
            />
            <button
              class="text-primary-600 underline"
              type="button"
              @click="loadEvents"
            >
              Atualizar
            </button>
          </div>
          <button
            class="hidden md:inline-flex items-center rounded-lg border border-primary-600 text-primary-600 text-xs font-semibold px-3 py-1.5 hover:bg-primary-light"
            type="button"
            @click="openCreateModal"
          >
            + Novo agendamento
          </button>
        </div>
      </div>

      <h2 class="text-sm font-semibold text-primary-700 mb-2">
        {{ periodLabel }}
      </h2>

      <div v-if="isLoading" class="text-xs text-gray-400">
        Carregando agendamentos...
      </div>
      <div v-else-if="!events.length" class="text-sm text-gray-500">
        Nenhum agendamento para o período selecionado.
      </div>
      <ul v-else class="divide-y divide-gray-100">
        <li
          v-for="event in events"
          :key="event.id"
          class="py-2 flex items-center justify-between text-sm"
        >
          <div>
            <p class="font-medium text-gray-800">
              {{ event.titulo || 'Atendimento' }}
            </p>
            <p class="text-xs text-gray-500">
              {{ new Date(event.data_hora_inicio).toLocaleString() }}
            </p>
            <p class="text-xs text-gray-500">
              Paciente:
              <span class="font-medium">
                {{ event.paciente_nome || 'Não vinculado' }}
              </span>
            </p>
          </div>
          <div class="flex items-center gap-3">
            <span
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
              :class="[
                event.status === 'agendado' && 'bg-gray-100 text-gray-700',
                event.status === 'confirmado' && 'bg-green-100 text-green-700',
                event.status === 'cancelado' && 'bg-red-100 text-red-700',
                event.status === 'concluido' && 'bg-primary-100 text-primary-700',
              ]"
            >
              {{ event.status }}
            </span>
            <button
              v-if="!event.paciente_id"
              class="text-xs text-primary-600 underline"
              type="button"
              @click="openPatientModal(event)"
            >
              Cadastrar paciente
            </button>
          </div>
        </li>
      </ul>
    </div>

    <!-- Modal de novo agendamento -->
    <div
      v-if="isCreating"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
    >
      <div class="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          Novo agendamento
        </h2>
        <form class="space-y-4" @submit.prevent="createEvent">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Data
              </label>
              <input
                v-model="createForm.date"
                class="form-input text-xs"
                type="date"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Horário
              </label>
              <input
                v-model="createForm.time"
                class="form-input text-xs"
                type="time"
              />
            </div>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Título (opcional)
            </label>
            <input
              v-model="createForm.title"
              class="form-input text-xs"
              placeholder="Ex.: Consulta João"
              type="text"
            />
          </div>
          <div class="flex justify-end gap-3 mt-4">
            <button
              class="text-xs text-gray-500 underline"
              type="button"
              @click="isCreating.value = false"
            >
              Cancelar
            </button>
            <button
              class="btn-primary max-w-[140px] text-xs py-2"
              type="submit"
            >
              Salvar agendamento
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Modal de vínculo de paciente -->
    <div
      v-if="isLinkingPatient"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
    >
      <div class="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-2">
          Vincular paciente ao agendamento
        </h2>
        <p class="text-xs text-gray-500 mb-4">
          Primeiro informe o CPF ou documento do paciente para buscá-lo. Caso
          não exista, será criado um novo cadastro básico.
        </p>
        <form class="space-y-4" @submit.prevent="savePatientLink">
          <div class="flex gap-2 items-end">
            <div class="flex-1">
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                CPF / Documento
              </label>
              <input
                v-model="patientForm.documento"
                class="form-input text-xs"
                placeholder="Digite o CPF ou documento"
                type="text"
              />
            </div>
            <button
              class="text-xs text-primary-600 underline"
              type="button"
              @click="searchPatient"
            >
              {{ isSearchingPatient ? 'Buscando...' : 'Buscar' }}
            </button>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Nome completo
            </label>
            <input
              v-model="patientForm.nome"
              class="form-input text-xs"
              placeholder="Nome do paciente"
              type="text"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Telefone (opcional)
            </label>
            <input
              v-model="patientForm.telefone"
              class="form-input text-xs"
              placeholder="( ) _____-____"
              type="text"
            />
          </div>
          <div class="flex justify-end gap-3 mt-4">
            <button
              class="text-xs text-gray-500 underline"
              type="button"
              @click="isLinkingPatient.value = false"
            >
              Cancelar
            </button>
            <button
              class="btn-primary max-w-[160px] text-xs py-2"
              type="submit"
            >
              Salvar e vincular
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>
