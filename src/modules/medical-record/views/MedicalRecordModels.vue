<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type ModeloProntuario = {
  id: string
  nome: string
  descricao: string | null
  estrutura: Record<string, unknown> | null
  is_default?: boolean
}

const auth = useAuthStore()
const feedback = useFeedbackStore()

const estabelecimentoId = ref<string | null>(null)
const modelos = ref<ModeloProntuario[]>([])
const selectedModeloId = ref<string | null>(null)

const isLoading = ref(false)
const isLoadingModelos = ref(false)
const isSaving = ref(false)
const isDeleting = ref(false)

const secoesList = [
  { key: 'queixa', label: 'Queixa principal (QP)' },
  { key: 'hda', label: 'História da doença atual (HDA)' },
  { key: 'hpp', label: 'História pregressa (HPP)' },
  { key: 'h-familiar', label: 'História familiar' },
  { key: 'h-social', label: 'História social e hábitos de vida' },
  { key: 'exame-fisico', label: 'Exame físico e sinais vitais' },
  { key: 'exames-realizados', label: 'Exames realizados' },
  { key: 'procedimentos-indicados', label: 'Procedimentos indicados' },
  { key: 'evolucao-pos-op', label: 'Evolução pós-operatória' },
  { key: 'desc-cirurgica', label: 'Descrição cirúrgica' },
  { key: 'equipe-cirurgica', label: 'Equipe cirúrgica' },
  { key: 'fotos-paciente', label: 'Fotos do paciente' },
  { key: 'anexos', label: 'Anexos' },
  { key: 'cid10', label: 'CID-10' },
  { key: 'conduta', label: 'Conduta' },
  { key: 'prescricao', label: 'Prescrição' },
  { key: 'encaminhamento', label: 'Encaminhamento' },
]

type FormState = {
  id: string | null
  nome: string
  descricao: string
  secoes: Record<string, boolean>
  ordemSecoes: string[]
}

const emptySecoes = (): Record<string, boolean> =>
  secoesList.reduce((acc, s) => {
    acc[s.key] = false
    return acc
  }, {} as Record<string, boolean>)

const form = reactive<FormState>({
  id: null,
  nome: '',
  descricao: '',
  secoes: emptySecoes(),
  ordemSecoes: [],
})

function syncOrderWithActive() {
  const activeKeys = Object.keys(form.secoes).filter((key) => form.secoes[key])
  const remaining = new Set(activeKeys)

  const ordered: string[] = []

  form.ordemSecoes.forEach((key) => {
    if (remaining.has(key)) {
      ordered.push(key)
      remaining.delete(key)
    }
  })

  activeKeys.forEach((key) => {
    if (remaining.has(key)) {
      ordered.push(key)
      remaining.delete(key)
    }
  })

  form.ordemSecoes = ordered
}

function resetForm() {
  form.id = null
  form.nome = ''
  form.descricao = ''
  form.secoes = emptySecoes()
  form.ordemSecoes = []
  selectedModeloId.value = null
}

function fillFormFromModel(modelo: ModeloProntuario) {
  form.id = modelo.id
  form.nome = modelo.nome
  form.descricao = modelo.descricao ?? ''

  const estrutura = (modelo.estrutura as {
    secoes?: Record<string, boolean> | undefined
    ordem?: string[] | undefined
  } | null) ?? null
  const secoesConfig = estrutura?.secoes ?? {}

  const novo = emptySecoes()
  secoesList.forEach((s) => {
    if (secoesConfig[s.key] === true) {
      novo[s.key] = true
    }
  })
  form.secoes = novo

  if (estrutura?.ordem && Array.isArray(estrutura.ordem)) {
    form.ordemSecoes = estrutura.ordem.filter((key) => key in novo)
  } else {
    form.ordemSecoes = secoesList
      .map((s) => s.key)
      .filter((key) => novo[key])
  }
}

const selectedSecoesInOrder = computed(() => {
  return form.ordemSecoes.filter((key) => form.secoes[key])
})

function moveSecaoInOrder(key: string, direction: 'up' | 'down') {
  const idx = form.ordemSecoes.indexOf(key)
  if (idx === -1) return
  const newIndex = direction === 'up' ? idx - 1 : idx + 1
  if (newIndex < 0 || newIndex >= form.ordemSecoes.length) return
  const arr = [...form.ordemSecoes]
  const [item] = arr.splice(idx, 1)
  arr.splice(newIndex, 0, item)
  form.ordemSecoes = arr
}

watch(
  () => ({ ...form.secoes }),
  () => {
    syncOrderWithActive()
  },
  { deep: true },
)

async function loadEstabelecimento() {
  if (!auth.currentUser?.id) return

  const { data, error } = await supabase
    .from('estabelecimentos')
    .select('id, nome_fantasia')
    .eq('owner_usuario_id', auth.currentUser.id)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível identificar o estabelecimento.')
    return
  }

  estabelecimentoId.value = data?.id ?? null
}

async function loadModelos() {
  if (!estabelecimentoId.value) return
  isLoadingModelos.value = true

  try {
    const { data, error } = await supabase
      .from('modelo_de_prontuario')
      .select('id, nome, descricao, estrutura, is_default')
      .eq('estabelecimento_id', estabelecimentoId.value)
      .order('nome')

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar os modelos de prontuário.')
      return
    }

    modelos.value = (data ?? []) as ModeloProntuario[]
  } finally {
    isLoadingModelos.value = false
  }
}

async function handleSave() {
  if (!estabelecimentoId.value) {
    feedback.error('Estabelecimento não identificado.')
    return
  }

  if (!form.nome.trim()) {
    feedback.error('Informe o nome do modelo.')
    return
  }

  const secoesPayload: Record<string, boolean> = {}
  secoesList.forEach((s) => {
    if (form.secoes[s.key]) {
      secoesPayload[s.key] = true
    }
  })

  if (Object.keys(secoesPayload).length === 0) {
    feedback.error('Selecione pelo menos uma seção para o modelo.')
    return
  }

  const estrutura = {
    secoes: secoesPayload,
    ordem: selectedSecoesInOrder.value,
  }

  isSaving.value = true
  try {
    if (form.id) {
      const modeloAtual = modelos.value.find((m) => m.id === form.id)
      if (modeloAtual?.is_default) {
        feedback.error(
          'Modelos padrão do sistema não podem ser editados. Crie um novo modelo personalizado.',
        )
        return
      }

      const { error } = await supabase
        .from('modelo_de_prontuario')
        .update({
          nome: form.nome.trim(),
          descricao: form.descricao.trim() || null,
          estrutura,
        })
        .eq('id', form.id)
        .eq('estabelecimento_id', estabelecimentoId.value)

      if (error) {
        console.error(error)
        feedback.error('Não foi possível atualizar o modelo de prontuário.')
          return
      }

      feedback.success('Modelo de prontuário atualizado com sucesso.')
    } else {
      const { error } = await supabase
        .from('modelo_de_prontuario')
        .insert({
          estabelecimento_id: estabelecimentoId.value,
          nome: form.nome.trim(),
          descricao: form.descricao.trim() || null,
          estrutura,
        })

      if (error) {
        console.error(error)
        feedback.error('Não foi possível criar o modelo de prontuário.')
        return
      }

      feedback.success('Modelo de prontuário criado com sucesso.')
    }

    await loadModelos()
    resetForm()
  } finally {
    isSaving.value = false
  }
}

async function handleEdit(modelo: ModeloProntuario) {
  if (modelo.is_default) {
    feedback.error(
      'Modelos padrão do sistema não podem ser editados. Crie um novo modelo personalizado a partir desse padrão.',
    )
    return
  }

  selectedModeloId.value = modelo.id
  fillFormFromModel(modelo)
}

async function handleDelete(modelo: ModeloProntuario) {
  if (!estabelecimentoId.value) return

  if (modelo.is_default) {
    feedback.error(
      'Modelos padrão do sistema não podem ser excluídos. Crie um novo modelo personalizado se precisar de variações.',
    )
    return
  }

  if (!window.confirm('Deseja realmente excluir este modelo de prontuário?')) {
    return
  }

  isDeleting.value = true
  try {
    const { error } = await supabase
      .from('modelo_de_prontuario')
      .delete()
      .eq('id', modelo.id)
      .eq('estabelecimento_id', estabelecimentoId.value)

    if (error) {
      console.error(error)
      feedback.error(
        'Não foi possível excluir o modelo. Verifique se não há evoluções usando este modelo.',
      )
      return
    }

    feedback.success('Modelo de prontuário excluído com sucesso.')
    if (form.id === modelo.id) {
      resetForm()
    }
    await loadModelos()
  } finally {
    isDeleting.value = false
  }
}

onMounted(async () => {
  isLoading.value = true
  try {
    await loadEstabelecimento()
    if (!estabelecimentoId.value) return
    await loadModelos()
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Modelos de prontuário
        </h1>
        <p class="text-sm text-gray-500">
          Crie, edite e organize os modelos de prontuário utilizados no
          estabelecimento.
        </p>
      </div>
    </header>

    <div v-if="isLoading" class="text-xs text-gray-400">
      Carregando dados...
    </div>

    <div v-else-if="!estabelecimentoId" class="text-sm text-gray-500">
      Nenhum estabelecimento foi encontrado para o seu usuário. Apenas o
      proprietário do estabelecimento pode gerenciar modelos de prontuário.
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <div class="mb-4 flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold text-primary-700">
            Modelos cadastrados
          </h2>
          <button
            type="button"
            class="text-xs text-primary-600 underline"
            @click="resetForm"
          >
            + Novo modelo
          </button>
        </div>

        <div v-if="isLoadingModelos" class="text-xs text-gray-400">
          Carregando modelos...
        </div>
        <div v-else-if="!modelos.length" class="text-sm text-gray-500">
          Nenhum modelo cadastrado ainda. Clique em “Novo modelo” para criar o
          primeiro.
        </div>
        <ul v-else class="divide-y divide-gray-100 text-sm">
          <li
            v-for="modelo in modelos"
            :key="modelo.id"
            class="py-2 flex items-center justify-between gap-3"
          >
            <div>
              <p class="font-semibold text-primary-dark">
                {{ modelo.nome }}
              </p>
              <p v-if="modelo.descricao" class="text-xs text-gray-500">
                {{ modelo.descricao }}
              </p>
            </div>
            <div class="flex items-center gap-2 text-xs">
              <button
                v-if="!modelo.is_default"
                type="button"
                class="text-primary-600 hover:underline"
                @click="handleEdit(modelo)"
              >
                Editar
              </button>
              <button
                v-if="!modelo.is_default"
                type="button"
                class="text-red-600 hover:underline disabled:opacity-50"
                :disabled="isDeleting"
                @click="handleDelete(modelo)"
              >
                Excluir
              </button>
            </div>
          </li>
        </ul>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          {{ form.id ? 'Editar modelo' : 'Novo modelo' }}
        </h2>
        <form class="space-y-4" @submit.prevent="handleSave">
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Nome do modelo
            </label>
            <input
              v-model="form.nome"
              class="form-input text-xs"
              placeholder="Ex.: Primeira consulta, Evolução pós-operatória"
              type="text"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Descrição (opcional)
            </label>
            <textarea
              v-model="form.descricao"
              class="form-input text-xs min-h-[72px] resize-y"
              placeholder="Descrição breve do objetivo deste modelo."
            />
          </div>

          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-2">
              Seções incluídas no modelo
            </label>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs">
              <label
                v-for="secao in secoesList"
                :key="secao.key"
                class="inline-flex items-center gap-2"
              >
                <input
                  v-model="form.secoes[secao.key]"
                  type="checkbox"
                  class="h-3 w-3 rounded border-gray-300 text-primary focus:ring-primary"
                />
                <span>{{ secao.label }}</span>
              </label>
            </div>
          </div>

          <div v-if="selectedSecoesInOrder.length">
            <label class="block text-xs font-semibold text-gray-700 mb-2">
              Ordem das seções
            </label>
            <ul class="space-y-1 text-xs">
              <li
                v-for="key in selectedSecoesInOrder"
                :key="key"
                class="flex items-center justify-between rounded border border-gray-200 bg-gray-50 px-2 py-1"
              >
                <span>
                  {{
                    secoesList.find((s) => s.key === key)?.label ||
                    key
                  }}
                </span>
                <span class="inline-flex items-center gap-1">
                  <button
                    type="button"
                    class="text-[11px] text-gray-500 hover:text-primary-600"
                    @click="moveSecaoInOrder(key, 'up')"
                  >
                    ↑
                  </button>
                  <button
                    type="button"
                    class="text-[11px] text-gray-500 hover:text-primary-600"
                    @click="moveSecaoInOrder(key, 'down')"
                  >
                    ↓
                  </button>
                </span>
              </li>
            </ul>
          </div>

          <div class="flex justify-end gap-3 pt-2">
            <button
              type="button"
              class="text-xs text-gray-500 underline"
              @click="resetForm"
            >
              Cancelar
            </button>
            <button
              type="submit"
              class="btn-primary max-w-xs text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSaving"
            >
              {{ isSaving ? 'Salvando...' : 'Salvar modelo' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>
