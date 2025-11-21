<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import {
  formatCpfCnpj,
  formatPhone,
  onlyDigits,
} from '@/utils/masks'

type Paciente = {
  id: string
  nome_completo: string
  cpf_cnpj: string | null
  telefone: string | null
  telefone_celular: string | null
  telefone_fixo: string | null
  data_nascimento: string | null
  sexo: string | null
  cep: string | null
  logradouro: string | null
  numero: string | null
  complemento: string | null
  bairro: string | null
  cidade: string | null
  estado: string | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()

const isLoading = ref(false)
const pacientes = ref<Paciente[]>([])
const filter = reactive({
  search: '',
})

const isEditing = ref(false)
const isSaving = ref(false)
const editForm = reactive({
  id: '',
  nome: '',
  cpfCnpj: '',
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

const isDeleting = ref(false)
const patientToDeleteId = ref<string | null>(null)

const filteredPacientes = computed(() => {
  if (!filter.search) return pacientes.value
  const term = filter.search.toLowerCase()
  return pacientes.value.filter((p) => {
    const name = p.nome_completo?.toLowerCase() ?? ''
    const doc = (p.cpf_cnpj ?? '').toLowerCase()
    return name.includes(term) || doc.includes(term)
  })
})

async function loadPacientes() {
  if (!auth.currentUser?.id) return
  isLoading.value = true
  pacientes.value = []
  try {
    // identifica estabelecimento do usuário (owner ou profissional vinculado)
    let estabelecimentoId: string | null = null

    const { data: estabOwner } = await supabase
      .from('estabelecimentos')
      .select('id')
      .eq('owner_usuario_id', auth.currentUser.id)
      .order('created_at', { ascending: true })
      .limit(1)
      .maybeSingle()

    if (estabOwner?.id) {
      estabelecimentoId = estabOwner.id
    } else {
      const { data: profissional } = await supabase
        .from('profissionais')
        .select('id')
        .eq('usuario_id', auth.currentUser.id)
        .limit(1)
        .maybeSingle()

      if (profissional?.id) {
        const { data: vinculo } = await supabase
          .from('vinculo_profissional_estabelecimento')
          .select('estabelecimento_id')
          .eq('profissional_id', profissional.id)
          .limit(1)
          .maybeSingle()

        if (vinculo?.estabelecimento_id) {
          estabelecimentoId = vinculo.estabelecimento_id
        }
      }
    }

    if (!estabelecimentoId) {
      feedback.info(
        'Nenhum estabelecimento encontrado para carregar pacientes vinculados.',
      )
      return
    }

    // busca pacientes diretamente pela coluna estabelecimento_id
    const { data: pacientesData, error: pacError } = await supabase
      .from('pacientes')
      .select(
        'id, nome_completo, cpf_cnpj, telefone, telefone_celular, telefone_fixo, data_nascimento, sexo, cep, logradouro, numero, complemento, bairro, cidade, estado',
      )
      .eq('estabelecimento_id', estabelecimentoId)
      .order('nome_completo', { ascending: true })

    if (pacError) {
      console.error(pacError)
      feedback.error('Não foi possível carregar os pacientes do estabelecimento.')
      return
    }

    pacientes.value = (pacientesData ?? []) as Paciente[]
  } finally {
    isLoading.value = false
  }
}

function openEdit(p: Paciente) {
  editForm.id = p.id
  editForm.nome = p.nome_completo
  editForm.cpfCnpj = p.cpf_cnpj ? formatCpfCnpj(p.cpf_cnpj) : ''
  editForm.celular = p.telefone_celular
    ? formatPhone(p.telefone_celular)
    : p.telefone
      ? formatPhone(p.telefone)
      : ''
  editForm.telefoneFixo = p.telefone_fixo ? formatPhone(p.telefone_fixo) : ''
  editForm.dataNascimento = p.data_nascimento ?? ''
  editForm.sexo = p.sexo ?? ''
  editForm.cep = p.cep ?? ''
  editForm.logradouro = p.logradouro ?? ''
  editForm.numero = p.numero ?? ''
  editForm.complemento = p.complemento ?? ''
  editForm.bairro = p.bairro ?? ''
  editForm.cidade = p.cidade ?? ''
  editForm.estado = p.estado ?? ''
  isEditing.value = true
}

function openDelete(p: Paciente) {
  patientToDeleteId.value = p.id
  isDeleting.value = true
}

async function saveEdit() {
  if (!editForm.nome) {
    feedback.error('Informe o nome do paciente.')
    return
  }

  isSaving.value = true
  try {
    const digits = onlyDigits(editForm.cpfCnpj)
    const celular = editForm.celular || ''
    const fixo = editForm.telefoneFixo || ''

    const { error } = await supabase
      .from('pacientes')
      .update({
        nome_completo: editForm.nome,
        cpf_cnpj: digits || null,
        telefone: celular || fixo || null,
        telefone_celular: celular || null,
        telefone_fixo: fixo || null,
        data_nascimento: editForm.dataNascimento || null,
        sexo: editForm.sexo || null,
        cep: editForm.cep || null,
        logradouro: editForm.logradouro || null,
        numero: editForm.numero || null,
        complemento: editForm.complemento || null,
        bairro: editForm.bairro || null,
        cidade: editForm.cidade || null,
        estado: editForm.estado || null,
      })
      .eq('id', editForm.id)

    if (error) {
      console.error(error)
      feedback.error('Não foi possível salvar as alterações do paciente.')
      return
    }

    feedback.success('Paciente atualizado com sucesso.')
    isEditing.value = false
    await loadPacientes()
  } finally {
    isSaving.value = false
  }
}

async function deletePatient() {
  if (!patientToDeleteId.value) {
    isDeleting.value = false
    return
  }

  // verifica se há agendamentos vinculados
  const { data: eventos, error: evError } = await supabase
    .from('evento_de_agendamento')
    .select('id')
    .eq('paciente_id', patientToDeleteId.value)
    .limit(1)

  if (evError) {
    console.error(evError)
    feedback.error('Não foi possível verificar agendamentos do paciente.')
    return
  }

  if (eventos && eventos.length) {
    feedback.error(
      'Não é possível excluir um paciente que possui agendamentos cadastrados.',
    )
    isDeleting.value = false
    return
  }

  const { error } = await supabase
    .from('pacientes')
    .delete()
    .eq('id', patientToDeleteId.value)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível excluir o paciente.')
    return
  }

  feedback.success('Paciente excluído com sucesso.')
  isDeleting.value = false
  patientToDeleteId.value = null
  await loadPacientes()
}

onMounted(() => {
  loadPacientes()
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Pacientes do estabelecimento
        </h1>
        <p class="text-sm text-gray-500">
          Veja todos os pacientes vinculados a este estabelecimento.
        </p>
      </div>
    </header>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
      <div class="mb-4 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div class="text-xs text-gray-500">
          {{ filteredPacientes.length }} paciente(s) encontrado(s).
        </div>
        <div class="flex items-center gap-2">
          <label class="text-xs text-gray-600">
            Buscar:
          </label>
          <input
            v-model="filter.search"
            class="form-input text-xs w-60"
            placeholder="Nome ou CPF/CNPJ"
            type="text"
          />
        </div>
      </div>

      <div v-if="isLoading" class="text-xs text-gray-400">
        Carregando pacientes...
      </div>
      <div v-else-if="!filteredPacientes.length" class="text-sm text-gray-500">
        Nenhum paciente vinculado a este estabelecimento.
      </div>
      <div v-else class="overflow-x-auto">
        <table class="min-w-full text-xs">
          <thead>
            <tr class="text-left text-gray-500 border-b border-gray-100">
              <th class="py-2 pr-4">
                Nome
              </th>
              <th class="py-2 pr-4">
                CPF / CNPJ
              </th>
              <th class="py-2 pr-4">
                Celular
              </th>
              <th class="py-2 pr-4">
                Telefone fixo
              </th>
              <th class="py-2 pr-4">
                Data de nascimento
              </th>
              <th class="py-2 pr-4">
                Sexo
              </th>
              <th class="py-2 pr-4">
                Cidade / UF
              </th>
              <th class="py-2 pr-4 text-right">
                Ações
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="pac in filteredPacientes"
              :key="pac.id"
              class="border-b border-gray-50 hover:bg-gray-50/60"
            >
              <td class="py-2 pr-4 font-medium text-gray-800">
                {{ pac.nome_completo }}
              </td>
              <td class="py-2 pr-4 text-gray-700">
                {{ pac.cpf_cnpj ? formatCpfCnpj(pac.cpf_cnpj) : '—' }}
              </td>
              <td class="py-2 pr-4 text-gray-700">
                {{ pac.telefone_celular || pac.telefone || '—' }}
              </td>
              <td class="py-2 pr-4 text-gray-700">
                {{ pac.telefone_fixo || '—' }}
              </td>
              <td class="py-2 pr-4 text-gray-700">
                {{
                  pac.data_nascimento
                    ? new Date(pac.data_nascimento).toLocaleDateString()
                    : '—'
                }}
              </td>
              <td class="py-2 pr-4 text-gray-700">
                {{
                  pac.sexo === 'masculino'
                    ? 'Masculino'
                    : pac.sexo === 'feminino'
                      ? 'Feminino'
                      : pac.sexo === 'outro'
                        ? 'Outro'
                        : 'Não informado'
                }}
              </td>
              <td class="py-2 pr-4 text-gray-700">
                {{
                  pac.cidade
                    ? `${pac.cidade}${pac.estado ? ` / ${pac.estado}` : ''}`
                    : '—'
                }}
              </td>
              <td class="py-2 pr-4 text-right">
                <button
                  class="text-xs text-primary-600 underline mr-3"
                  type="button"
                  @click="openEdit(pac)"
                >
                  Editar
                </button>
                <button
                  class="text-xs text-red-600 underline"
                  type="button"
                  @click="openDelete(pac)"
                >
                  Excluir
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal edição de paciente -->
    <div
      v-if="isEditing"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
    >
      <div class="w-full max-w-2xl bg-white rounded-2xl shadow-lg p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          Editar paciente
        </h2>
        <form class="space-y-4" @submit.prevent="saveEdit">
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Nome completo
            </label>
            <input
              v-model="editForm.nome"
              class="form-input text-xs"
              placeholder="Nome do paciente"
              type="text"
            />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                CPF / CNPJ
              </label>
              <input
                v-model="editForm.cpfCnpj"
                class="form-input text-xs"
                placeholder="Digite o CPF ou CNPJ"
                type="text"
                maxlength="18"
                @input="
                  editForm.cpfCnpj = formatCpfCnpj(editForm.cpfCnpj)
                "
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Celular
              </label>
              <input
                v-model="editForm.celular"
                class="form-input text-xs"
                placeholder="( ) _____-____"
                type="text"
                maxlength="15"
                @input="
                  editForm.celular = formatPhone(editForm.celular)
                "
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Telefone fixo
              </label>
              <input
                v-model="editForm.telefoneFixo"
                class="form-input text-xs"
                placeholder="( ) ____-____"
                type="text"
                maxlength="14"
                @input="
                  editForm.telefoneFixo = formatPhone(editForm.telefoneFixo)
                "
              />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Data de nascimento
              </label>
              <input
                v-model="editForm.dataNascimento"
                class="form-input text-xs"
                type="date"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Sexo
              </label>
              <select
                v-model="editForm.sexo"
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
          <div class="grid grid-cols-3 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                CEP
              </label>
              <input
                v-model="editForm.cep"
                class="form-input text-xs"
                placeholder="_____‑___"
                type="text"
              />
            </div>
            <div class="col-span-2">
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Cidade
              </label>
              <input
                v-model="editForm.cidade"
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
                v-model="editForm.estado"
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
              @click="isEditing = false"
            >
              Cancelar
            </button>
            <button
              class="btn-primary max-w-[160px] text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
              type="submit"
              :disabled="isSaving"
            >
              {{ isSaving ? 'Salvando...' : 'Salvar alterações' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Modal confirmação de exclusão -->
    <div
      v-if="isDeleting"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
    >
      <div class="w-full max-w-sm bg-white rounded-2xl shadow-lg p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-2">
          Excluir paciente
        </h2>
        <p class="text-xs text-gray-500 mb-4">
          Tem certeza que deseja excluir este paciente? Essa ação não poderá ser
          desfeita.
        </p>
        <div class="flex justify-end gap-3 mt-4">
          <button
            class="text-xs text-gray-500 underline"
            type="button"
            @click="isDeleting = false"
          >
            Cancelar
          </button>
          <button
            class="bg-red-600 text-white text-xs font-semibold px-4 py-2 rounded-lg"
            type="button"
            @click="deletePatient"
          >
            Excluir
          </button>
        </div>
      </div>
    </div>
  </section>
</template>
