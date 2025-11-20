<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type PermissaoModelo = {
  id: string
  nome: string
  permissoes: string[]
}

type ProfissionalVinculado = {
  id: string
  profissional_nome: string
  modelo_permissao_id: string | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()

const estabelecimentoId = ref<string | null>(null)
const modelos = ref<PermissaoModelo[]>([])
const profissionais = ref<ProfissionalVinculado[]>([])
const isLoading = ref(false)
const isSavingModelo = ref(false)

const novoModelo = reactive({
  nome: '',
  permissoesTexto: '',
})

async function loadEstabelecimento() {
  if (!auth.currentUser?.id) return

  const { data, error } = await supabase
    .from('estabelecimentos')
    .select('id')
    .eq('owner_usuario_id', auth.currentUser.id)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar o estabelecimento.')
    return
  }

  if (data) estabelecimentoId.value = data.id
}

async function ensureDefaultModels() {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('modelo_permissao_estabelecimento')
    .select('id')
    .eq('estabelecimento_id', estabelecimentoId.value)
    .limit(1)

  if (error) {
    console.error(error)
    return
  }

  if (data && data.length) return

  // Cria modelos padrão
  const defaults = [
    {
      nome: 'Admin',
      permissoes: ['agenda', 'pacientes', 'prontuario', 'profissionais', 'config_estabelecimento'],
    },
    {
      nome: 'Médico',
      permissoes: ['agenda', 'pacientes', 'prontuario'],
    },
    {
      nome: 'Recepção',
      permissoes: ['agenda', 'pacientes'],
    },
  ]

  const { error: insertError } = await supabase
    .from('modelo_permissao_estabelecimento')
    .insert(
      defaults.map((m) => ({
        estabelecimento_id: estabelecimentoId.value,
        nome: m.nome,
        permissoes: m.permissoes,
      })),
    )

  if (insertError) {
    console.error(insertError)
  }
}

async function loadModelos() {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('modelo_permissao_estabelecimento')
    .select('id, nome, permissoes')
    .eq('estabelecimento_id', estabelecimentoId.value)
    .order('nome')

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar os modelos de permissão.')
    return
  }

  modelos.value =
    data?.map((m: any) => ({
      id: m.id,
      nome: m.nome,
      permissoes: (m.permissoes ?? []) as string[],
    })) ?? []
}

async function loadProfissionais() {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .select(
      `
      id,
      modelo_permissao_estabelecimento_id,
      profissional:profissionais (
        nome_exibicao
      )
    `,
    )
    .eq('estabelecimento_id', estabelecimentoId.value)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar os profissionais.')
    return
  }

  profissionais.value =
    data?.map((v: any) => ({
      id: v.id,
      modelo_permissao_id: v.modelo_permissao_estabelecimento_id,
      profissional_nome: v.profissional?.nome_exibicao ?? 'Profissional',
    })) ?? []
}

async function saveNovoModelo() {
  if (!estabelecimentoId.value) return
  if (!novoModelo.nome) {
    feedback.error('Informe o nome do modelo de permissão.')
    return
  }

  isSavingModelo.value = true

  try {
    const permissoesArray = novoModelo.permissoesTexto
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)

    const { error } = await supabase
      .from('modelo_permissao_estabelecimento')
      .insert({
        estabelecimento_id: estabelecimentoId.value,
        nome: novoModelo.nome,
        permissoes: permissoesArray,
      })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível criar o modelo de permissão.')
      return
    }

    feedback.success('Modelo de permissão criado com sucesso.')
    novoModelo.nome = ''
    novoModelo.permissoesTexto = ''
    await loadModelos()
  } finally {
    isSavingModelo.value = false
  }
}

async function updateProfissionalModelo(
  vinculoId: string,
  modeloId: string | null,
) {
  const { error } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .update({ modelo_permissao_estabelecimento_id: modeloId })
    .eq('id', vinculoId)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível atualizar as permissões do profissional.')
    return
  }

  feedback.success('Permissões do profissional atualizadas com sucesso.')
}

onMounted(async () => {
  await loadEstabelecimento()
  if (!estabelecimentoId.value) return

  isLoading.value = true
  try {
    await ensureDefaultModels()
    await Promise.all([loadModelos(), loadProfissionais()])
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
          Permissões dos profissionais
        </h1>
        <p class="text-sm text-gray-500">
          Defina modelos de permissão e atribua quais áreas do sistema cada
          profissional pode acessar.
        </p>
      </div>
    </header>

    <div v-if="!estabelecimentoId" class="text-sm text-gray-600">
      <p>
        Nenhum estabelecimento encontrado para o seu usuário. Crie e configure
        um estabelecimento antes de gerenciar permissões.
      </p>
    </div>

    <div v-else class="space-y-6 max-w-5xl">
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-3">
          Modelos de permissão
        </h2>
        <p class="text-xs text-gray-500 mb-4">
          Utilize modelos para padronizar o acesso de administradores, médicos,
          recepção e outros perfis.
        </p>

        <div v-if="!modelos.length" class="text-sm text-gray-500 mb-4">
          Nenhum modelo configurado ainda. Modelos padrão foram sugeridos
          automaticamente.
        </div>

        <ul v-else class="space-y-2 mb-6">
          <li
            v-for="m in modelos"
            :key="m.id"
            class="flex items-start justify-between gap-4 text-sm"
          >
            <div>
              <p class="font-semibold text-primary-dark">
                {{ m.nome }}
              </p>
              <p class="text-xs text-gray-500">
                {{ m.permissoes.join(', ') || 'Sem permissões definidas' }}
              </p>
            </div>
          </li>
        </ul>

        <div class="border-t border-gray-100 pt-4 mt-4">
          <h3 class="text-xs font-semibold text-primary-700 mb-2">
            Criar novo modelo
          </h3>
          <form
            class="grid grid-cols-1 md:grid-cols-3 gap-3 items-end"
            @submit.prevent="saveNovoModelo"
          >
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Nome do modelo
              </label>
              <input
                v-model="novoModelo.nome"
                class="form-input text-xs"
                placeholder="Ex.: Faturamento, Coordenador"
                type="text"
              />
            </div>
            <div class="md:col-span-2">
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Permissões (separadas por vírgula)
              </label>
              <input
                v-model="novoModelo.permissoesTexto"
                class="form-input text-xs"
                placeholder="agenda, pacientes, prontuario"
                type="text"
              />
            </div>
            <div class="md:col-span-3 flex justify-end mt-2">
              <button
                class="btn-primary max-w-xs disabled:opacity-60 disabled:cursor-not-allowed text-xs py-2"
                :disabled="isSavingModelo"
                type="submit"
              >
                {{ isSavingModelo ? 'Salvando...' : 'Criar modelo' }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          Permissões por profissional
        </h2>
        <p class="text-xs text-gray-500 mb-4">
          Escolha qual modelo de permissão se aplica para cada profissional
          vinculado ao estabelecimento.
        </p>

        <div v-if="!profissionais.length" class="text-sm text-gray-500">
          Nenhum profissional vinculado para configurar permissões.
        </div>
        <table
          v-else
          class="w-full text-xs text-left border-collapse border-spacing-0"
        >
          <thead>
            <tr class="border-b border-gray-100 text-gray-500">
              <th class="py-2 pr-4 font-medium">Profissional</th>
              <th class="py-2 pr-4 font-medium">Modelo de permissão</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="p in profissionais"
              :key="p.id"
              class="border-b border-gray-50"
            >
              <td class="py-2 pr-4 text-gray-800">
                {{ p.profissional_nome }}
              </td>
              <td class="py-2 pr-4">
                <select
                  v-model="p.modelo_permissao_id"
                  class="form-input text-xs"
                  @change="updateProfissionalModelo(p.id, p.modelo_permissao_id)"
                >
                  <option :value="null">
                    Sem modelo
                  </option>
                  <option
                    v-for="m in modelos"
                    :key="m.id"
                    :value="m.id"
                  >
                    {{ m.nome }}
                  </option>
                </select>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </section>
</template>

