<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type WorkItem = {
  id: string
  dataHoraInicio: string
  tipoConsulta: string | null
  pacienteId: string
  pacienteNome: string
}

const auth = useAuthStore()
const feedback = useFeedbackStore()

const estabelecimentoId = ref<string | null>(null)
const profissionalId = ref<string | null>(null)
const selectedDate = ref<string>(new Date().toISOString().substring(0, 10))
const isLoading = ref(false)
const itens = ref<WorkItem[]>([])

function getDayRange(dateStr: string) {
  const base = dateStr ? new Date(dateStr + 'T00:00:00') : new Date()
  const start = new Date(base)
  const end = new Date(base)
  end.setDate(start.getDate() + 1)
  return {
    start: start.toISOString(),
    end: end.toISOString(),
  }
}

async function loadContext() {
  if (!auth.currentUser?.id) return

  // Busca profissional do usuário logado
  const { data: profissional, error: profError } = await supabase
    .from('profissionais')
    .select('id')
    .eq('usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (profError) {
    console.error(profError)
    feedback.error('Não foi possível identificar o profissional.')
    return
  }

  if (!profissional?.id) {
    feedback.error(
      'Nenhum cadastro de profissional encontrado para o seu usuário.',
    )
    return
  }

  profissionalId.value = profissional.id

  // Busca estabelecimento vinculado ao profissional
  const { data: vinculo, error: vincError } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .select('estabelecimento_id')
    .eq('profissional_id', profissional.id)
    .eq('ativo', true)
    .limit(1)
    .maybeSingle()

  if (vincError) {
    console.error(vincError)
    feedback.error('Não foi possível identificar o estabelecimento vinculado.')
    return
  }

  estabelecimentoId.value = vinculo?.estabelecimento_id ?? null
}

async function loadWorklist() {
  if (!estabelecimentoId.value || !profissionalId.value) return

  isLoading.value = true
  itens.value = []

  try {
    const { start, end } = getDayRange(selectedDate.value)

    const { data, error } = await supabase
      .from('evento_de_agendamento')
      .select(
        `
        id,
        data_hora_inicio,
        status,
        tipo_consulta,
        paciente_id,
        paciente:pacientes ( id, nome_completo )
      `,
      )
      .eq('estabelecimento_id', estabelecimentoId.value)
      .eq('profissional_id', profissionalId.value)
      .eq('status', 'confirmado')
      .not('paciente_id', 'is', null)
      .gte('data_hora_inicio', start)
      .lt('data_hora_inicio', end)
      .order('data_hora_inicio', { ascending: true })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar as consultas do dia.')
      return
    }

    itens.value =
      (data ?? []).map((row: any) => ({
        id: row.id as string,
        dataHoraInicio: row.data_hora_inicio as string,
        tipoConsulta: (row.tipo_consulta as string | null) ?? null,
        pacienteId: (row.paciente?.id as string) ?? row.paciente_id,
        pacienteNome:
          (row.paciente?.nome_completo as string | null) ?? 'Paciente',
      })) ?? []
  } finally {
    isLoading.value = false
  }
}

onMounted(async () => {
  await loadContext()
  if (!estabelecimentoId.value || !profissionalId.value) return
  await loadWorklist()
})

watch(
  () => selectedDate.value,
  () => {
    loadWorklist()
  },
)
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Minhas consultas
        </h1>
        <p class="text-sm text-gray-500">
          Veja as consultas confirmadas para você e inicie o prontuário do
          paciente.
        </p>
      </div>

      <div class="flex items-center gap-2 text-xs">
        <label class="text-gray-600" for="worklist-date">
          Dia:
        </label>
        <input
          id="worklist-date"
          v-model="selectedDate"
          class="form-input text-xs py-1 px-2 w-32"
          type="date"
        />
      </div>
    </header>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <div v-if="!estabelecimentoId || !profissionalId" class="text-sm text-gray-500">
        Não foi possível identificar um profissional e estabelecimento
        vinculados ao seu usuário.
      </div>

      <div v-else>
        <div v-if="isLoading" class="text-xs text-gray-400">
          Carregando consultas...
        </div>
        <div v-else-if="!itens.length" class="text-sm text-gray-500">
          Nenhuma consulta confirmada para o dia selecionado.
        </div>
        <ul v-else class="divide-y divide-gray-100 text-sm">
          <li
            v-for="item in itens"
            :key="item.id"
            class="py-2 flex items-center justify-between gap-4"
          >
            <div>
              <p class="font-semibold text-gray-800">
                {{ item.pacienteNome }}
              </p>
              <p class="text-xs text-gray-500">
                {{
                  new Date(item.dataHoraInicio).toLocaleString('pt-BR', {
                    dateStyle: 'short',
                    timeStyle: 'short',
                  })
                }}
                <span v-if="item.tipoConsulta" class="ml-1">
                  ·
                  {{
                    item.tipoConsulta === 'consulta'
                      ? 'Consulta'
                      : item.tipoConsulta === 'retorno'
                        ? 'Retorno'
                        : item.tipoConsulta === 'procedimento'
                          ? 'Procedimento'
                          : item.tipoConsulta === 'exame'
                            ? 'Exame'
                            : 'Outro'
                  }}
                </span>
              </p>
            </div>
            <RouterLink
              :to="{
                name: 'medical-record',
                params: { pacienteId: item.pacienteId },
                query: { eventoId: item.id },
              }"
              class="inline-flex items-center rounded-lg border border-primary-600 text-primary-600 text-xs font-semibold px-3 py-1.5 hover:bg-primary-light"
            >
              Abrir prontuário
            </RouterLink>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>

