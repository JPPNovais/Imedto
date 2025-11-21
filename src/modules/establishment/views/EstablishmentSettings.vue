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

const auth = useAuthStore()
const feedback = useFeedbackStore()
const router = useRouter()

const estabelecimentoId = ref<string | null>(null)
const isLoading = ref(false)
const isSavingEstab = ref(false)
const isSavingSala = ref(false)

const tiposSala = ref<TipoSala[]>([])
const salas = ref<Sala[]>([])

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
    feedback.error('Use apenas CNPJ (14 dígitos) ou deixe em branco.')
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
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
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
                CPF / CNPJ
              </label>
              <input
                v-model="formEstab.cpfCnpj"
                type="text"
                maxlength="18"
                placeholder="Digite o CPF ou CNPJ"
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

      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
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

      <p v-if="isLoading" class="text-xs text-gray-400">
        Carregando dados do estabelecimento...
      </p>
    </div>
  </section>
</template>
