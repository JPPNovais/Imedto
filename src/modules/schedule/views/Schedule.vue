<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { NDatePicker, NConfigProvider, datePtBR, ptBR } from 'naive-ui'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import { onlyDigits, formatPhone, formatCep, formatCpfCnpj } from '@/utils/masks'
import { fetchAddressByCep } from '@/utils/viaCep'

type Evento = {
  id: string
  data_hora_inicio: string
  data_hora_fim: string | null
  status: string
  tipo_consulta: string | null
  paciente_id: string | null
  paciente_nome: string | null
  profissional_id: string | null
  especialidade_id: string | null
  paciente_nome_agenda: string | null
  paciente_telefone_agenda: string | null
  profissional_nome: string | null
  especialidade_nome: string | null
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
const filterProfessionalId = ref<string>('')
const filterSpecialtyId = ref<string>('')

const selectedDateTimestamp = computed<number | null>({
  get() {
    if (!selectedDate.value) return null
    return new Date(selectedDate.value + 'T00:00:00').getTime()
  },
  set(value) {
    if (!value) return
    const d = new Date(value)
    selectedDate.value = d.toISOString().substring(0, 10)
  },
})

const isCreating = ref(false)
const editingEventId = ref<string | null>(null)
const createForm = reactive({
  date: new Date().toISOString().substring(0, 10),
  time: '09:00',
  title: '',
  durationMinutes: 30,
  tipoConsulta: 'consulta',
  patientName: '',
  patientPhone: '',
  specialtyId: '',
  professionalId: '',
})

const isLinkingPatient = ref(false)
const eventToLink = ref<Evento | null>(null)
const patientForm = reactive({
  documento: '',
  nome: '',
  celular: '',
  telefoneFixo: '',
  dataNascimento: '',
  sexo: '',
  cep: '',
  logradouro: '',
  numero: '',
  complemento: '',
  bairro: '',
  cidade: '',
  estado: '',
})
const foundPatientId = ref<string | null>(null)
const isSearchingPatient = ref(false)

type ProfessionalOption = {
  id: string
  nome: string
  especialidadeId: string | null
  especialidadeNome: string | null
}

type SpecialtyOption = {
  id: string
  nome: string
}

const professionalOptions = ref<ProfessionalOption[]>([])
const specialtyOptions = ref<SpecialtyOption[]>([])
const occupiedSlots = ref<string[]>([])

const filteredProfessionalOptions = computed(() => {
  if (!createForm.specialtyId) return professionalOptions.value
  return professionalOptions.value.filter(
    (p) => p.especialidadeId === createForm.specialtyId,
  )
})

watch(
  () => createForm.specialtyId,
  (newId) => {
    if (!newId) return
    const currentProf = professionalOptions.value.find(
      (p) => p.id === createForm.professionalId,
    )
    if (currentProf && currentProf.especialidadeId === newId) return
    const profForSpec = professionalOptions.value.find(
      (p) => p.especialidadeId === newId,
    )
    if (profForSpec) {
      createForm.professionalId = profForSpec.id
    }
  },
)

watch(
  () => createForm.professionalId,
  (newId) => {
    if (!newId) return
    const prof = professionalOptions.value.find((p) => p.id === newId)
    if (prof?.especialidadeId && createForm.specialtyId !== prof.especialidadeId) {
      createForm.specialtyId = prof.especialidadeId
    }
  },
)

watch(filterProfessionalId, () => {
  loadEvents()
})

watch(filterSpecialtyId, () => {
  loadEvents()
})

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
        status,
        tipo_consulta,
        paciente_id,
        paciente:pacientes ( nome_completo ),
        profissional_id,
        profissional:profissionais (
          nome_exibicao,
          especialidade:especialidades ( nome )
        ),
        especialidade_id,
        paciente_nome_agenda,
        paciente_telefone_agenda
      `,
      )
      .gte('data_hora_inicio', start)
      .lt('data_hora_inicio', end)
      .order('data_hora_inicio', { ascending: true })

    if (estabelecimentoId.value) {
      query = query.eq('estabelecimento_id', estabelecimentoId.value)
    }

    if (filterProfessionalId.value) {
      query = query.eq('profissional_id', filterProfessionalId.value)
    }

    if (filterSpecialtyId.value) {
      query = query.eq('especialidade_id', filterSpecialtyId.value)
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
          status: e.status,
          tipo_consulta: e.tipo_consulta ?? null,
          paciente_id: e.paciente_id,
          paciente_nome: e.paciente?.nome_completo ?? null,
          profissional_id: e.profissional_id ?? null,
          especialidade_id: e.especialidade_id ?? null,
          paciente_nome_agenda: e.paciente_nome_agenda ?? null,
          paciente_telefone_agenda: e.paciente_telefone_agenda ?? null,
          profissional_nome: e.profissional?.nome_exibicao ?? null,
          especialidade_nome: e.profissional?.especialidade?.nome ?? null,
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
    .select(`
      id,
      especialidade:especialidades ( id, nome )
    `)
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

  if (estabelecimentoId.value) {
    const { data: vinculos, error: vincsError } = await supabase
      .from('vinculo_profissional_estabelecimento')
      .select(`
        profissional_id,
        profissional:profissionais (
          id,
          nome_exibicao,
          profissao:profissoes ( nome ),
          especialidade:especialidades ( id, nome )
        )
      `)
      .eq('estabelecimento_id', estabelecimentoId.value)
      .eq('ativo', true)

    if (vincsError) {
      console.error(vincsError)
    } else if (vinculos) {
      const list: ProfessionalOption[] = []
      const specialtyMap = new Map<string, string>()

      vinculos.forEach((v: any) => {
        const p = v.profissional
        if (!p) return

        // opcional: filtra só médicos (ou outra profissão), se desejar
        // if (!p.profissao?.nome?.toLowerCase().startsWith('médico')) return

        const esp = p.especialidade

        list.push({
          id: p.id,
          nome: p.nome_exibicao ?? 'Profissional',
          especialidadeId: esp?.id ?? null,
          especialidadeNome: esp?.nome ?? null,
        })

        if (esp?.id && esp.nome && !specialtyMap.has(esp.id)) {
          specialtyMap.set(esp.id, esp.nome)
        }
      })

      professionalOptions.value = list
      specialtyOptions.value = Array.from(specialtyMap.entries()).map(
        ([id, nome]) => ({ id, nome }),
      )

      const defaultProf =
        list.find((p) => p.id === profissionalId.value) ?? list[0]
      if (defaultProf) {
        createForm.professionalId = defaultProf.id
      }
    }
  }
}

async function createEvent() {
  if (!estabelecimentoId.value) {
    feedback.error(
      'Não foi possível identificar o estabelecimento. Verifique seu cadastro.',
    )
    return
  }

  const selectedProfessionalId =
    createForm.professionalId || profissionalId.value

  if (!selectedProfessionalId) {
    feedback.error(
      'Selecione o profissional responsável por este agendamento.',
    )
    return
  }

  if (!createForm.date || !createForm.time) {
    feedback.error('Informe data e horário para o agendamento.')
    return
  }

  if (!createForm.patientName) {
    feedback.error('Informe o nome do paciente.')
    return
  }

  const start = new Date(`${createForm.date}T${createForm.time}:00`)
  const end = new Date(start)
  end.setMinutes(start.getMinutes() + (createForm.durationMinutes || 30))

  // verifica conflitos na agenda do profissional para o dia selecionado
  const dayStart = new Date(createForm.date + 'T00:00:00').toISOString()
  const dayEnd = new Date(createForm.date + 'T00:00:00')
  dayEnd.setDate(dayEnd.getDate() + 1)

  let conflitosQuery = supabase
    .from('evento_de_agendamento')
    .select('id, data_hora_inicio, data_hora_fim')
    .eq('profissional_id', selectedProfessionalId)
    .gte('data_hora_inicio', dayStart)
    .lt('data_hora_inicio', dayEnd.toISOString())

  // quando estiver editando, ignora o próprio evento no cálculo de conflito
  if (editingEventId.value) {
    conflitosQuery = conflitosQuery.neq('id', editingEventId.value)
  }

  const { data: conflitos, error: confError } = await conflitosQuery

  if (confError) {
    console.error(confError)
  }

  const newStartMs = start.getTime()
  const newEndMs = end.getTime()

  let hasOverlap = false

  occupiedSlots.value =
    conflitos?.map((c: any) => {
      const existingStart = new Date(c.data_hora_inicio)
      const existingEnd = c.data_hora_fim
        ? new Date(c.data_hora_fim)
        : new Date(existingStart.getTime() + (createForm.durationMinutes || 30) * 60000)

      if (!hasOverlap) {
        const existingStartMs = existingStart.getTime()
        const existingEndMs = existingEnd.getTime()
        if (newStartMs < existingEndMs && newEndMs > existingStartMs) {
          hasOverlap = true
        }
      }

      const startStr = existingStart.toTimeString().slice(0, 5)
      const endStr = existingEnd.toTimeString().slice(0, 5)
      return `${startStr}-${endStr}`
    }) ?? []

  if (hasOverlap) {
    feedback.error(
      'Já existe um agendamento nesse intervalo de horário para este profissional.',
    )
    return
  }

  const payload = {
    estabelecimento_id: estabelecimentoId.value,
    profissional_id: selectedProfessionalId,
    data_hora_inicio: start.toISOString(),
    data_hora_fim: end.toISOString(),
    tipo_consulta: createForm.tipoConsulta || null,
    paciente_nome_agenda: createForm.patientName,
    paciente_telefone_agenda: createForm.patientPhone || null,
    especialidade_id: createForm.specialtyId || null,
  }

  const baseMutation = supabase.from('evento_de_agendamento')

  const { error } = editingEventId.value
    ? await baseMutation
        .update({
          ...payload,
        })
        .eq('id', editingEventId.value)
    : await baseMutation.insert({
        ...payload,
        status: 'agendado',
      })

  if (error) {
    console.error(error)
    feedback.error('Não foi possível criar o agendamento.')
    return
  }

  feedback.success('Agendamento criado com sucesso.')
  isCreating.value = false
  editingEventId.value = null
  createForm.date = selectedDate.value
  createForm.time = '09:00'
  createForm.durationMinutes = 30
  createForm.tipoConsulta = 'consulta'
  createForm.patientName = ''
  createForm.patientPhone = ''
  createForm.specialtyId = ''
  createForm.professionalId = profissionalId.value || ''
  await loadEvents()
}

function closeCreateModal() {
  isCreating.value = false
  occupiedSlots.value = []
  editingEventId.value = null
}

function openCreateModal() {
  isCreating.value = true
  editingEventId.value = null
  createForm.date = selectedDate.value
  createForm.time = '09:00'
  createForm.durationMinutes = 30
  createForm.tipoConsulta = 'consulta'
  createForm.patientName = ''
  createForm.patientPhone = ''
  createForm.specialtyId = ''
  createForm.professionalId = profissionalId.value || ''
}

function openEditModal(event: Evento) {
  editingEventId.value = event.id
  isCreating.value = true

  const start = new Date(event.data_hora_inicio)
  const end = event.data_hora_fim ? new Date(event.data_hora_fim) : null
  const duration =
    end && end.getTime() > start.getTime()
      ? Math.round((end.getTime() - start.getTime()) / 60000)
      : 30

  createForm.date = start.toISOString().substring(0, 10)
  createForm.time = start.toTimeString().slice(0, 5)
  createForm.durationMinutes = duration
  createForm.patientName =
    event.paciente_nome_agenda || event.paciente_nome || ''
  createForm.patientPhone = event.paciente_telefone_agenda || ''
  createForm.specialtyId = event.especialidade_id || ''
  createForm.professionalId = event.profissional_id || profissionalId.value || ''
  createForm.tipoConsulta = event.tipo_consulta || 'consulta'
}

function openPatientModal(event: Evento) {
  eventToLink.value = event
  isLinkingPatient.value = true
  patientForm.documento = ''
  patientForm.nome = ''
  patientForm.celular = ''
  patientForm.telefoneFixo = ''
  patientForm.dataNascimento = ''
  patientForm.sexo = ''
  patientForm.cep = ''
  patientForm.logradouro = ''
  patientForm.numero = ''
  patientForm.complemento = ''
  patientForm.bairro = ''
  patientForm.cidade = ''
  patientForm.estado = ''
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
      .select(
        'id, nome_completo, cpf_cnpj, telefone, telefone_celular, telefone_fixo, data_nascimento, sexo, cep, logradouro, numero, complemento, bairro, cidade, estado',
      )
      .eq('cpf_cnpj', doc)
      .eq('estabelecimento_id', estabelecimentoId.value)
      .maybeSingle()

    if (error) {
      console.error(error)
      feedback.error('Erro ao buscar paciente.')
      return
    }

    if (data) {
      foundPatientId.value = data.id
      patientForm.nome = data.nome_completo ?? ''
      patientForm.celular = data.telefone_celular
        ? data.telefone_celular
        : data.telefone ?? ''
      patientForm.telefoneFixo = data.telefone_fixo ?? ''
      patientForm.dataNascimento = data.data_nascimento ?? ''
      patientForm.sexo = data.sexo ?? ''
      patientForm.cep = data.cep ?? ''
      patientForm.logradouro = data.logradouro ?? ''
      patientForm.numero = data.numero ?? ''
      patientForm.complemento = data.complemento ?? ''
      patientForm.bairro = data.bairro ?? ''
      patientForm.cidade = data.cidade ?? ''
      patientForm.estado = data.estado ?? ''
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
    const celular = patientForm.celular || ''
    const fixo = patientForm.telefoneFixo || ''

    const { data: novoId, error: pacError } = await supabase.rpc(
      'criar_paciente_e_vincular',
      {
        p_nome_completo: patientForm.nome,
        p_cpf_cnpj: docDigits || null,
        p_telefone: celular || fixo || null,
        p_data_nascimento: patientForm.dataNascimento || null,
        p_sexo: patientForm.sexo || 'nao_informado',
        p_cep: patientForm.cep || null,
        p_logradouro: patientForm.logradouro || null,
        p_numero: patientForm.numero || null,
        p_complemento: patientForm.complemento || null,
        p_bairro: patientForm.bairro || null,
        p_cidade: patientForm.cidade || null,
        p_estado: patientForm.estado || null,
        p_estabelecimento_id: estabelecimentoId.value,
      },
    )

    if (pacError || !novoId) {
      console.error(pacError)
      feedback.error('Não foi possível criar o paciente.')
      return
    }
    pacienteId = novoId as string
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

async function confirmEvent(event: Evento) {
  const { error } = await supabase
    .from('evento_de_agendamento')
    .update({ status: 'confirmado' })
    .eq('id', event.id)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível confirmar o agendamento.')
    return
  }

  feedback.success('Agendamento confirmado com sucesso.')
  await loadEvents()
}

async function onCepBlur() {
  if (!patientForm.cep) return
  try {
    const address = await fetchAddressByCep(patientForm.cep)
    if (!address) return

    patientForm.cep = address.cep
    if (!patientForm.logradouro) patientForm.logradouro = address.logradouro
    if (!patientForm.bairro) patientForm.bairro = address.bairro
    if (!patientForm.cidade) patientForm.cidade = address.localidade
    if (!patientForm.estado) patientForm.estado = address.uf
    if (!patientForm.complemento && address.complemento) {
      patientForm.complemento = address.complemento
    }
  } catch (e) {
    console.error(e)
  }
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
        <div class="flex flex-col gap-3">
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
          <div class="flex flex-wrap items-center gap-3 text-xs">
            <div>
              <label class="block text-[11px] text-gray-600 mb-0.5">
                Filtrar por especialidade
              </label>
              <select
                v-model="filterSpecialtyId"
                class="form-input text-[11px] h-7 w-44 text-gray-700 bg-white p-0 pl-2"
              >
                <option value="">
                  Todas as especialidades
                </option>
                <option
                  v-for="esp in specialtyOptions"
                  :key="esp.id"
                  :value="esp.id"
                >
                  {{ esp.nome }}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-[11px] text-gray-600 mb-0.5">
                Filtrar por profissional
              </label>
              <select
                v-model="filterProfessionalId"
                class="form-input text-[11px] h-7 w-48 text-gray-700 bg-white p-0 pl-2"
              >
                <option value="">
                  Todos os profissionais
                </option>
                <option
                  v-for="prof in professionalOptions"
                  :key="prof.id"
                  :value="prof.id"
                >
                  {{
                    prof.especialidadeNome
                      ? `${prof.nome} - ${prof.especialidadeNome}`
                      : prof.nome
                  }}
                </option>
              </select>
            </div>
          </div>
        </div>
        <div class="flex flex-col items-end gap-3 text-xs">
          <button
            class="hidden md:inline-flex items-center rounded-lg border border-primary-600 text-primary-600 text-xs font-semibold px-3 py-1.5 hover:bg-primary-light"
            type="button"
            @click="openCreateModal"
          >
            + Novo agendamento
          </button>
        </div>
      </div>

      <div class="mt-4 flex flex-col md:flex-row gap-6">
        <div class="md:w-[320px]">
          <span class="block text-[11px] text-gray-600 mb-1">
            Calendário
          </span>
          <div
            class="bg-gray-50 border border-gray-100 rounded-lg p-2 shadow-sm overflow-hidden"
          >
            <n-config-provider :locale="ptBR" :date-locale="datePtBR">
              <n-date-picker
                v-model:value="selectedDateTimestamp"
                type="date"
                panel
                size="small"
                class="calendar-compact"
                style="height: 360px"
              />
            </n-config-provider>
          </div>
        </div>

        <div class="flex-1">
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
                  {{
                    event.paciente_nome ||
                    event.paciente_nome_agenda ||
                    'Atendimento'
                  }}
                </p>
                <p class="text-xs text-gray-500">
                  {{
                    new Date(event.data_hora_inicio).toLocaleString()
                  }}
                  <span v-if="event.tipo_consulta" class="ml-1">
                    ·
                    {{
                      event.tipo_consulta === 'consulta'
                        ? 'Consulta'
                        : event.tipo_consulta === 'retorno'
                          ? 'Retorno'
                          : event.tipo_consulta === 'procedimento'
                            ? 'Procedimento'
                            : event.tipo_consulta === 'exame'
                              ? 'Exame'
                              : 'Outro'
                    }}
                  </span>
                </p>
                <p class="text-xs text-gray-500">
                  Profissional:
                  <span class="font-medium">
                    {{
                      event.profissional_nome || 'Não informado'
                    }}
                  </span>
                  <span v-if="event.especialidade_nome" class="ml-1">
                    · {{ event.especialidade_nome }}
                  </span>
                </p>
              </div>
              <div class="flex items-center gap-3">
                <span
                  class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
                  :class="[
                    event.status === 'agendado' && 'bg-gray-100 text-gray-700',
                    event.status === 'confirmado' &&
                      'bg-green-100 text-green-700',
                    event.status === 'cancelado' && 'bg-red-100 text-red-700',
                    event.status === 'concluido' &&
                      'bg-primary-100 text-primary-700',
                  ]"
                >
                  {{
                    event.status === 'agendado'
                      ? 'Agendado'
                      : event.status === 'confirmado'
                        ? 'Confirmado'
                        : event.status === 'cancelado'
                          ? 'Cancelado'
                          : 'Concluído'
                  }}
                </span>
                <button
                  v-if="event.status === 'agendado'"
                  class="text-xs text-primary-600 underline"
                  type="button"
                  @click="confirmEvent(event)"
                >
                  Confirmar
                </button>
                <button
                  class="text-xs text-primary-600 underline"
                  type="button"
                  @click="openEditModal(event)"
                >
                  Editar
                </button>
                <button
                  v-if="event.status === 'confirmado' && !event.paciente_id"
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
      </div>
    </div>

    <!-- Modal de novo agendamento -->
    <div
      v-if="isCreating"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
    >
      <div class="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          {{ editingEventId ? 'Editar agendamento' : 'Novo agendamento' }}
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
              Duração da consulta
            </label>
            <select
              v-model.number="createForm.durationMinutes"
              class="form-input text-xs"
            >
              <option :value="15">
                15 minutos
              </option>
              <option :value="30">
                30 minutos
              </option>
              <option :value="45">
                45 minutos
              </option>
              <option :value="60">
                60 minutos
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Tipo da consulta
            </label>
            <select
              v-model="createForm.tipoConsulta"
              class="form-input text-xs"
            >
              <option value="consulta">
                Consulta
              </option>
              <option value="retorno">
                Retorno
              </option>
              <option value="procedimento">
                Procedimento
              </option>
              <option value="exame">
                Exame
              </option>
              <option value="outro">
                Outro
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Especialidade
            </label>
            <select
              v-model="createForm.specialtyId"
              class="form-input text-xs"
            >
              <option value="">
                Selecione
              </option>
              <option
                v-for="esp in specialtyOptions"
                :key="esp.id"
                :value="esp.id"
              >
                {{ esp.nome }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Profissional
            </label>
            <select
              v-model="createForm.professionalId"
              class="form-input text-xs"
            >
              <option value="">
                Selecione
              </option>
              <option
                v-for="prof in filteredProfessionalOptions"
                :key="prof.id"
                :value="prof.id"
              >
                {{ prof.nome }}
                <span v-if="prof.especialidadeNome">
                  - {{ prof.especialidadeNome }}
                </span>
              </option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Nome do paciente
            </label>
            <input
              v-model="createForm.patientName"
              class="form-input text-xs"
              placeholder="Nome do paciente"
              type="text"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Telefone do paciente (opcional)
            </label>
            <input
              v-model="createForm.patientPhone"
              class="form-input text-xs"
              placeholder="( ) _____-____"
              type="text"
              maxlength="15"
              @input="createForm.patientPhone = formatPhone(createForm.patientPhone)"
            />
          </div>
          <div v-if="occupiedSlots.length" class="text-[11px] text-gray-500">
            Horários já ocupados neste dia:
            <span class="font-semibold">
              {{ occupiedSlots.join(', ') }}
            </span>
          </div>
          <div class="flex justify-end gap-3 mt-4">
            <button
              class="text-xs text-gray-500 underline"
              type="button"
              @click="closeCreateModal"
            >
              Cancelar
            </button>
            <button
              class="btn-primary max-w-[140px] text-xs py-2"
              type="submit"
            >
              {{ editingEventId ? 'Salvar alterações' : 'Salvar agendamento' }}
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
      <div class="w-full max-w-2xl bg-white rounded-2xl shadow-lg p-6">
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
                maxlength="18"
                @input="patientForm.documento = formatCpfCnpj(patientForm.documento)"
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
              Celular (opcional)
            </label>
            <input
              v-model="patientForm.celular"
              class="form-input text-xs"
              placeholder="( ) _____-____"
              type="text"
              maxlength="15"
              @input="patientForm.celular = formatPhone(patientForm.celular)"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Telefone fixo (opcional)
            </label>
            <input
              v-model="patientForm.telefoneFixo"
              class="form-input text-xs"
              placeholder="( ) ____-____"
              type="text"
              maxlength="14"
              @input="
                patientForm.telefoneFixo = formatPhone(patientForm.telefoneFixo)
              "
            />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Data de nascimento
              </label>
              <input
                v-model="patientForm.dataNascimento"
                class="form-input text-xs"
                type="date"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Sexo
              </label>
              <select
                v-model="patientForm.sexo"
                class="form-input text-xs"
              >
                <option value="">
                  Não informado
                </option>
                <option value="masculino">
                  Masculino
                </option>
                <option value="feminino">
                  Feminino
                </option>
                <option value="outro">
                  Outro
                </option>
              </select>
            </div>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              CEP
            </label>
            <input
              v-model="patientForm.cep"
              class="form-input text-xs"
              placeholder="_____‑___"
              type="text"
              maxlength="9"
              @input="patientForm.cep = formatCep(patientForm.cep)"
              @blur="onCepBlur"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Endereço
            </label>
            <input
              v-model="patientForm.logradouro"
              class="form-input text-xs mb-2"
              placeholder="Rua, avenida..."
              type="text"
            />
            <div class="grid grid-cols-3 gap-3">
              <input
                v-model="patientForm.numero"
                class="form-input text-xs"
                placeholder="Número"
                type="text"
              />
              <input
                v-model="patientForm.complemento"
                class="form-input text-xs"
                placeholder="Compl."
                type="text"
              />
              <input
                v-model="patientForm.bairro"
                class="form-input text-xs"
                placeholder="Bairro"
                type="text"
              />
            </div>
          </div>
          <div class="grid grid-cols-3 gap-3">
            <div class="col-span-2">
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Cidade
              </label>
              <input
                v-model="patientForm.cidade"
                class="form-input text-xs"
                placeholder="Cidade"
                type="text"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                UF
              </label>
              <input
                v-model="patientForm.estado"
                class="form-input text-xs"
                placeholder="UF"
                maxlength="2"
                type="text"
              />
            </div>
          </div>
          <div class="flex justify-end gap-3 mt-4">
            <button
              class="text-xs text-gray-500 underline"
              type="button"
              @click="isLinkingPatient = false"
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

<style scoped>
.calendar-compact :deep(.n-calendar-dates .n-calendar-cell__text) {
  font-size: 11px;
}

.calendar-compact :deep(.n-calendar-dates .n-calendar-cell) {
  padding-top: 2px;
  padding-bottom: 2px;
}

/* Abreviação dos dias da semana: Dom, Seg, Ter, Qua, Qui, Sex, Sáb */
.calendar-compact :deep(.n-calendar-weekdays .n-calendar-cell__text) {
  font-size: 11px;
  visibility: hidden;
  position: relative;
}

.calendar-compact :deep(.n-calendar-weekdays .n-calendar-cell__text::after) {
  visibility: visible;
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(1) .n-calendar-cell__text::after) {
  content: 'Dom';
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(2) .n-calendar-cell__text::after) {
  content: 'Seg';
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(3) .n-calendar-cell__text::after) {
  content: 'Ter';
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(4) .n-calendar-cell__text::after) {
  content: 'Qua';
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(5) .n-calendar-cell__text::after) {
  content: 'Qui';
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(6) .n-calendar-cell__text::after) {
  content: 'Sex';
}

.calendar-compact
  :deep(.n-calendar-weekdays .n-calendar-cell:nth-child(7) .n-calendar-cell__text::after) {
  content: 'Sáb';
}
</style>
