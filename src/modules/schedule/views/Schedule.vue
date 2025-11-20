<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'

type Evento = {
  id: string
  data_hora_inicio: string
  data_hora_fim: string | null
  titulo: string | null
  status: string
}

type Periodo = 'dia' | 'semana' | 'mes'

const isLoading = ref(false)
const events = reactive<Evento[]>([])
const activePeriod = ref<Periodo>('dia')
const selectedDate = ref<string>(new Date().toISOString().substring(0, 10))

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

    const { data, error } = await supabase
      .from('evento_de_agendamento')
      .select('id, data_hora_inicio, data_hora_fim, titulo, status')
      .gte('data_hora_inicio', start)
      .lt('data_hora_inicio', end)
      .order('data_hora_inicio', { ascending: true })

    if (error) {
      console.error(error)
      return
    }

    if (data) {
      data.forEach((e) =>
        events.push({
          id: e.id,
          data_hora_inicio: e.data_hora_inicio,
          data_hora_fim: e.data_hora_fim,
          titulo: e.titulo,
          status: e.status,
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

watch([activePeriod, selectedDate], () => {
  loadEvents()
})

onMounted(() => {
  loadEvents()
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
      >
        Novo agendamento
      </button>
    </header>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3 mb-4">
        <div class="flex items-center gap-3">
          <div
            class="inline-flex rounded-full bg-gray-50 p-1 text-xs font-semibold text-gray-600"
          >
            <button
              class="px-3 py-1 rounded-full"
              :class="activePeriod === 'dia' ? 'bg-white text-primary-700 shadow-sm' : ''"
              type="button"
              @click="activePeriod = 'dia'"
            >
              Dia
            </button>
            <button
              class="px-3 py-1 rounded-full"
              :class="activePeriod === 'semana' ? 'bg-white text-primary-700 shadow-sm' : ''"
              type="button"
              @click="activePeriod = 'semana'"
            >
              Semana
            </button>
            <button
              class="px-3 py-1 rounded-full"
              :class="activePeriod === 'mes' ? 'bg-white text-primary-700 shadow-sm' : ''"
              type="button"
              @click="activePeriod = 'mes'"
            >
              Mês
            </button>
          </div>
        </div>
        <div class="flex items-center gap-2 text-xs">
          <label class="text-gray-600" for="agenda-date">Referência:</label>
          <input
            id="agenda-date"
            v-model="selectedDate"
            class="form-input text-xs py-1 px-2 w-36"
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
          </div>
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
        </li>
      </ul>
    </div>
  </section>
</template>

