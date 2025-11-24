<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import { useRoute } from 'vue-router'

type ModeloProntuario = {
  id: string
  nome: string
  descricao: string | null
  estrutura: Record<string, any> | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()
const route = useRoute()

const estabelecimentoId = ref<string | null>(null)
const pacienteId = ref<string | null>(null)
const prontuarioId = ref<string | null>(null)
const profissionalId = ref<string | null>(null)
const modelos = ref<ModeloProntuario[]>([])
const selectedModeloId = ref<string>('')
const isLoading = ref(false)
const isLoadingModelos = ref(false)
const isSaving = ref(false)

type EvolucaoItem = {
  id: string
  criado_em: string
  modelo_nome: string | null
}

const evolucoes = ref<EvolucaoItem[]>([])
const secaoConteudo = reactive<Record<string, string>>({})
type AnexoItem = {
  nome: string
}
const anexos = ref<AnexoItem[]>([])
const hasAnexos = computed(() => (anexos.value ?? []).length > 0)
const hasEvolucoes = computed(() => (evolucoes.value ?? []).length > 0)

function onAnexosChange(event: Event) {
  const target = event.target as HTMLInputElement | null
  if (!target?.files) return
  const files = Array.from(target.files)
  files.forEach((file) => {
    anexos.value.push({ nome: file.name })
  })
  // limpa o input para permitir selecionar o mesmo arquivo novamente, se necessário
  target.value = ''
}

function removeAnexo(index: number) {
  if (!anexos.value || index < 0 || index >= anexos.value.length) return
  anexos.value.splice(index, 1)
}

const secoesDictionary: Record<
  string,
  { key: string; label: string; placeholder: string }
> = {
  secao_queixa_principal: {
    key: 'secao_queixa_principal',
    label: 'Queixa principal',
    placeholder: 'Descreva a queixa principal do paciente...',
  },
  secao_historia_atual: {
    key: 'secao_historia_atual',
    label: 'História atual',
    placeholder: 'Descreva a história atual da doença...',
  },
  secao_historia_pregressa: {
    key: 'secao_historia_pregressa',
    label: 'História pregressa',
    placeholder: 'Antecedentes pessoais, doenças prévias, cirurgias...',
  },
  secao_historia_familiar: {
    key: 'secao_historia_familiar',
    label: 'História familiar',
    placeholder: 'Doenças familiares relevantes...',
  },
  secao_historia_social: {
    key: 'secao_historia_social',
    label: 'História social',
    placeholder: 'Hábitos, profissão, uso de substâncias...',
  },
  secao_exame_fisico: {
    key: 'secao_exame_fisico',
    label: 'Exame físico',
    placeholder: 'Achados do exame físico...',
  },
  secao_evolucao: {
    key: 'secao_evolucao',
    label: 'Evolução',
    placeholder: 'Descrição da evolução clínica...',
  },
  secao_exames_realizados: {
    key: 'secao_exames_realizados',
    label: 'Exames realizados',
    placeholder: 'Exames complementares realizados e resultados...',
  },
  secao_procedimentos_indicados: {
    key: 'secao_procedimentos_indicados',
    label: 'Procedimentos indicados',
    placeholder: 'Procedimentos indicados ao paciente...',
  },
  secao_evolucao_pre_operatoria: {
    key: 'secao_evolucao_pre_operatoria',
    label: 'Evolução pré-operatória',
    placeholder: 'Registre a evolução pré-operatória...',
  },
  secao_evolucao_pos_operatoria: {
    key: 'secao_evolucao_pos_operatoria',
    label: 'Evolução pós-operatória',
    placeholder: 'Registre a evolução pós-operatória...',
  },
  secao_detalhes_da_cirurgia: {
    key: 'secao_detalhes_da_cirurgia',
    label: 'Informações da cirurgia realizada',
    placeholder: 'Data, tipo de cirurgia, tempo cirúrgico...',
  },
  secao_descricao_cirurgica: {
    key: 'secao_descricao_cirurgica',
    label: 'Descrição cirúrgica',
    placeholder: 'Descrição detalhada do ato cirúrgico...',
  },
  secao_equipe: {
    key: 'secao_equipe',
    label: 'Equipe',
    placeholder: 'Equipe envolvida no procedimento...',
  },
  secao_fotos_do_paciente: {
    key: 'secao_fotos_do_paciente',
    label: 'Fotos do paciente',
    placeholder: 'Referência às fotos registradas do paciente...',
  },
  secao_anexos: {
    key: 'secao_anexos',
    label: 'Anexos',
    placeholder: 'Documentos, laudos ou outros anexos importantes...',
  },
  secao_conduta: {
    key: 'secao_conduta',
    label: 'Conduta',
    placeholder: 'Conduta proposta, orientações e plano terapêutico...',
  },
}

const selectedModelo = computed(() =>
  modelos.value.find((m) => m.id === selectedModeloId.value),
)

const activeSections = computed(() => {
  const modelo = selectedModelo.value
  if (!modelo?.estrutura) return []

  const estrutura = modelo.estrutura as {
    secoes?: Record<string, boolean> | undefined
    ordem?: string[] | undefined
  }

  const secoesConfig = estrutura.secoes ?? {}

  const baseKeys = Object.keys(secoesDictionary).filter(
    (key) => secoesConfig[key] === true,
  )

  if (estrutura.ordem && Array.isArray(estrutura.ordem)) {
    const ordemSet = new Set(estrutura.ordem)
    const ordered: string[] = []

    estrutura.ordem.forEach((key) => {
      if (secoesConfig[key] && key in secoesDictionary) {
        ordered.push(key)
      }
    })

    baseKeys.forEach((key) => {
      if (!ordemSet.has(key)) {
        ordered.push(key)
      }
    })

    return ordered
  }

  return baseKeys
})

const hasActiveSections = computed(
  () => (activeSections.value ?? []).length > 0,
)

watch(activeSections, (keys) => {
  keys.forEach((k) => {
    if (!(k in secaoConteudo)) {
      secaoConteudo[k] = ''
    }
  })
})

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
      .select('id, nome, descricao, estrutura')
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

async function loadProfissional() {
  if (!auth.currentUser?.id) return

  const { data, error } = await supabase
    .from('profissionais')
    .select('id')
    .eq('usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    return
  }

  profissionalId.value = data?.id ?? null
}

async function ensureProntuario() {
  if (!estabelecimentoId.value || !pacienteId.value) return

  const { data, error } = await supabase
    .from('prontuarios')
    .select('id, modelo_de_prontuario_id')
    .eq('estabelecimento_id', estabelecimentoId.value)
    .eq('paciente_id', pacienteId.value)
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar o prontuário do paciente.')
    return
  }

  if (data?.id) {
    prontuarioId.value = data.id
    if (!selectedModeloId.value && data.modelo_de_prontuario_id) {
      selectedModeloId.value = data.modelo_de_prontuario_id
    }
    return
  }

  const { data: created, error: insertError } = await supabase
    .from('prontuarios')
    .insert({
      paciente_id: pacienteId.value,
      estabelecimento_id: estabelecimentoId.value,
      modelo_de_prontuario_id: selectedModeloId.value || null,
    })
    .select('id')
    .maybeSingle()

  if (insertError) {
    console.error(insertError)
    feedback.error('Não foi possível criar o prontuário do paciente.')
    return
  }

  prontuarioId.value = created?.id ?? null
}

async function loadEvolucoes() {
  if (!prontuarioId.value) return

  const { data, error } = await supabase
    .from('evolucao_prontuario')
    .select(
      `
      id,
      criado_em,
      modelo:modelo_de_prontuario ( nome )
    `,
    )
    .eq('prontuario_id', prontuarioId.value)
    .order('criado_em', { ascending: false })

  if (error) {
    console.error(error)
    return
  }

  evolucoes.value =
    data?.map((e: any) => ({
      id: e.id,
      criado_em: e.criado_em,
      modelo_nome: e.modelo?.nome ?? null,
    })) ?? []
}

async function salvarEvolucao() {
  if (!estabelecimentoId.value || !pacienteId.value || !profissionalId.value) {
    feedback.error(
      'Não foi possível identificar estabelecimento, paciente ou profissional.',
    )
    return
  }

  if (!selectedModeloId.value) {
    feedback.error('Selecione um modelo de prontuário.')
    return
  }

  await ensureProntuario()
  if (!prontuarioId.value) return

  const secoesPayload: Record<string, any> = {}
  activeSections.value.forEach((key) => {
    if (key === 'secao_anexos') {
      secoesPayload[key] = {
        arquivos: anexos.value.map((a) => ({ nome: a.nome })),
      }
    } else {
      secoesPayload[key] = {
        texto: secaoConteudo[key] || '',
      }
    }
  })

  const conteudo = {
    secoes: secoesPayload,
  }

  isSaving.value = true
  try {
    const eventoId =
      typeof route.query.eventoId === 'string'
        ? route.query.eventoId
        : null

    const { error } = await supabase
      .from('evolucao_prontuario')
      .insert({
        prontuario_id: prontuarioId.value,
        estabelecimento_id: estabelecimentoId.value,
        paciente_id: pacienteId.value,
        profissional_id: profissionalId.value,
        evento_de_agendamento_id: eventoId,
        modelo_de_prontuario_id: selectedModeloId.value,
        conteudo,
      })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível salvar a evolução do prontuário.')
      return
    }

    feedback.success('Evolução do prontuário salva com sucesso.')

    activeSections.value.forEach((k) => {
      secaoConteudo[k] = ''
    })
    anexos.value = []

    await loadEvolucoes()
  } finally {
    isSaving.value = false
  }
}

onMounted(async () => {
  isLoading.value = true
  try {
    const pId = route.params.pacienteId
    if (typeof pId === 'string') {
      pacienteId.value = pId
    }

    await loadEstabelecimento()
    if (!estabelecimentoId.value) return
    await loadProfissional()
    await loadModelos()
    if (pacienteId.value) {
      await ensureProntuario()
      await loadEvolucoes()
    }
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
          Prontuário
        </h1>
        <p class="text-sm text-gray-500">
          Selecione um modelo de prontuário para visualizar as seções que serão
          utilizadas na evolução.
        </p>
      </div>
    </header>

    <div v-if="isLoading" class="text-xs text-gray-400">
      Carregando dados...
    </div>

    <div v-else-if="!estabelecimentoId" class="text-sm text-gray-500">
      Não foi possível identificar um estabelecimento vinculado ao seu usuário.
    </div>

    <div
      v-else
      class="bg-white rounded-xl shadow-sm border border-gray-100 p-6"
    >
      <div class="mb-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div class="flex-1">
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Modelo de prontuário
          </label>
          <select
            v-model="selectedModeloId"
            class="form-input text-xs max-w-xs"
          >
            <option value="">
              Selecione um modelo
            </option>
            <option
              v-for="modelo in modelos"
              :key="modelo.id"
              :value="modelo.id"
            >
              {{ modelo.nome }}
            </option>
          </select>
          <p
            v-if="selectedModelo && selectedModelo.descricao"
            class="mt-1 text-[11px] text-gray-500"
          >
            {{ selectedModelo.descricao }}
          </p>
        </div>
      </div>

      <div v-if="isLoadingModelos" class="text-xs text-gray-400">
        Carregando modelos...
      </div>

      <div
        v-else-if="!pacienteId"
        class="text-sm text-gray-500"
      >
        Nenhum paciente foi selecionado. Acesse o prontuário a partir da ficha
        do paciente ou da agenda.
      </div>

      <div v-else-if="!selectedModeloId" class="text-sm text-gray-500">
        Selecione um modelo de prontuário para exibir as seções.
      </div>

      <div
        v-else-if="!hasActiveSections"
        class="text-sm text-gray-500"
      >
        O modelo selecionado ainda não possui seções configuradas. Ajuste a
        configuração do modelo ou escolha outro.
      </div>

      <div
        v-else
        class="mt-4 grid grid-cols-1 gap-4"
      >
        <div
          v-for="secaoKey in activeSections"
          :key="secaoKey"
          class="border border-gray-100 rounded-lg p-4 bg-gray-50"
        >
          <h3 class="text-sm font-semibold text-primary-700 mb-2">
            {{ secoesDictionary[secaoKey].label }}
          </h3>
          <template v-if="secaoKey === 'secao_anexos'">
            <input
              type="file"
              multiple
              class="text-xs mb-2"
              @change="onAnexosChange"
            />
            <div v-if="!hasAnexos" class="text-[11px] text-gray-500">
              Nenhum arquivo adicionado. Selecione arquivos para anexar ao
              prontuário.
            </div>
            <ul
              v-else
              class="text-[11px] text-gray-700 space-y-1"
            >
              <li
                v-for="(anexo, index) in anexos"
                :key="`${anexo.nome}-${index}`"
                class="flex items-center justify-between"
              >
                <span class="truncate max-w-[180px]">
                  {{ anexo.nome }}
                </span>
                <button
                  type="button"
                  class="text-[10px] text-red-500 hover:underline"
                  @click="removeAnexo(index)"
                >
                  Remover
                </button>
              </li>
            </ul>
          </template>
          <template v-else>
            <textarea
              v-model="secaoConteudo[secaoKey]"
              class="form-input text-xs min-h-[96px] resize-y"
              :placeholder="secoesDictionary[secaoKey].placeholder"
            />
          </template>
        </div>

        <div class="flex justify-end">
          <button
            type="button"
            class="btn-primary max-w-xs text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
            :disabled="isSaving"
            @click="salvarEvolucao"
          >
            {{ isSaving ? 'Salvando evolução...' : 'Salvar evolução' }}
          </button>
        </div>

        <div v-if="hasEvolucoes" class="mt-6 border-t border-gray-100 pt-4">
          <h2 class="text-sm font-semibold text-primary-700 mb-3">
            Evoluções anteriores
          </h2>
          <ul class="space-y-2 text-xs text-gray-600">
            <li
              v-for="evo in evolucoes"
              :key="evo.id"
              class="flex items-center justify-between"
            >
              <span>
                {{
                  new Date(evo.criado_em).toLocaleString('pt-BR', {
                    dateStyle: 'short',
                    timeStyle: 'short',
                  })
                }}
              </span>
              <span class="text-[11px] text-gray-500">
                {{ evo.modelo_nome || 'Modelo não informado' }}
              </span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>
