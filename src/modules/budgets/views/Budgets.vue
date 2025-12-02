<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type PacienteOption = {
  id: string
  nome: string
}

type OrcamentoResumo = {
  id: string
  titulo: string | null
  criadoEm: string
  status: string
  valorTotal: number
}

type ProcedimentoOption = {
  id: string
  nome: string
  tipoCirurgia: string | null
  duracaoMinutos: number | null
  valorSugerido: number | null
}

type OrcamentoItemForm = {
  id?: string
  procedimentoId?: string | null
  descricao: string
  quantidade: number
  valorUnitario: number
  tipoCirurgia: string
  tempoMinutos: number
}

type OrcamentoItemDb = {
  id: string
  procedimento_id: string | null
  descricao: string | null
  quantidade: number | null
  valor_unitario: number | null
  tipo_cirurgia: string | null
  tempo_previsto_minutos: number | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()
const route = useRoute()

const estabelecimentoId = ref<string | null>(null)
const profissionalId = ref<string | null>(null)
const pacientes = ref<PacienteOption[]>([])
const orcamentos = ref<OrcamentoResumo[]>([])
const procedimentos = ref<ProcedimentoOption[]>([])
const isLoading = ref(false)
const isSaving = ref(false)

const pacienteSelecionadoId = ref<string>('')
const orcamentoSelecionadoId = ref<string | null>(null)

const formOrcamento = reactive({
  titulo: '',
  validade: '',
  observacoes: '',
  status: 'rascunho' as 'rascunho' | 'enviado' | 'aprovado' | 'recusado' | 'cancelado' | 'expirado',
  itens: [] as OrcamentoItemForm[],
})

const totalOrcamento = computed(() =>
  formOrcamento.itens.reduce(
    (acc, item) => acc + (item.quantidade || 0) * (item.valorUnitario || 0),
    0,
  ),
)

const podeEditar = computed(() => !!pacienteSelecionadoId.value)

async function loadEstabelecimentoEProfissional() {
  if (!auth.currentUser?.id) return

  const { data: estabOwner } = await supabase
    .from('estabelecimentos')
    .select('id')
    .eq('owner_usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (estabOwner?.id) {
    estabelecimentoId.value = estabOwner.id
  } else {
    const { data: profissional } = await supabase
      .from('profissionais')
      .select('id')
      .eq('usuario_id', auth.currentUser.id)
      .limit(1)
      .maybeSingle()

    if (profissional?.id) {
      profissionalId.value = profissional.id

      const { data: vinculo } = await supabase
        .from('vinculo_profissional_estabelecimento')
        .select('estabelecimento_id')
        .eq('profissional_id', profissional.id)
        .eq('ativo', true)
        .limit(1)
        .maybeSingle()

      estabelecimentoId.value = vinculo?.estabelecimento_id ?? null
    }
  }
}

async function loadPacientes() {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('pacientes')
    .select('id, nome_completo')
    .eq('estabelecimento_id', estabelecimentoId.value)
    .order('nome_completo')

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar os pacientes.')
    return
  }

  pacientes.value =
    data?.map((p) => ({
      id: p.id as string,
      nome: (p as { nome_completo?: string | null }).nome_completo ?? 'Paciente',
    })) ?? []
}

async function loadProcedimentos() {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('procedimento_cirurgico')
    .select('id, nome, tipo_cirurgia, duracao_minutos, valor_sugerido')
    .eq('estabelecimento_id', estabelecimentoId.value)
    .order('nome')

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar os procedimentos cirúrgicos.')
    return
  }

  procedimentos.value =
    data?.map((p) => ({
      id: p.id as string,
      nome: p.nome as string,
      tipoCirurgia:
        (p as { tipo_cirurgia?: string | null }).tipo_cirurgia ?? null,
      duracaoMinutos:
        (p as { duracao_minutos?: number | null }).duracao_minutos ?? null,
      valorSugerido:
        (p as { valor_sugerido?: number | null }).valor_sugerido ?? null,
    })) ?? []
}

async function loadOrcamentos() {
  if (!estabelecimentoId.value || !pacienteSelecionadoId.value) {
    orcamentos.value = []
    return
  }

  isLoading.value = true
  try {
    const { data, error } = await supabase
      .from('orcamentos')
      .select('id, titulo, status, valor_total, created_at')
      .eq('estabelecimento_id', estabelecimentoId.value)
      .eq('paciente_id', pacienteSelecionadoId.value)
      .order('created_at', { ascending: false })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar os orçamentos do paciente.')
      return
    }

    orcamentos.value =
      data?.map((o) => ({
        id: o.id as string,
        titulo: (o as { titulo?: string | null }).titulo ?? null,
        status: (o as { status?: string }).status ?? 'rascunho',
        valorTotal: (o as { valor_total?: number | null }).valor_total ?? 0,
        criadoEm: o.created_at as string,
      })) ?? []
  } finally {
    isLoading.value = false
  }
}

async function loadOrcamentoDetalhe(id: string) {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('orcamentos')
    .select(
      `
      id,
      titulo,
      observacoes,
      status,
      validade,
      valor_total,
      itens:orcamento_itens (
        id,
        procedimento_id,
        descricao,
        quantidade,
        valor_unitario,
        tipo_cirurgia,
        tempo_previsto_minutos
      )
    `,
    )
    .eq('id', id)
    .eq('estabelecimento_id', estabelecimentoId.value)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar o orçamento selecionado.')
    return
  }

  if (!data) return

  orcamentoSelecionadoId.value = data.id as string
  formOrcamento.titulo = (data as { titulo?: string | null }).titulo ?? ''
  formOrcamento.validade = (data as { validade?: string | null }).validade ?? ''
  formOrcamento.observacoes =
    (data as { observacoes?: string | null }).observacoes ?? ''
  formOrcamento.status =
    ((data as { status?: string }).status as typeof formOrcamento.status) ??
    'rascunho'

  formOrcamento.itens =
    (data as { itens?: OrcamentoItemDb[] }).itens?.map((i: OrcamentoItemDb) => ({
      id: i.id as string,
      procedimentoId: i.procedimento_id,
      descricao: i.descricao ?? '',
      quantidade: i.quantidade ?? 1,
      valorUnitario: i.valor_unitario ?? 0,
      tipoCirurgia: i.tipo_cirurgia ?? '',
      tempoMinutos: i.tempo_previsto_minutos ?? 0,
    })) ?? []
}

function novoOrcamento() {
  orcamentoSelecionadoId.value = null
  formOrcamento.titulo = ''
  formOrcamento.validade = ''
  formOrcamento.observacoes = ''
  formOrcamento.status = 'rascunho'
  formOrcamento.itens = [
    {
      procedimentoId: null,
      descricao: '',
      quantidade: 1,
      valorUnitario: 0,
      tipoCirurgia: '',
      tempoMinutos: 0,
    },
  ]
}

function adicionarItem() {
  formOrcamento.itens.push({
    procedimentoId: null,
    descricao: '',
    quantidade: 1,
    valorUnitario: 0,
    tipoCirurgia: '',
    tempoMinutos: 0,
  })
}

function removerItem(index: number) {
  if (formOrcamento.itens.length === 1) return
  formOrcamento.itens.splice(index, 1)
}

async function salvarOrcamento() {
  if (!estabelecimentoId.value || !pacienteSelecionadoId.value) {
    feedback.error('Selecione um paciente para salvar o orçamento.')
    return
  }

  if (!formOrcamento.itens.length) {
    feedback.error('Adicione ao menos um item ao orçamento.')
    return
  }

  const itensValidos = formOrcamento.itens.filter(
    (i) => i.descricao && i.quantidade > 0,
  )

  if (!itensValidos.length) {
    feedback.error('Preencha descrição e quantidade dos itens.')
    return
  }

  isSaving.value = true

  try {
    const valorTotal = totalOrcamento.value

    let orcamentoId = orcamentoSelecionadoId.value

    if (!orcamentoId) {
      const { data, error } = await supabase
        .from('orcamentos')
        .insert({
          estabelecimento_id: estabelecimentoId.value,
          paciente_id: pacienteSelecionadoId.value,
          profissional_id: profissionalId.value || null,
          titulo: formOrcamento.titulo || null,
          observacoes: formOrcamento.observacoes || null,
          status: formOrcamento.status,
          validade: formOrcamento.validade || null,
          valor_total: valorTotal,
        })
        .select('id')
        .maybeSingle()

      if (error || !data?.id) {
        console.error(error)
        feedback.error('Não foi possível criar o orçamento.')
        return
      }

      orcamentoId = data.id as string
      orcamentoSelecionadoId.value = orcamentoId
    } else {
      const { error } = await supabase
        .from('orcamentos')
        .update({
          titulo: formOrcamento.titulo || null,
          observacoes: formOrcamento.observacoes || null,
          status: formOrcamento.status,
          validade: formOrcamento.validade || null,
          valor_total: valorTotal,
        })
        .eq('id', orcamentoId)
        .eq('estabelecimento_id', estabelecimentoId.value)

      if (error) {
        console.error(error)
        feedback.error('Não foi possível atualizar o orçamento.')
        return
      }

      // Remove itens antigos e recria para simplificar
      await supabase
        .from('orcamento_itens')
        .delete()
        .eq('orcamento_id', orcamentoId)
    }

    if (!orcamentoId) return

    if (itensValidos.length) {
      const itensPayload = itensValidos.map((i) => ({
        orcamento_id: orcamentoId,
        descricao: i.descricao,
        quantidade: i.quantidade,
        valor_unitario: i.valorUnitario,
        valor_total: i.quantidade * i.valorUnitario,
      }))

      const { error: itensError } = await supabase
        .from('orcamento_itens')
        .insert(itensPayload)

      if (itensError) {
        console.error(itensError)
        feedback.error('Não foi possível salvar os itens do orçamento.')
        return
      }
    }

    feedback.success('Orçamento salvo com sucesso.')
    await loadOrcamentos()
  } finally {
    isSaving.value = false
  }
}

async function deletarOrcamento(orcamentoId: string) {
  if (
    !window.confirm(
      'Deseja realmente excluir este orçamento? Essa ação não pode ser desfeita.',
    )
  ) {
    return
  }

  const { error } = await supabase
    .from('orcamentos')
    .delete()
    .eq('id', orcamentoId)
    .eq('estabelecimento_id', estabelecimentoId.value)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível excluir o orçamento.')
    return
  }

  if (orcamentoSelecionadoId.value === orcamentoId) {
    orcamentoSelecionadoId.value = null
    formOrcamento.titulo = ''
    formOrcamento.validade = ''
    formOrcamento.observacoes = ''
    formOrcamento.status = 'rascunho'
    formOrcamento.itens = []
  }

  feedback.success('Orçamento excluído com sucesso.')
  await loadOrcamentos()
}

watch(pacienteSelecionadoId, () => {
  novoOrcamento()
  loadOrcamentos()
})

onMounted(async () => {
  isLoading.value = true
  try {
    await loadEstabelecimentoEProfissional()
    if (!estabelecimentoId.value) return
    await loadPacientes()
     await loadProcedimentos()

    const qpId = route.query.pacienteId
    if (typeof qpId === 'string') {
      pacienteSelecionadoId.value = qpId
    }

    if (pacienteSelecionadoId.value) {
      await loadOrcamentos()
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
          Orçamentos
        </h1>
        <p class="text-sm text-gray-500">
          Gere e acompanhe orçamentos cirúrgicos por paciente e estabelecimento.
        </p>
      </div>
    </header>

    <div v-if="isLoading" class="text-xs text-gray-400">
      Carregando dados...
    </div>

    <div
      v-else-if="!estabelecimentoId"
      class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 text-sm text-gray-600"
    >
      Não foi possível identificar um estabelecimento vinculado ao seu usuário
      para gerenciar orçamentos.
    </div>

    <div
      v-else
      class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 flex flex-col md:flex-row gap-6"
    >
      <!-- Coluna esquerda: seleção de paciente e lista de orçamentos -->
      <div class="md:w-1/3 space-y-4">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Paciente
          </label>
          <select
            v-model="pacienteSelecionadoId"
            class="form-input text-xs w-full"
          >
            <option value="">
              Selecione um paciente
            </option>
            <option
              v-for="p in pacientes"
              :key="p.id"
              :value="p.id"
            >
              {{ p.nome }}
            </option>
          </select>
        </div>

        <div class="flex items-center justify-between text-[11px] text-gray-700">
          <span class="font-semibold">
            Orçamentos do paciente
          </span>
          <button
            class="text-primary-600 hover:text-primary-700 underline disabled:text-gray-400 disabled:no-underline"
            type="button"
            :disabled="!pacienteSelecionadoId"
            @click="novoOrcamento"
          >
            + Novo orçamento
          </button>
        </div>

        <div
          v-if="!pacienteSelecionadoId"
          class="text-[11px] text-gray-500"
        >
          Selecione um paciente para visualizar ou criar orçamentos.
        </div>

        <ul
          v-else-if="orcamentos.length"
          class="space-y-2 text-xs"
        >
          <li
            v-for="orc in orcamentos"
            :key="orc.id"
          >
            <button
              class="w-full text-left rounded-lg border px-3 py-2 hover:bg-gray-50"
              :class="
                orcamentoSelecionadoId === orc.id
                  ? 'border-primary-600 bg-primary-50'
                  : 'border-gray-100'
              "
              type="button"
              @click="loadOrcamentoDetalhe(orc.id)"
            >
              <div class="flex items-center justify-between gap-2">
                <p class="font-semibold text-gray-800 truncate">
                  {{ orc.titulo || 'Orçamento sem título' }}
                </p>
                <span
                  class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium"
                  :class="[
                    orc.status === 'aprovado'
                      ? 'bg-green-50 text-green-700'
                      : orc.status === 'recusado'
                        ? 'bg-red-50 text-red-700'
                        : orc.status === 'enviado'
                          ? 'bg-blue-50 text-blue-700'
                          : 'bg-gray-50 text-gray-700',
                  ]"
                >
                  {{ orc.status }}
                </span>
              </div>
              <div class="mt-1 flex items-center justify-between text-[11px] text-gray-500">
                <span>
                  {{
                    new Date(orc.criadoEm).toLocaleDateString('pt-BR', {
                      dateStyle: 'short',
                    })
                  }}
                </span>
                <span class="font-semibold text-primary-700">
                  {{ orc.valorTotal.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }) }}
                </span>
              </div>
            </button>
          </li>
        </ul>
        <div
          v-else-if="pacienteSelecionadoId"
          class="text-[11px] text-gray-500"
        >
          Nenhum orçamento cadastrado para este paciente.
        </div>
      </div>

      <!-- Coluna direita: formulário do orçamento -->
      <div class="md:flex-1">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-primary-700">
            Detalhes do orçamento
          </h2>
          <span
            v-if="!pacienteSelecionadoId"
            class="text-[11px] text-gray-400"
          >
            Selecione um paciente para começar.
          </span>
        </div>

        <form
          class="space-y-4"
          @submit.prevent="salvarOrcamento"
        >
          <div class="grid grid-cols-1 md:grid-cols-[1.4fr,0.6fr] gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Título do orçamento
              </label>
              <input
                v-model="formOrcamento.titulo"
                class="form-input text-xs"
                placeholder="Ex.: Ritidoplastia + Blefaroplastia"
                :disabled="!podeEditar"
                type="text"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Validade
              </label>
              <input
                v-model="formOrcamento.validade"
                class="form-input text-xs"
                :disabled="!podeEditar"
                type="date"
              />
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-[0.8fr,0.8fr] gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Status
              </label>
              <select
                v-model="formOrcamento.status"
                class="form-input text-xs"
                :disabled="!podeEditar"
              >
                <option value="rascunho">
                  Rascunho
                </option>
                <option value="enviado">
                  Enviado ao paciente
                </option>
                <option value="aprovado">
                  Aprovado
                </option>
                <option value="recusado">
                  Recusado
                </option>
                <option value="cancelado">
                  Cancelado
                </option>
                <option value="expirado">
                  Expirado
                </option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Valor total
              </label>
              <div class="text-sm font-semibold text-primary-700 mt-2">
                {{
                  totalOrcamento.toLocaleString('pt-BR', {
                    style: 'currency',
                    currency: 'BRL',
                  })
                }}
              </div>
            </div>
          </div>

          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Itens do orçamento
            </label>
            <div class="space-y-2">
              <div
                v-for="(item, index) in formOrcamento.itens"
                :key="index"
                class="grid grid-cols-1 md:grid-cols-[1.4fr,0.4fr,0.6fr,auto] gap-2 items-end"
              >
                <div>
                  <input
                    v-model="item.descricao"
                    class="form-input text-xs"
                    placeholder="Descrição do procedimento / material"
                    :disabled="!podeEditar"
                    type="text"
                  />
                </div>
                <div>
                  <label class="block text-[11px] font-semibold text-gray-700 mb-0.5">
                    Qtde
                  </label>
                  <input
                    v-model.number="item.quantidade"
                    class="form-input text-xs"
                    min="1"
                    :disabled="!podeEditar"
                    type="number"
                  />
                </div>
                <div>
                  <label class="block text-[11px] font-semibold text-gray-700 mb-0.5">
                    Valor unitário
                  </label>
                  <input
                    v-model.number="item.valorUnitario"
                    class="form-input text-xs"
                    min="0"
                    step="0.01"
                    :disabled="!podeEditar"
                    type="number"
                  />
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-[11px] text-gray-600">
                    {{
                      (item.quantidade * item.valorUnitario || 0).toLocaleString(
                        'pt-BR',
                        { style: 'currency', currency: 'BRL' },
                      )
                    }}
                  </span>
                  <button
                    class="h-7 w-7 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                    type="button"
                    :disabled="!podeEditar"
                    @click="removerItem(index)"
                  >
                    <i class="fa-solid fa-trash" aria-hidden="true"></i>
                  </button>
                </div>
              </div>
              <button
                class="inline-flex items-center gap-1 text-[11px] text-primary-700 font-semibold hover:underline"
                type="button"
                :disabled="!podeEditar"
                @click="adicionarItem"
              >
                <span class="text-base leading-none">+</span>
                <span>Adicionar item</span>
              </button>
            </div>
          </div>

          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Observações
            </label>
            <textarea
              v-model="formOrcamento.observacoes"
              class="form-input text-xs min-h-[80px] resize-y"
              placeholder="Informações complementares para o paciente sobre o orçamento"
              :disabled="!podeEditar"
            />
          </div>

          <div class="mt-4 flex items-center justify-between">
            <button
              v-if="orcamentoSelecionadoId"
              class="text-[11px] text-red-600 hover:underline"
              type="button"
              @click="deletarOrcamento(orcamentoSelecionadoId)"
            >
              Excluir orçamento
            </button>
            <div class="flex-1" />
            <button
              class="btn-primary max-w-[160px] text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSaving || !podeEditar"
              type="submit"
            >
              {{ isSaving ? 'Salvando...' : 'Salvar orçamento' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>
