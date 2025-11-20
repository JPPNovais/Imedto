<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'

type Evento = {
  id: string
  data_hora_inicio: string
  data_hora_fim: string | null
  titulo: string | null
  status: string
}

const isLoading = ref(false)
const events = reactive<Evento[]>([])

async function loadTodayEvents() {
  isLoading.value = true
  events.splice(0, events.length)
  try {
    const today = new Date()
    const startOfDay = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate(),
    )
    const endOfDay = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate() + 1,
    )

    const { data, error } = await supabase
      .from('evento_de_agendamento')
      .select('id, data_hora_inicio, data_hora_fim, titulo, status')
      .gte('data_hora_inicio', startOfDay.toISOString())
      .lt('data_hora_inicio', endOfDay.toISOString())
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

onMounted(() => {
  loadTodayEvents()
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
          Veja os agendamentos do dia e organize seus atendimentos.
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
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-sm font-semibold text-primary-700">
          Agenda de hoje
        </h2>
        <button
          class="text-xs text-primary-600 underline"
          type="button"
          @click="loadTodayEvents"
        >
          Atualizar
        </button>
      </div>

      <div v-if="isLoading" class="text-xs text-gray-400">
        Carregando agendamentos...
      </div>
      <div v-else-if="!events.length" class="text-sm text-gray-500">
        Nenhum agendamento para hoje.
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

