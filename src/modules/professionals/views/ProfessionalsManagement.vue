<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type ProfissionalVinculado = {
  id: string
  is_admin: boolean
  ativo: boolean
  profissional_nome: string
  profissao_nome: string | null
  email: string | null
  salario_base: number | null
  valor_dia: number | null
  foto_url: string | null
}

type Solicitacao = {
  id: string
  email_profissional: string
  status: string
  profissao_nome: string | null
  especialidade_nome: string | null
  created_at: string
}

type Profissao = { id: string; nome: string }
type Especialidade = { id: string; nome: string }

const auth = useAuthStore()
const feedback = useFeedbackStore()

const estabelecimentoId = ref<string | null>(null)
const estabelecimentoNome = ref('')
const estabelecimentoFoto = ref<string | null>(null)

const isLoading = ref(false)
const isLoadingSolicitacoes = ref(false)
const isSendingInvite = ref(false)
const profissionais = ref<ProfissionalVinculado[]>([])
const solicitacoes = ref<Solicitacao[]>([])
const profissoes = ref<Profissao[]>([])
const especialidades = ref<Especialidade[]>([])
const statusFilter = ref<'ativos' | 'inativos' | 'todos'>('ativos')

const inviteForm = reactive({
  email: '',
  profissaoId: '',
  especialidadeId: '',
})

const activeTab = ref<'vinculados' | 'solicitacoes'>('vinculados')

const filteredProfissionais = computed(() => {
  if (statusFilter.value === 'todos') {
    return profissionais.value
  }
  const shouldBeActive = statusFilter.value === 'ativos'
  return profissionais.value.filter((p) => !!p.ativo === shouldBeActive)
})

async function loadEstabelecimento() {
  if (!auth.currentUser?.id) return

  const { data, error } = await supabase
    .from('estabelecimentos')
    .select('id, nome_fantasia, foto_url')
    .eq('owner_usuario_id', auth.currentUser.id)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar os dados do estabelecimento.')
    return
  }

  if (data) {
    estabelecimentoId.value = data.id
    estabelecimentoNome.value = data.nome_fantasia ?? ''
    estabelecimentoFoto.value = data.foto_url ?? null
  }
}

async function loadProfissionais() {
  if (!estabelecimentoId.value) return

  isLoading.value = true
  try {
    const { data, error } = await supabase
      .from('vinculo_profissional_estabelecimento')
      .select(
        `
        id,
        ativo,
        is_admin,
        salario_base,
        valor_dia,
        profissional:profissionais (
          id,
          nome_exibicao,
          foto_url,
          profissao:profissoes ( nome )
        )
      `,
      )
      .eq('estabelecimento_id', estabelecimentoId.value)

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar os profissionais vinculados.')
      return
    }

    profissionais.value =
      data?.map((item: any) => ({
        id: item.id,
        is_admin: item.is_admin,
        ativo: item.ativo ?? true,
        profissional_nome: item.profissional?.nome_exibicao ?? 'Profissional',
        profissao_nome: item.profissional?.profissao?.nome ?? null,
        email: null,
        salario_base: item.salario_base,
        valor_dia: item.valor_dia,
        foto_url: item.profissional?.foto_url ?? null,
      })) ?? []
  } finally {
    isLoading.value = false
  }
}

async function loadSolicitacoes() {
  if (!estabelecimentoId.value) return

  isLoadingSolicitacoes.value = true
  try {
    const { data, error } = await supabase
      .from('solicitacao_vinculo_profissional_estabelecimento')
      .select(
        `
        id,
        email_profissional,
        status,
        created_at,
        profissao:profissoes ( nome ),
        especialidade:especialidades ( nome )
      `,
      )
      .eq('estabelecimento_id', estabelecimentoId.value)
      .order('created_at', { ascending: false })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar as solicitações.')
      return
    }

    solicitacoes.value =
      data?.map((s: any) => ({
        id: s.id,
        email_profissional: s.email_profissional,
        status: s.status,
        profissao_nome: s.profissao?.nome ?? null,
        especialidade_nome: s.especialidade?.nome ?? null,
        created_at: s.created_at,
      })) ?? []
  } finally {
    isLoadingSolicitacoes.value = false
  }
}

async function loadDominios() {
  const [profResp, espResp] = await Promise.all([
    supabase.from('profissoes').select('id, nome').order('nome'),
    supabase.from('especialidades').select('id, nome').order('nome'),
  ])

  if (!profResp.error && profResp.data) {
    profissoes.value = profResp.data as Profissao[]
  }
  if (!espResp.error && espResp.data) {
    especialidades.value = espResp.data as Especialidade[]
  }
}

async function sendInvite() {
  if (!estabelecimentoId.value) {
    feedback.error('Salve as informações do estabelecimento antes de convidar profissionais.')
    return
  }

  if (!inviteForm.email) {
    feedback.error('Informe o e-mail do profissional que deseja convidar.')
    return
  }

  const targetEmail = inviteForm.email.toLowerCase().trim()

  isSendingInvite.value = true

  try {
    // Verifica se já existe vínculo ativo para este e-mail
    const { data: alreadyLinked, error: checkError } = await supabase.rpc(
      'is_professional_linked_to_establishment',
      {
        p_email: targetEmail,
        p_estabelecimento_id: estabelecimentoId.value,
      },
    )

    if (checkError) {
      console.error(checkError)
    } else if (alreadyLinked) {
      feedback.error(
        'Este profissional já está vinculado e ativo neste estabelecimento.',
      )
      return
    }

    const { error } = await supabase
      .from('solicitacao_vinculo_profissional_estabelecimento')
      .insert({
        estabelecimento_id: estabelecimentoId.value,
        email_profissional: targetEmail,
        profissao_id: inviteForm.profissaoId || null,
        especialidade_id: inviteForm.especialidadeId || null,
        status: 'pendente',
      })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível enviar o convite.')
      return
    }

    // Opcional: dispara função de envio de e-mail (edge function)
    try {
      await supabase.functions.invoke('send-professional-invite', {
        body: {
          email: inviteForm.email.toLowerCase(),
          estabelecimentoId: estabelecimentoId.value,
          estabelecimentoNome: estabelecimentoNome.value,
        },
      })
    } catch (fnError) {
      console.warn('Falha ao chamar função de e-mail:', fnError)
    }

    feedback.success('Convite enviado com sucesso.')
    inviteForm.email = ''
    inviteForm.profissaoId = ''
    inviteForm.especialidadeId = ''
    await loadSolicitacoes()
  } finally {
    isSendingInvite.value = false
  }
}

async function cancelSolicitacao(id: string) {
  const { error } =
    await supabase
      .from('solicitacao_vinculo_profissional_estabelecimento')
      .update({ status: 'cancelado' })
      .eq('id', id)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível cancelar a solicitação.')
    return
  }

  feedback.success('Solicitação cancelada.')
  await loadSolicitacoes()
}

async function deleteSolicitacao(id: string) {
  const { error } =
    await supabase
      .from('solicitacao_vinculo_profissional_estabelecimento')
      .delete()
      .eq('id', id)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível excluir a solicitação.')
    return
  }

  feedback.success('Solicitação excluída.')
  await loadSolicitacoes()
}

async function resendSolicitacao(s: Solicitacao) {
  if (!estabelecimentoId.value) return

  isSendingInvite.value = true
  try {
    try {
      await supabase.functions.invoke('send-professional-invite', {
        body: {
          email: s.email_profissional.toLowerCase(),
          estabelecimentoId: estabelecimentoId.value,
          estabelecimentoNome: estabelecimentoNome.value,
        },
      })
    } catch (fnError) {
      console.warn('Falha ao chamar função de e-mail:', fnError)
    }

    feedback.success('Convite reenviado com sucesso.')
  } finally {
    isSendingInvite.value = false
  }
}

async function updateVinculoValores(
  vinculoId: string,
  salarioBase: number | null,
  valorDia: number | null,
) {
  const { error } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .update({
      salario_base: salarioBase,
      valor_dia: valorDia,
    })
    .eq('id', vinculoId)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível atualizar os valores do profissional.')
    return
  }

  feedback.success('Valores do profissional atualizados com sucesso.')
}

async function setVinculoAtivo(vinculoId: string, ativo: boolean) {
  const { error } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .update({ ativo })
    .eq('id', vinculoId)

  if (error) {
    console.error(error)
    feedback.error(
      ativo
        ? 'Não foi possível reativar o profissional.'
        : 'Não foi possível desativar o profissional.',
    )
    return
  }

  feedback.success(
    ativo
      ? 'Profissional reativado com sucesso.'
      : 'Profissional desativado com sucesso.',
  )
  await loadProfissionais()
}

onMounted(async () => {
  if (!auth.currentUser?.id) return
  await loadEstabelecimento()
  await Promise.all([loadDominios(), loadProfissionais(), loadSolicitacoes()])
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Profissionais do estabelecimento
        </h1>
        <p class="text-sm text-gray-500">
          Gerencie os profissionais vinculados, convites e permissões de acesso.
        </p>
      </div>
    </header>

    <div v-if="!estabelecimentoId" class="text-sm text-gray-600">
      <p>
        Nenhum estabelecimento encontrado para o seu usuário. Crie e configure
        um estabelecimento antes de gerenciar profissionais.
      </p>
    </div>

    <div v-else class="space-y-6 w-full">
      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
        <div class="flex items-center gap-4">
          <div
            class="h-12 w-12 rounded-full bg-primary-light flex items-center justify-center text-primary-dark font-semibold text-lg overflow-hidden"
          >
            <img
              v-if="estabelecimentoFoto"
              :src="estabelecimentoFoto"
              alt="Logo do estabelecimento"
              class="h-full w-full object-cover"
            />
            <span v-else>
              {{ estabelecimentoNome?.[0] ?? 'E' }}
            </span>
          </div>
          <div>
            <p class="text-xs text-gray-500">
              Estabelecimento
            </p>
            <p class="text-sm font-semibold text-primary-dark">
              {{ estabelecimentoNome || 'Sem nome definido' }}
            </p>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          Enviar convite para profissional
        </h2>
        <form
          class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end"
          @submit.prevent="sendInvite"
        >
          <div class="md:col-span-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              E-mail do profissional
            </label>
            <input
              v-model="inviteForm.email"
              type="email"
              placeholder="profissional@exemplo.com"
              class="form-input"
            />
          </div>
          <div class="md:col-span-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Profissão (opcional)
            </label>
            <select v-model="inviteForm.profissaoId" class="form-input">
              <option value="">
                Selecione
              </option>
              <option
                v-for="p in profissoes"
                :key="p.id"
                :value="p.id"
              >
                {{ p.nome }}
              </option>
            </select>
          </div>
          <div class="md:col-span-1">
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Especialidade (opcional)
            </label>
            <select v-model="inviteForm.especialidadeId" class="form-input">
              <option value="">
                Selecione
              </option>
              <option
                v-for="e in especialidades"
                :key="e.id"
                :value="e.id"
              >
                {{ e.nome }}
              </option>
            </select>
          </div>
          <div class="md:col-span-3 flex justify-end mt-2">
            <button
              type="submit"
              class="btn-primary max-w-xs h-14 disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSendingInvite"
            >
              {{
                isSendingInvite ? 'Enviando convite...' : 'Enviar convite'
              }}
            </button>
          </div>
        </form>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-100">
        <div class="border-b border-gray-100 px-6 pt-4">
          <div class="inline-flex rounded-full bg-gray-50 p-1 text-xs font-semibold text-gray-600">
            <button
              class="px-4 py-1 rounded-full"
              :class="activeTab === 'vinculados' ? 'bg-white text-primary-700 shadow-sm' : ''"
              type="button"
              @click="activeTab = 'vinculados'"
            >
              Profissionais vinculados
            </button>
            <button
              class="px-4 py-1 rounded-full"
              :class="activeTab === 'solicitacoes' ? 'bg-white text-primary-700 shadow-sm' : ''"
              type="button"
              @click="activeTab = 'solicitacoes'"
            >
              Solicitações enviadas
            </button>
          </div>
        </div>

        <div class="p-6 space-y-6">
          <div v-if="activeTab === 'vinculados'">
            <div class="mb-4 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <h2 class="text-sm font-semibold text-primary-700">
                Profissionais vinculados
              </h2>
              <div class="flex items-center gap-2 text-xs">
                <span class="text-gray-600">
                  Status:
                </span>
                <select
                  v-model="statusFilter"
                  class="form-input text-[11px] h-7 w-40"
                >
                  <option value="ativos">
                    Ativos
                  </option>
                  <option value="inativos">
                    Inativos
                  </option>
                  <option value="todos">
                    Todos
                  </option>
                </select>
              </div>
            </div>
            <div v-if="isLoading" class="text-xs text-gray-400">
              Carregando profissionais...
            </div>
            <div
              v-else-if="!filteredProfissionais.length"
              class="text-sm text-gray-500"
            >
              Nenhum profissional encontrado para o filtro selecionado.
            </div>
            <table
              v-else
              class="w-full text-xs text-left border-collapse border-spacing-0"
            >
              <thead>
                <tr class="border-b border-gray-100 text-gray-500">
                  <th class="py-2 pr-4 font-medium">Profissional</th>
                  <th class="py-2 pr-4 font-medium">Profissão</th>
                  <th class="py-2 pr-4 font-medium">E-mail</th>
                  <th class="py-2 pr-2 font-medium">Salário base</th>
                  <th class="py-2 pr-2 font-medium">Valor/dia</th>
                  <th class="py-2 pr-4 font-medium text-right">Perfil / status</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="prof in filteredProfissionais"
                  :key="prof.id"
                  class="border-b border-gray-50"
                >
                  <td class="py-2 pr-4 text-gray-800">
                    <div class="flex items-center gap-2">
                      <div
                        class="h-7 w-7 rounded-full bg-primary-light flex items-center justify-center text-primary-dark text-[10px] font-semibold overflow-hidden"
                      >
                        <img
                          v-if="prof.foto_url"
                          :src="prof.foto_url"
                          alt="Foto do profissional"
                          class="h-full w-full object-cover"
                        />
                        <span v-else>
                          {{ prof.profissional_nome?.[0] ?? 'P' }}
                        </span>
                      </div>
                      <span>{{ prof.profissional_nome }}</span>
                    </div>
                  </td>
                  <td class="py-2 pr-4 text-gray-600">
                    {{ prof.profissao_nome || '—' }}
                  </td>
                  <td class="py-2 pr-4 text-gray-600">
                    {{ prof.email || '—' }}
                  </td>
                  <td class="py-2 pr-2 text-gray-600">
                    <input
                      v-model.number="prof.salario_base"
                      type="number"
                      min="0"
                      step="0.01"
                      class="form-input text-xs"
                      placeholder="0,00"
                      @blur="
                        updateVinculoValores(
                          prof.id,
                          prof.salario_base,
                          prof.valor_dia,
                        )
                      "
                    />
                  </td>
                  <td class="py-2 pr-2 text-gray-600">
                    <input
                      v-model.number="prof.valor_dia"
                      type="number"
                      min="0"
                      step="0.01"
                      class="form-input text-xs"
                      placeholder="0,00"
                      @blur="
                        updateVinculoValores(
                          prof.id,
                          prof.salario_base,
                          prof.valor_dia,
                        )
                      "
                    />
                  </td>
                  <td class="py-2 pr-4 text-right">
                    <div class="flex flex-col items-end gap-1">
                      <div class="flex items-center gap-1">
                        <span
                          v-if="prof.is_admin"
                          class="inline-flex items-center rounded-full bg-primary-light text-primary-dark px-2 py-0.5 text-[10px] font-semibold"
                        >
                          Admin
                        </span>
                        <span
                          v-else
                          class="inline-flex items-center rounded-full bg-gray-100 text-gray-700 px-2 py-0.5 text-[10px] font-semibold"
                        >
                          Profissional
                        </span>
                        <span
                          class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-semibold"
                          :class="
                            prof.ativo
                              ? 'bg-green-50 text-green-700 border border-green-200'
                              : 'bg-gray-100 text-gray-600 border border-gray-200'
                          "
                        >
                          {{ prof.ativo ? 'Ativo' : 'Desativado' }}
                        </span>
                      </div>
                      <button
                        type="button"
                        class="text-[11px] text-primary-600 underline"
                        @click="setVinculoAtivo(prof.id, !prof.ativo)"
                      >
                        {{ prof.ativo ? 'Desativar vínculo' : 'Reativar vínculo' }}
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>

          </div>

          <div v-else>
            <h2 class="text-sm font-semibold text-primary-700 mb-4">
              Solicitações enviadas
            </h2>
            <div v-if="isLoadingSolicitacoes" class="text-xs text-gray-400">
              Carregando solicitações...
            </div>
            <div
              v-else-if="!solicitacoes.length"
              class="text-sm text-gray-500"
            >
              Nenhuma solicitação enviada até o momento.
            </div>
            <ul v-else class="divide-y divide-gray-100 text-sm">
              <li
                v-for="s in solicitacoes"
                :key="s.id"
                class="py-2 flex items-center justify-between gap-4"
              >
                <div>
                  <p class="text-gray-800">
                    {{ s.email_profissional }}
                  </p>
                  <p class="text-xs text-gray-500">
                    {{ s.profissao_nome || 'Profissão não informada' }}
                    <span v-if="s.especialidade_nome">
                      • {{ s.especialidade_nome }}
                    </span>
                  </p>
                </div>
                <div class="flex items-center gap-2 text-xs">
                  <span
                    class="inline-flex items-center rounded-full px-2 py-0.5 font-semibold"
                    :class="{
                      'bg-yellow-50 text-yellow-700 border border-yellow-200':
                        s.status === 'pendente',
                      'bg-green-50 text-green-700 border border-green-200':
                        s.status === 'aceito',
                      'bg-red-50 text-red-700 border border-red-200':
                        s.status === 'recusado' || s.status === 'cancelado',
                    }"
                  >
                    {{ s.status }}
                  </span>
                  <button
                    v-if="s.status === 'pendente'"
                    type="button"
                    class="text-primary-600 hover:underline"
                    @click="cancelSolicitacao(s.id)"
                  >
                    Cancelar
                  </button>
                  <button
                    v-if="s.status === 'pendente'"
                    type="button"
                    class="text-primary-600 hover:underline"
                    @click="resendSolicitacao(s)"
                  >
                    Reenviar
                  </button>
                  <button
                    v-else
                    type="button"
                    class="text-gray-500 hover:underline"
                    @click="deleteSolicitacao(s.id)"
                  >
                    Excluir
                  </button>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
