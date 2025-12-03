<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import { formatCpfCnpj, onlyDigits, isValidCnpj, formatCep } from '@/utils/masks'
import { fetchAddressByCep } from '@/utils/viaCep'

type TipoSala = {
  id: string
  nome: string
}

type Sala = {
  id: string
  nome: string
  tipo_nome?: string | null
}

type VariavelTipoId =
  | 'alergia'
  | 'cirurgia'
  | 'doenca_hereditaria'
  | 'doenca_cronica'
  | 'droga'
  | 'relacao_familiar'
  | 'expectativa'
  | 'atividade_fisica'
  | 'cirurgia_pregressa'

type VariavelItem = {
  nome: string
  estabelecimento_id: string | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()
const router = useRouter()

const estabelecimentoId = ref<string | null>(null)
const isLoading = ref(false)
const isSavingEstab = ref(false)
const isSavingSala = ref(false)
const isSavingVariavel = ref(false)

const tiposSala = ref<TipoSala[]>([])
const salas = ref<Sala[]>([])

const variavelTipos: { id: VariavelTipoId; label: string }[] = [
  { id: 'alergia', label: 'Alergias' },
  { id: 'cirurgia', label: 'Cirurgias' },
  { id: 'doenca_hereditaria', label: 'Doenças hereditárias' },
  { id: 'doenca_cronica', label: 'Doenças crônicas / comorbidades' },
  { id: 'droga', label: 'Drogas / substâncias ilícitas' },
  { id: 'relacao_familiar', label: 'Relações familiares' },
  { id: 'expectativa', label: 'Expectativas do paciente' },
  { id: 'atividade_fisica', label: 'Atividades físicas' },
  { id: 'cirurgia_pregressa', label: 'Cirurgias pregressas' },
]

const variaveisPorTipo = reactive<Record<VariavelTipoId, VariavelItem[]>>(
  variavelTipos.reduce(
    (acc, t) => {
      acc[t.id] = []
      return acc
    },
    {} as Record<VariavelTipoId, VariavelItem[]>,
  ),
)

const variavelAtiva = ref<VariavelTipoId>('alergia')
const novaVariavel = ref('')
const variavelEditIndex = ref<number | null>(null)
const variavelEditValue = ref('')

const formEstab = reactive({
  nomeFantasia: '',
  cpfCnpj: '',
  cep: '',
  logradouro: '',
  numero: '',
  complemento: '',
  bairro: '',
  cidade: '',
  estado: '',
})

const novaSala = reactive({
  nome: '',
  tipoSalaId: '',
})

const activeTab = ref<'dados' | 'salas' | 'variaveis' | 'outras'>('dados')

async function loadData() {
  if (!auth.currentUser?.id) {
    router.push('/login')
    return
  }

  isLoading.value = true
  try {
    const [estabResp, tiposSalaResp] = await Promise.all([
      supabase
        .from('estabelecimentos')
        .select('id, nome_fantasia, cpf_cnpj, cep, logradouro, numero, complemento, bairro, cidade, estado')
        .eq('owner_usuario_id', auth.currentUser.id)
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle(),
      supabase
        .from('tipo_sala_atendimento')
        .select('id, nome')
        .order('nome', { ascending: true }),
    ])

    if (estabResp.data) {
      const e = estabResp.data
      estabelecimentoId.value = e.id
      formEstab.nomeFantasia = e.nome_fantasia ?? ''
      formEstab.cpfCnpj = e.cpf_cnpj ?? ''
      formEstab.cep = e.cep ?? ''
      formEstab.logradouro = e.logradouro ?? ''
      formEstab.numero = e.numero ?? ''
      formEstab.complemento = e.complemento ?? ''
      formEstab.bairro = e.bairro ?? ''
      formEstab.cidade = e.cidade ?? ''
      formEstab.estado = e.estado ?? ''
    }

    if (tiposSalaResp.data) {
      tiposSala.value = tiposSalaResp.data as TipoSala[]
    }

    if (estabelecimentoId.value) {
      const { data: salasData, error: salasError } = await supabase
        .from('sala_atendimento')
        .select('id, nome')
        .eq('estabelecimento_id', estabelecimentoId.value)
        .order('created_at')

      if (!salasError && salasData) {
        salas.value = salasData as Sala[]
      }

      const { data: varsData, error: varsError } = await supabase
        .from('prontuario_variaveis_pool')
        .select('tipo, nome, estabelecimento_id')
        .in(
          'tipo',
          variavelTipos.map((v) => v.id),
        )

      if (!varsError && varsData) {
        const map = variaveisPorTipo as Record<string, VariavelItem[]>
        variavelTipos.forEach((v) => {
          map[v.id] = []
        })

        ;(
          varsData as {
            tipo: VariavelTipoId
            nome: string
            estabelecimento_id: string | null
          }[]
        ).forEach((row) => {
          if (!map[row.tipo]) {
            map[row.tipo] = []
          }
          map[row.tipo].push({
            nome: row.nome,
            estabelecimento_id: row.estabelecimento_id,
          })
        })

        variavelTipos.forEach((v) => {
          map[v.id] = map[v.id]
            .slice()
            .sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'))
        })
      }
    }
  } finally {
    isLoading.value = false
  }
}

async function saveEstabelecimento() {
  if (!auth.currentUser?.id) {
    feedback.error('Sessão expirada. Faça login novamente.')
    router.push('/login')
    return
  }
  if (!formEstab.nomeFantasia) {
    feedback.error('Informe o nome do estabelecimento.')
    return
  }

  let cpfCnpjToSave: string | null = null
  const digits = onlyDigits(formEstab.cpfCnpj)

  if (digits.length === 0) {
    cpfCnpjToSave = null
  } else if (digits.length === 14) {
    if (!isValidCnpj(digits)) {
      feedback.error('CNPJ inválido. Verifique os números informados.')
      return
    }
    cpfCnpjToSave = formatCpfCnpj(digits)
  } else if (digits.length === 11) {
    feedback.error(
      'CPF não é permitido para o estabelecimento. Use apenas CNPJ (14 dígitos) ou deixe em branco.',
    )
    return
  } else {
    feedback.error('CNPJ incompleto. Verifique e tente novamente.')
    return
  }

  isSavingEstab.value = true

  try {
    const payload = {
      nome_fantasia: formEstab.nomeFantasia,
      cpf_cnpj: cpfCnpjToSave,
      owner_usuario_id: auth.currentUser.id as string,
      tipo_pessoa: 'PJ',
      cep: formEstab.cep || null,
      logradouro: formEstab.logradouro || null,
      numero: formEstab.numero || null,
      complemento: formEstab.complemento || null,
      bairro: formEstab.bairro || null,
      cidade: formEstab.cidade || null,
      estado: formEstab.estado || null,
    }

    let error = null

    if (estabelecimentoId.value) {
      const { error: updateError } = await supabase
        .from('estabelecimentos')
        .update(payload)
        .eq('id', estabelecimentoId.value)
      error = updateError
    } else {
      const { data, error: insertError } = await supabase
        .from('estabelecimentos')
        .insert(payload)
        .select('id')
        .single()
      error = insertError
      if (data?.id) {
        estabelecimentoId.value = data.id
      }
    }

    if (error) {
      console.error(error)
      feedback.error('Não foi possível salvar o estabelecimento.')
      return
    }

    feedback.success('Dados do estabelecimento salvos com sucesso.')
  } finally {
    isSavingEstab.value = false
  }
}

async function addSala() {
  if (!estabelecimentoId.value) {
    feedback.error('Salve os dados do estabelecimento antes de cadastrar salas.')
    return
  }

  if (!novaSala.nome) {
    feedback.error('Informe o nome da sala.')
    return
  }

  isSavingSala.value = true

  try {
    const { data, error } = await supabase
      .from('sala_atendimento')
      .insert({
        estabelecimento_id: estabelecimentoId.value,
        nome: novaSala.nome,
        tipo_sala_id: novaSala.tipoSalaId || null,
      })
      .select('id, nome')
      .single()

    if (error) {
      console.error(error)
      feedback.error('Não foi possível cadastrar a sala.')
      return
    }

    salas.value.push({ id: data.id, nome: data.nome })
    novaSala.nome = ''
    novaSala.tipoSalaId = ''

    feedback.success('Sala cadastrada com sucesso.')
  } finally {
    isSavingSala.value = false
  }
}

async function addVariavel() {
  if (!estabelecimentoId.value) {
    feedback.error(
      'Salve os dados do estabelecimento antes de cadastrar variáveis.',
    )
    return
  }

  const nome = novaVariavel.value.trim()
  if (!nome) {
    feedback.error('Informe o nome da variável.')
    return
  }

  const tipo = variavelAtiva.value
  const lista = variaveisPorTipo[tipo]

  if (lista.some((v) => v.nome === nome)) {
    feedback.error('Essa opção já está cadastrada nessa lista.')
    return
  }

  isSavingVariavel.value = true
  try {
    const { error } = await supabase.from('prontuario_variaveis_pool').insert({
      estabelecimento_id: estabelecimentoId.value,
      tipo,
      nome,
    })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível cadastrar a variável.')
      return
    }

    lista.push({
      nome,
      estabelecimento_id: estabelecimentoId.value,
    })
    lista.sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'))
    novaVariavel.value = ''
    feedback.success('Varíavel cadastrada com sucesso.')
  } finally {
    isSavingVariavel.value = false
  }
}

async function saveVariavelEdit(index: number) {
  if (!estabelecimentoId.value) return

  const tipo = variavelAtiva.value
  const lista = variaveisPorTipo[tipo]
  const item = lista[index]
  if (!item || !item.estabelecimento_id) {
    feedback.error(
      'Apenas variáveis cadastradas pelo estabelecimento podem ser editadas.',
    )
    variavelEditIndex.value = null
    variavelEditValue.value = ''
    return
  }

  const original = item.nome
  const novoNome = variavelEditValue.value.trim()
  if (!novoNome || original === novoNome) {
    variavelEditIndex.value = null
    variavelEditValue.value = ''
    return
  }

  isSavingVariavel.value = true
  try {
    const { data, error } = await supabase
      .from('prontuario_variaveis_pool')
      .update({ nome: novoNome })
      .eq('tipo', tipo)
      .eq('estabelecimento_id', item.estabelecimento_id)
      .eq('nome', original)
      .select('nome')

    if (error) {
      console.error(error)
      feedback.error('Não foi possível atualizar a variável.')
      return
    }

    if (data && data.length > 0) {
      lista[index] = {
        ...item,
        nome: novoNome,
      }
      lista.sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'))
    }

    variavelEditIndex.value = null
    variavelEditValue.value = ''
    feedback.success('Variável atualizada com sucesso.')
  } finally {
    isSavingVariavel.value = false
  }
}

async function deleteVariavel(index: number) {
  if (!estabelecimentoId.value) return

  const tipo = variavelAtiva.value
  const lista = variaveisPorTipo[tipo]
  const item = lista[index]
  if (!item || !item.estabelecimento_id) {
    feedback.error(
      'Apenas variáveis cadastradas pelo estabelecimento podem ser excluídas.',
    )
    return
  }

  const nome = item.nome
  if (
    !window.confirm(
      `Deseja realmente excluir "${nome}"? Ela deixará de aparecer nos dropdowns deste estabelecimento.`,
    )
  ) {
    return
  }

  isSavingVariavel.value = true
  try {
    const { error } = await supabase
      .from('prontuario_variaveis_pool')
      .delete()
      .eq('tipo', tipo)
      .eq('estabelecimento_id', item.estabelecimento_id)
      .eq('nome', nome)

    if (error) {
      console.error(error)
      feedback.error('Não foi possível excluir a variável.')
      return
    }

    lista.splice(index, 1)
    feedback.success('Variável excluída com sucesso.')
  } finally {
    isSavingVariavel.value = false
  }
}

function goToMedicalRecordModels() {
  router.push({ name: 'medical-record-models' })
}

async function onCepBlurEstab() {
  if (!formEstab.cep) return
  try {
    const address = await fetchAddressByCep(formEstab.cep)
    if (!address) return

    formEstab.cep = address.cep
    if (!formEstab.logradouro) formEstab.logradouro = address.logradouro
    if (!formEstab.bairro) formEstab.bairro = address.bairro
    if (!formEstab.cidade) formEstab.cidade = address.localidade
    if (!formEstab.estado) formEstab.estado = address.uf
    if (!formEstab.complemento && address.complemento) {
      formEstab.complemento = address.complemento
    }
  } catch (e) {
    console.error(e)
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Configurações do estabelecimento
        </h1>
        <p class="text-sm text-gray-500">
          Complete as informações básicas e cadastre as salas de atendimento.
        </p>
      </div>
    </header>

    <div class="max-w-4xl space-y-6">
      <div class="inline-flex rounded-full bg-gray-50 p-1 text-xs font-semibold text-gray-600 mb-2">
        <button
          class="px-4 py-1 rounded-full"
          :class="activeTab === 'dados' ? 'bg-white text-primary-700 shadow-sm' : ''"
          type="button"
          @click="activeTab = 'dados'"
        >
          Dados do estabelecimento
        </button>
        <button
          class="px-4 py-1 rounded-full"
          :class="activeTab === 'salas' ? 'bg-white text-primary-700 shadow-sm' : ''"
          type="button"
          @click="activeTab = 'salas'"
        >
          Salas de atendimento
        </button>
        <button
          class="px-4 py-1 rounded-full"
          :class="activeTab === 'variaveis' ? 'bg-white text-primary-700 shadow-sm' : ''"
          type="button"
          @click="activeTab = 'variaveis'"
        >
          Listas de variáveis
        </button>
        <button
          class="px-4 py-1 rounded-full"
          :class="activeTab === 'outras' ? 'bg-white text-primary-700 shadow-sm' : ''"
          type="button"
          @click="activeTab = 'outras'"
        >
          Outras configurações
        </button>
      </div>

      <div
        v-if="activeTab === 'dados'"
        class="bg-white rounded-xl shadow-sm border border-gray-100 p-6"
      >
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          Dados do estabelecimento
        </h2>
        <form class="space-y-4" @submit.prevent="saveEstabelecimento">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                Nome fantasia
              </label>
              <input
                v-model="formEstab.nomeFantasia"
                type="text"
                placeholder="Nome que aparecerá para pacientes"
                class="form-input"
              />
            </div>
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                CNPJ (opcional)
              </label>
              <input
                v-model="formEstab.cpfCnpj"
                type="text"
                maxlength="18"
                placeholder="Digite o CNPJ (opcional)"
                class="form-input"
                @input="formEstab.cpfCnpj = formatCpfCnpj(formEstab.cpfCnpj)"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                CEP
              </label>
              <input
                v-model="formEstab.cep"
                type="text"
                maxlength="9"
                placeholder="_____‑___"
                class="form-input"
                @input="formEstab.cep = formatCep(formEstab.cep)"
                @blur="onCepBlurEstab"
              />
            </div>
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                Endereço
              </label>
              <input
                v-model="formEstab.logradouro"
                type="text"
                placeholder="Rua, avenida..."
                class="form-input"
              />
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                Número
              </label>
              <input
                v-model="formEstab.numero"
                type="text"
                class="form-input"
              />
            </div>
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                Complemento
              </label>
              <input
                v-model="formEstab.complemento"
                type="text"
                class="form-input"
              />
            </div>
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                Bairro
              </label>
              <input
                v-model="formEstab.bairro"
                type="text"
                class="form-input"
              />
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="md:col-span-2">
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                Cidade
              </label>
              <input
                v-model="formEstab.cidade"
                type="text"
                class="form-input"
              />
            </div>
            <div>
              <label class="block text-sm font-semibold text-gray-700 mb-1">
                UF
              </label>
              <input
                v-model="formEstab.estado"
                type="text"
                maxlength="2"
                class="form-input"
              />
            </div>
          </div>

          <div class="flex justify-end mt-4">
            <button
              type="submit"
              class="btn-primary max-w-xs disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSavingEstab"
            >
              {{ isSavingEstab ? 'Salvando...' : 'Salvar estabelecimento' }}
            </button>
          </div>
        </form>
      </div>

      <div
        v-if="activeTab === 'salas'"
        class="bg-white rounded-xl shadow-sm border border-gray-100 p-6"
      >
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          Salas de atendimento
        </h2>

        <form
          class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end mb-4"
          @submit.prevent="addSala"
        >
          <div class="md:col-span-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Nome da sala
            </label>
            <input
              v-model="novaSala.nome"
              type="text"
              placeholder="Ex.: Sala 01, Cirurgia"
              class="form-input"
            />
          </div>
          <div class="md:col-span-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Tipo de sala
            </label>
            <select v-model="novaSala.tipoSalaId" class="form-input">
              <option value="">
                Selecione (opcional)
              </option>
              <option
                v-for="tipo in tiposSala"
                :key="tipo.id"
                :value="tipo.id"
              >
                {{ tipo.nome }}
              </option>
            </select>
          </div>
          <div class="md:col-span-1 flex justify-end">
            <button
              type="submit"
              class="btn-primary max-w-xs disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSavingSala"
            >
              {{ isSavingSala ? 'Adicionando...' : 'Adicionar sala' }}
            </button>
          </div>
        </form>

        <div v-if="!salas.length" class="text-sm text-gray-500">
          Nenhuma sala cadastrada ainda.
        </div>
        <ul v-else class="divide-y divide-gray-100 text-sm">
          <li
            v-for="sala in salas"
            :key="sala.id"
            class="py-2 flex items-center justify-between"
          >
            <span class="text-gray-800">{{ sala.nome }}</span>
          </li>
        </ul>
      </div>

      <div
        v-if="activeTab === 'variaveis'"
        class="bg-white rounded-xl shadow-sm border border-gray-100 p-6"
      >
        <h2 class="text-sm font-semibold text-primary-700 mb-2">
          Listas de variáveis
        </h2>
        <p class="text-xs text-gray-500 mb-4">
          Gerencie listas usadas em dropdowns do prontuário, como alergias, cirurgias, doenças e outras variáveis.
        </p>

        <div class="mb-4 flex flex-wrap gap-2 text-[11px]">
          <button
            v-for="tipo in variavelTipos"
            :key="tipo.id"
            type="button"
            class="px-3 py-1 rounded-full border"
            :class="
              variavelAtiva === tipo.id
                ? 'border-primary-600 bg-primary-50 text-primary-700'
                : 'border-gray-200 bg-gray-50 text-gray-600'
            "
            @click="
              variavelAtiva = tipo.id;
              variavelEditIndex = null;
              variavelEditValue = '';
            "
          >
            {{ tipo.label }}
          </button>
        </div>

        <form
          class="grid grid-cols-1 md:grid-cols-[1.6fr,auto] gap-3 items-end mb-4"
          @submit.prevent="addVariavel"
        >
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Nova opção
            </label>
            <input
              v-model="novaVariavel"
              type="text"
              placeholder="Digite uma nova opção para esta lista"
              class="form-input text-xs"
            />
          </div>
          <div class="flex justify-end">
            <button
              type="submit"
              class="btn-primary max-w-xs text-xs disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSavingVariavel"
            >
              {{ isSavingVariavel ? 'Adicionando...' : 'Adicionar' }}
            </button>
          </div>
        </form>

        <div
          v-if="!variaveisPorTipo[variavelAtiva].length"
          class="text-sm text-gray-500"
        >
          Nenhuma opção cadastrada ainda para esta lista.
        </div>
        <ul v-else class="divide-y divide-gray-100 text-sm">
          <li
            v-for="(item, index) in variaveisPorTipo[variavelAtiva]"
            :key="`${item.nome}-${item.estabelecimento_id ?? 'default'}`"
            class="py-2 flex items-center justify-between gap-3"
          >
            <div class="flex-1 flex items-center gap-2">
              <input
                v-if="variavelEditIndex === index"
                v-model="variavelEditValue"
                type="text"
                class="form-input text-xs"
              />
              <span
                v-else
                class="text-gray-800 text-xs"
              >
                {{ item.nome }}
              </span>
              <span
                v-if="!item.estabelecimento_id"
                class="inline-flex items-center rounded-full bg-gray-100 text-gray-500 px-2 py-0.5 text-[10px]"
              >
                Padrão do sistema
              </span>
            </div>
            <div class="flex items-center gap-2 text-[11px]">
              <button
                v-if="item.estabelecimento_id"
                type="button"
                class="text-primary-600 hover:underline"
                @click="
                  variavelEditIndex = index;
                  variavelEditValue = item.nome;
                "
              >
                Editar
              </button>
              <button
                v-if="item.estabelecimento_id && variavelEditIndex === index"
                type="button"
                class="text-primary-600 hover:underline"
                @click="saveVariavelEdit(index)"
              >
                Salvar
              </button>
              <button
                v-if="item.estabelecimento_id"
                type="button"
                class="text-red-600 hover:underline disabled:opacity-50"
                :disabled="isSavingVariavel"
                @click="deleteVariavel(index)"
              >
                Excluir
              </button>
            </div>
          </li>
        </ul>
      </div>

      <div
        v-if="activeTab === 'outras'"
        class="bg-white rounded-xl shadow-sm border border-gray-100 p-6"
      >
        <h2 class="text-sm font-semibold text-primary-700 mb-2">
          Modelos de prontuário
        </h2>
        <p class="text-xs text-gray-500 mb-3">
          Configure os modelos de prontuário que poderão ser utilizados nas
          evoluções de pacientes neste estabelecimento.
        </p>
        <button
          type="button"
          class="inline-flex items-center rounded-lg border border-primary-600 text-primary-600 text-xs font-semibold px-4 py-2 hover:bg-primary-light"
          @click="goToMedicalRecordModels"
        >
          Gerenciar modelos de prontuário
        </button>
      </div>

      <p v-if="isLoading" class="text-xs text-gray-400">
        Carregando dados do estabelecimento...
      </p>
    </div>
  </section>
</template>
