<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type ProdutoEstoque = {
  id: string
  nome: string
  descricao: string | null
  unidade: string | null
  quantidadeAtual: number
  quantidadeMinima: number | null
}

type MovimentoEstoque = {
  id: string
  tipo: 'entrada' | 'saida'
  quantidade: number
  motivo: string | null
  criadoEm: string
  produtoNome: string
}

const auth = useAuthStore()
const feedback = useFeedbackStore()

const estabelecimentoId = ref<string | null>(null)
const isLoading = ref(false)
const isSaving = ref(false)
const isSavingMovimento = ref(false)
const produtos = ref<ProdutoEstoque[]>([])
const movimentos = ref<MovimentoEstoque[]>([])
const filtroBuscar = ref('')
const filtroTipoMov = ref<'todos' | 'entrada' | 'saida'>('todos')
const filtroDataIni = ref('')
const filtroDataFim = ref('')

const activeTab = ref<'overview' | 'stock' | 'movements' | 'history'>(
  'overview',
)

const isModalAberto = ref(false)
const editandoProdutoId = ref<string | null>(null)

const formProduto = reactive({
  nome: '',
  descricao: '',
  unidade: '',
  quantidadeInicial: 0,
  quantidadeMinima: 0,
})

const movimentoForm = reactive({
  produtoId: '',
  tipo: 'saida' as 'entrada' | 'saida',
  quantidade: 1,
  motivo: '',
})

const produtosFiltrados = computed(() => {
  if (!filtroBuscar.value) return produtos.value
  const term = filtroBuscar.value.toLowerCase()
  return produtos.value.filter((p) =>
    p.nome.toLowerCase().includes(term),
  )
})

const lowStockProdutos = computed(() =>
  produtos.value.filter(
    (p) =>
      p.quantidadeMinima !== null &&
      p.quantidadeMinima !== undefined &&
      p.quantidadeAtual <= p.quantidadeMinima,
  ),
)

const totalProdutos = computed(() => produtos.value.length)
const totalItensEstoque = computed(() =>
  produtos.value.reduce((acc, p) => acc + (p.quantidadeAtual || 0), 0),
)

const movimentosFiltrados = computed(() => {
  let list = movimentos.value

  if (filtroTipoMov.value !== 'todos') {
    list = list.filter((m) => m.tipo === filtroTipoMov.value)
  }

  if (filtroDataIni.value) {
    const ini = new Date(filtroDataIni.value + 'T00:00:00').getTime()
    list = list.filter((m) => new Date(m.criadoEm).getTime() >= ini)
  }

  if (filtroDataFim.value) {
    const fim = new Date(filtroDataFim.value + 'T23:59:59').getTime()
    list = list.filter((m) => new Date(m.criadoEm).getTime() <= fim)
  }

  return list
})

async function loadEstabelecimento() {
  if (!auth.currentUser?.id) return

  // Primeiro tenta como owner
  const { data: estabOwner, error: ownerError } = await supabase
    .from('estabelecimentos')
    .select('id')
    .eq('owner_usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (!ownerError && estabOwner?.id) {
    estabelecimentoId.value = estabOwner.id
    return
  }

  // Se não for owner, tenta via vínculo profissional
  const { data: profissional } = await supabase
    .from('profissionais')
    .select('id')
    .eq('usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (!profissional?.id) return

  const { data: vinculo } = await supabase
    .from('vinculo_profissional_estabelecimento')
    .select('estabelecimento_id')
    .eq('profissional_id', profissional.id)
    .eq('ativo', true)
    .limit(1)
    .maybeSingle()

  estabelecimentoId.value = vinculo?.estabelecimento_id ?? null
}

async function loadProdutos() {
  if (!estabelecimentoId.value) return

  isLoading.value = true
  try {
    const { data, error } = await supabase
      .from('estoque_produto')
      .select(
        'id, nome, descricao, unidade, quantidade_atual, quantidade_minima',
      )
      .eq('estabelecimento_id', estabelecimentoId.value)
      .order('nome')

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar o estoque.')
      return
    }

    produtos.value =
      (data ?? []).map((p) => ({
        id: p.id as string,
        nome: p.nome as string,
        descricao: (p as { descricao?: string | null }).descricao ?? null,
        unidade: (p as { unidade?: string | null }).unidade ?? null,
        quantidadeAtual:
          (p as { quantidade_atual?: number | null }).quantidade_atual ?? 0,
        quantidadeMinima:
          (p as { quantidade_minima?: number | null }).quantidade_minima ??
          null,
      })) ?? []
  } finally {
    isLoading.value = false
  }
}

async function loadMovimentos() {
  if (!estabelecimentoId.value) return

  const { data, error } = await supabase
    .from('movimento_estoque')
    .select(
      `
      id,
      tipo,
      quantidade,
      motivo,
      created_at,
      produto:estoque_produto ( nome )
    `,
    )
    .eq('estabelecimento_id', estabelecimentoId.value)
    .order('created_at', { ascending: false })

  if (error) {
    console.error(error)
    return
  }

  movimentos.value =
    (data ?? []).map((m) => ({
      id: m.id as string,
      tipo: m.tipo as 'entrada' | 'saida',
      quantidade: m.quantidade as number,
      motivo: (m as { motivo?: string | null }).motivo ?? null,
      criadoEm: m.created_at as string,
      produtoNome: (m as { produto?: { nome?: string | null } }).produto
        ?.nome ?? 'Produto',
    })) ?? []
}

function abrirNovoProduto() {
  editandoProdutoId.value = null
  formProduto.nome = ''
  formProduto.descricao = ''
  formProduto.unidade = ''
  formProduto.quantidadeInicial = 0
  formProduto.quantidadeMinima = 0
  isModalAberto.value = true
}

function abrirEditarProduto(produto: ProdutoEstoque) {
  editandoProdutoId.value = produto.id
  formProduto.nome = produto.nome
  formProduto.descricao = produto.descricao ?? ''
  formProduto.unidade = produto.unidade ?? ''
  formProduto.quantidadeInicial = produto.quantidadeAtual
  formProduto.quantidadeMinima = produto.quantidadeMinima ?? 0
  isModalAberto.value = true
}

function fecharModal() {
  isModalAberto.value = false
}

async function salvarProduto() {
  if (!estabelecimentoId.value) return
  if (!formProduto.nome) {
    feedback.error('Informe o nome do produto.')
    return
  }

  isSaving.value = true

  try {
    const payload = {
      estabelecimento_id: estabelecimentoId.value,
      nome: formProduto.nome,
      descricao: formProduto.descricao || null,
      unidade: formProduto.unidade || null,
      quantidade_minima: formProduto.quantidadeMinima || 0,
    }

    let error

    if (editandoProdutoId.value) {
      // Atualiza dados básicos; quantidade pode ser ajustada pelo movimento
      const resp = await supabase
        .from('estoque_produto')
        .update({
          ...payload,
          quantidade_atual: formProduto.quantidadeInicial,
        })
        .eq('id', editandoProdutoId.value)

      error = resp.error
    } else {
      const resp = await supabase.from('estoque_produto').insert({
        ...payload,
        quantidade_atual: formProduto.quantidadeInicial || 0,
      })
      error = resp.error
    }

    if (error) {
      console.error(error)
      feedback.error('Não foi possível salvar o produto.')
      return
    }

    feedback.success('Produto salvo com sucesso.')
    isModalAberto.value = false
    await loadProdutos()
  } finally {
    isSaving.value = false
  }
}

async function deletarProduto(produto: ProdutoEstoque) {
  if (!window.confirm(`Deseja realmente remover o produto "${produto.nome}"?`))
    return

  const { error } = await supabase
    .from('estoque_produto')
    .delete()
    .eq('id', produto.id)

  if (error) {
    console.error(error)
    feedback.error('Não foi possível remover o produto.')
    return
  }

  feedback.success('Produto removido com sucesso.')
  await loadProdutos()
}

function abrirMovimento(produto: ProdutoEstoque, tipo: 'entrada' | 'saida') {
  movimentoForm.produtoId = produto.id
  movimentoForm.tipo = tipo
  movimentoForm.quantidade = 1
  movimentoForm.motivo = ''
}

async function salvarMovimento() {
  if (!estabelecimentoId.value || !movimentoForm.produtoId) return
  if (!movimentoForm.quantidade || movimentoForm.quantidade <= 0) {
    feedback.error('Informe a quantidade para registrar o movimento.')
    return
  }

  const produto = produtos.value.find(
    (p) => p.id === movimentoForm.produtoId,
  )
  if (!produto) return

  const delta =
    movimentoForm.tipo === 'entrada'
      ? movimentoForm.quantidade
      : -movimentoForm.quantidade

  const novaQuantidade = produto.quantidadeAtual + delta
  if (novaQuantidade < 0) {
    feedback.error('Quantidade insuficiente em estoque para esta saída.')
    return
  }

  isSavingMovimento.value = true

  try {
    const { error: movError } = await supabase
      .from('movimento_estoque')
      .insert({
        estabelecimento_id: estabelecimentoId.value,
        produto_id: produto.id,
        tipo: movimentoForm.tipo,
        quantidade: movimentoForm.quantidade,
        motivo: movimentoForm.motivo || null,
      })

    if (movError) {
      console.error(movError)
      feedback.error('Não foi possível registrar o movimento de estoque.')
      return
    }

    const { error: prodError } = await supabase
      .from('estoque_produto')
      .update({ quantidade_atual: novaQuantidade })
      .eq('id', produto.id)

    if (prodError) {
      console.error(prodError)
      feedback.error('Não foi possível atualizar a quantidade em estoque.')
      return
    }

    feedback.success('Movimento de estoque registrado com sucesso.')
    movimentoForm.produtoId = ''
    await loadProdutos()
    await loadMovimentos()
  } finally {
    isSavingMovimento.value = false
  }
}

onMounted(async () => {
  await loadEstabelecimento()
  if (!estabelecimentoId.value) return
  await loadProdutos()
  await loadMovimentos()
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6">
      <h1 class="text-2xl font-bold text-primary-700">
        Estoque
      </h1>
      <p class="text-sm text-gray-500">
        Cadastre e acompanhe os produtos utilizados na clínica ou consultório.
      </p>
    </header>

    <div
      v-if="!estabelecimentoId"
      class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 text-sm text-gray-600"
    >
      Não foi possível identificar um estabelecimento vinculado ao seu usuário
      para gerenciar o estoque.
    </div>

    <div
      v-else
      class="bg-white rounded-xl shadow-sm border border-gray-100 p-6 space-y-4"
    >
      <!-- Tabs -->
      <div class="flex flex-wrap gap-2 text-xs mb-2">
        <button
          class="px-3 py-1.5 rounded-full border"
          :class="
            activeTab === 'overview'
              ? 'bg-primary-50 border-primary-600 text-primary-700'
              : 'border-gray-200 text-gray-600 hover:bg-gray-50'
          "
          type="button"
          @click="activeTab = 'overview'"
        >
          Visão geral
        </button>
        <button
          class="px-3 py-1.5 rounded-full border"
          :class="
            activeTab === 'stock'
              ? 'bg-primary-50 border-primary-600 text-primary-700'
              : 'border-gray-200 text-gray-600 hover:bg-gray-50'
          "
          type="button"
          @click="activeTab = 'stock'"
        >
          Estoque
        </button>
        <button
          class="px-3 py-1.5 rounded-full border"
          :class="
            activeTab === 'movements'
              ? 'bg-primary-50 border-primary-600 text-primary-700'
              : 'border-gray-200 text-gray-600 hover:bg-gray-50'
          "
          type="button"
          @click="activeTab = 'movements'"
        >
          Movimentação
        </button>
        <button
          class="px-3 py-1.5 rounded-full border"
          :class="
            activeTab === 'history'
              ? 'bg-primary-50 border-primary-600 text-primary-700'
              : 'border-gray-200 text-gray-600 hover:bg-gray-50'
          "
          type="button"
          @click="activeTab = 'history'"
        >
          Histórico
        </button>
      </div>

      <!-- Overview -->
      <div v-if="activeTab === 'overview'" class="space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <div class="rounded-lg border border-gray-100 bg-gray-50 px-4 py-3">
            <p class="text-[11px] text-gray-500">
              Produtos cadastrados
            </p>
            <p class="mt-1 text-xl font-semibold text-primary-700">
              {{ totalProdutos }}
            </p>
          </div>
          <div class="rounded-lg border border-gray-100 bg-gray-50 px-4 py-3">
            <p class="text-[11px] text-gray-500">
              Itens em estoque
            </p>
            <p class="mt-1 text-xl font-semibold text-primary-700">
              {{ totalItensEstoque }}
            </p>
          </div>
          <div class="rounded-lg border border-gray-100 bg-gray-50 px-4 py-3">
            <p class="text-[11px] text-gray-500">
              Produtos abaixo do mínimo
            </p>
            <p class="mt-1 text-xl font-semibold" :class="lowStockProdutos.length ? 'text-red-600' : 'text-primary-700'">
              {{ lowStockProdutos.length }}
            </p>
          </div>
        </div>

        <div class="border border-gray-100 rounded-lg overflow-hidden">
          <div
            class="hidden md:grid grid-cols-[1.4fr,0.6fr,0.6fr,0.6fr,0.8fr] bg-gray-50 border-b border-gray-100 text-[11px] font-semibold text-gray-500 px-3 py-2"
          >
            <span>Produto</span>
            <span>Unidade</span>
            <span class="text-right">
              Qtde atual
            </span>
            <span class="text-right">
              Qtde mínima
            </span>
            <span class="text-right">
              Ações
            </span>
          </div>
          <ul class="divide-y divide-gray-100">
            <li
              v-for="produto in produtosFiltrados"
              :key="produto.id"
              class="px-3 py-2 text-xs md:text-sm flex flex-col md:grid md:grid-cols-[1.4fr,0.6fr,0.6fr,0.6fr,0.8fr] md:items-center gap-1 md:gap-3"
            >
              <div>
                <p class="font-medium text-gray-800">
                  {{ produto.nome }}
                </p>
                <p v-if="produto.descricao" class="text-[11px] text-gray-500">
                  {{ produto.descricao }}
                </p>
              </div>
              <div class="text-xs text-gray-700">
                {{ produto.unidade || '-' }}
              </div>
              <div
                class="text-xs font-semibold text-right"
                :class="[
                  produto.quantidadeMinima !== null &&
                  produto.quantidadeAtual <= produto.quantidadeMinima
                    ? 'text-red-600'
                    : 'text-gray-800',
                ]"
              >
                {{ produto.quantidadeAtual }}
              </div>
              <div class="text-xs text-right text-gray-500">
                {{ produto.quantidadeMinima ?? '-' }}
              </div>
              <div class="flex items-center justify-end gap-2">
                <button
                  class="text-[11px] text-primary-600 hover:text-primary-700 underline"
                  type="button"
                  @click="abrirMovimento(produto, 'saida'); activeTab = 'movements'"
                >
                  Registrar uso
                </button>
                <button
                  class="text-[11px] text-primary-600 hover:text-primary-700 underline"
                  type="button"
                  @click="abrirMovimento(produto, 'entrada'); activeTab = 'movements'"
                >
                  Entrada
                </button>
                <button
                  class="inline-flex items-center justify-center h-7 w-7 rounded-md border border-gray-200 text-gray-600 hover:bg-gray-50 hover:border-gray-300"
                  type="button"
                  @click="abrirEditarProduto(produto)"
                >
                  <i class="fa-solid fa-pen" aria-hidden="true"></i>
                </button>
                <button
                  class="inline-flex items-center justify-center h-7 w-7 rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                  type="button"
                  @click="deletarProduto(produto)"
                >
                  <i class="fa-solid fa-trash" aria-hidden="true"></i>
                </button>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <!-- Stock -->
      <div v-if="activeTab === 'stock'" class="space-y-4">
        <div class="flex flex-col md:flex-row md:items-center md:gap-3">
          <div class="flex-1">
            <input
              v-model="filtroBuscar"
              class="form-input text-xs w-full md:w-72"
              placeholder="Buscar por nome do produto"
              type="text"
            />
          </div>
          <div class="mt-2 md:mt-0 md:ml-3">
            <button
              class="btn-primary text-[11px] px-3 py-1.5"
              type="button"
              @click="abrirNovoProduto"
            >
              + Novo produto
            </button>
          </div>
        </div>

        <div v-if="isLoading" class="text-xs text-gray-400">
          Carregando estoque...
        </div>
        <div
          v-else-if="!produtosFiltrados.length"
          class="text-sm text-gray-500"
        >
          Nenhum produto cadastrado no estoque.
          <button
            class="ml-1 text-primary-600 underline text-xs"
            type="button"
            @click="abrirNovoProduto"
          >
            Cadastrar primeiro produto
          </button>
        </div>
        <div v-else class="border border-gray-100 rounded-lg overflow-hidden">
          <div
            class="hidden md:grid grid-cols-[1.4fr,0.6fr,0.6fr,0.6fr,0.8fr] bg-gray-50 border-b border-gray-100 text-[11px] font-semibold text-gray-500 px-3 py-2"
          >
            <span>Produto</span>
            <span>Unidade</span>
            <span class="text-right">
              Qtde atual
            </span>
            <span class="text-right">
              Qtde mínima
            </span>
            <span class="text-right">
              Ações
            </span>
          </div>
          <ul class="divide-y divide-gray-100">
            <li
              v-for="produto in produtosFiltrados"
              :key="produto.id"
              class="px-3 py-2 text-xs md:text-sm flex flex-col md:grid md:grid-cols-[1.4fr,0.6fr,0.6fr,0.6fr,0.8fr] md:items-center gap-1 md:gap-3"
            >
              <div>
                <p class="font-medium text-gray-800">
                  {{ produto.nome }}
                </p>
                <p v-if="produto.descricao" class="text-[11px] text-gray-500">
                  {{ produto.descricao }}
                </p>
              </div>
              <div class="text-xs text-gray-700">
                {{ produto.unidade || '-' }}
              </div>
              <div
                class="text-xs font-semibold text-right"
                :class="[
                  produto.quantidadeMinima !== null &&
                  produto.quantidadeAtual <= produto.quantidadeMinima
                    ? 'text-red-600'
                    : 'text-gray-800',
                ]"
              >
                {{ produto.quantidadeAtual }}
              </div>
              <div class="text-xs text-right text-gray-500">
                {{ produto.quantidadeMinima ?? '-' }}
              </div>
              <div class="flex items-center justify-end gap-2">
                <button
                  class="text-[11px] text-primary-600 hover:text-primary-700 underline"
                  type="button"
                  @click="abrirMovimento(produto, 'saida'); activeTab = 'movements'"
                >
                  Registrar uso
                </button>
                <button
                  class="text-[11px] text-primary-600 hover:text-primary-700 underline"
                  type="button"
                  @click="abrirMovimento(produto, 'entrada'); activeTab = 'movements'"
                >
                  Entrada
                </button>
                <button
                  class="inline-flex items-center justify-center h-7 w-7 rounded-md border border-gray-200 text-gray-600 hover:bg-gray-50 hover:border-gray-300"
                  type="button"
                  @click="abrirEditarProduto(produto)"
                >
                  <i class="fa-solid fa-pen" aria-hidden="true"></i>
                </button>
                <button
                  class="inline-flex items-center justify-center h-7 w-7 rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                  type="button"
                  @click="deletarProduto(produto)"
                >
                  <i class="fa-solid fa-trash" aria-hidden="true"></i>
                </button>
              </div>
            </li>
          </ul>
        </div>
      </div>

      <!-- Movements -->
      <div v-if="activeTab === 'movements'" class="space-y-4">
        <div class="flex flex-col md:flex-row md:items-end md:gap-3">
          <div class="flex-1">
            <label class="block text-[11px] font-semibold text-gray-700 mb-1">
              Produto
            </label>
            <select
              v-model="movimentoForm.produtoId"
              class="form-input text-xs w-full"
            >
              <option value="">
                Selecione um produto
              </option>
              <option
                v-for="produto in produtos"
                :key="produto.id"
                :value="produto.id"
              >
                {{ produto.nome }}
              </option>
            </select>
          </div>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-3 mt-3 md:mt-0 md:flex-1">
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Tipo
              </label>
              <select
                v-model="movimentoForm.tipo"
                class="form-input text-xs"
              >
                <option value="saida">
                  Saída (uso)
                </option>
                <option value="entrada">
                  Entrada
                </option>
              </select>
            </div>
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Quantidade
              </label>
              <input
                v-model.number="movimentoForm.quantidade"
                class="form-input text-xs"
                min="1"
                type="number"
              />
            </div>
            <div class="col-span-2 md:col-span-1">
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Motivo / Observação
              </label>
              <input
                v-model="movimentoForm.motivo"
                class="form-input text-xs"
                placeholder="Ex.: uso em procedimento, reposição de estoque..."
                type="text"
              />
            </div>
          </div>
          <div class="mt-3 md:mt-0">
            <button
              class="btn-primary text-xs py-2 px-4 disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSavingMovimento"
              type="button"
              @click="salvarMovimento"
            >
              {{ isSavingMovimento ? 'Salvando...' : 'Registrar movimento' }}
            </button>
          </div>
        </div>

        <div class="text-[11px] text-gray-500">
          Dica: use esta seção para registrar rapidamente o uso dos materiais e as entradas de reposição.
        </div>
      </div>

      <!-- History -->
      <div v-if="activeTab === 'history'" class="space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-3 text-[11px]">
          <div>
            <label class="block font-semibold text-gray-700 mb-1">
              Tipo
            </label>
            <select
              v-model="filtroTipoMov"
              class="form-input text-xs"
            >
              <option value="todos">
                Todos
              </option>
              <option value="entrada">
                Entradas
              </option>
              <option value="saida">
                Saídas
              </option>
            </select>
          </div>
          <div>
            <label class="block font-semibold text-gray-700 mb-1">
              Data inicial
            </label>
            <input
              v-model="filtroDataIni"
              class="form-input text-xs"
              type="date"
            />
          </div>
          <div>
            <label class="block font-semibold text-gray-700 mb-1">
              Data final
            </label>
            <input
              v-model="filtroDataFim"
              class="form-input text-xs"
              type="date"
            />
          </div>
        </div>

        <div class="border border-gray-100 rounded-lg overflow-hidden">
          <div
            class="hidden md:grid grid-cols-[0.9fr,0.9fr,0.8fr,0.6fr,1.2fr] bg-gray-50 border-b border-gray-100 text-[11px] font-semibold text-gray-500 px-3 py-2"
          >
            <span>Data</span>
            <span>Produto</span>
            <span>Tipo</span>
            <span class="text-right">
              Quantidade
            </span>
            <span>Motivo</span>
          </div>
          <ul class="divide-y divide-gray-100">
            <li
              v-for="mov in movimentosFiltrados"
              :key="mov.id"
              class="px-3 py-2 text-xs md:text-[13px] flex flex-col md:grid md:grid-cols-[0.9fr,0.9fr,0.8fr,0.6fr,1.2fr] md:items-center gap-1 md:gap-3"
            >
              <div class="text-gray-600">
                {{
                  new Date(mov.criadoEm).toLocaleString('pt-BR', {
                    dateStyle: 'short',
                    timeStyle: 'short',
                  })
                }}
              </div>
              <div class="font-medium text-gray-800">
                {{ mov.produtoNome }}
              </div>
              <div>
                <span
                  class="inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-medium"
                  :class="[
                    mov.tipo === 'entrada'
                      ? 'bg-green-50 text-green-700'
                      : 'bg-red-50 text-red-700',
                  ]"
                >
                  {{ mov.tipo === 'entrada' ? 'Entrada' : 'Saída' }}
                </span>
              </div>
              <div class="text-right font-semibold text-gray-800">
                {{ mov.quantidade }}
              </div>
              <div class="text-[11px] text-gray-600">
                {{ mov.motivo || '-' }}
              </div>
            </li>
            <li
              v-if="!movimentosFiltrados.length"
              class="px-3 py-3 text-xs text-gray-500"
            >
              Nenhuma movimentação encontrada para os filtros selecionados.
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Modal de produto -->
    <div
      v-if="isModalAberto"
      class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
    >
      <div class="w-full max-w-md bg-white rounded-2xl shadow-lg p-6">
        <h2 class="text-sm font-semibold text-primary-700 mb-4">
          {{ editandoProdutoId ? 'Editar produto' : 'Novo produto' }}
        </h2>
        <form class="space-y-4" @submit.prevent="salvarProduto">
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Nome do produto
            </label>
            <input
              v-model="formProduto.nome"
              class="form-input text-xs"
              placeholder="Ex.: Soro fisiológico 0,9%"
              type="text"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              Descrição
            </label>
            <textarea
              v-model="formProduto.descricao"
              class="form-input text-xs min-h-[64px] resize-y"
              placeholder="Informações adicionais sobre o produto"
            />
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3 md:items-end">
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Unidade
              </label>
              <select
                v-model="formProduto.unidade"
                class="form-input text-xs"
              >
                <option value="">
                  Selecione a unidade
                </option>
                <option value="unidade">
                  Unidade
                </option>
                <option value="caixa">
                  Caixa
                </option>
                <option value="ml">
                  mL
                </option>
                <option value="l">
                  Litro (L)
                </option>
                <option value="mg">
                  mg
                </option>
                <option value="g">
                  g
                </option>
                <option value="comprimido">
                  Comprimido
                </option>
                <option value="ampola">
                  Ampola
                </option>
                <option value="kit">
                  Kit
                </option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Quantidade em estoque
              </label>
              <input
                v-model.number="formProduto.quantidadeInicial"
                class="form-input text-xs"
                min="0"
                type="number"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Quantidade mínima
              </label>
              <input
                v-model.number="formProduto.quantidadeMinima"
                class="form-input text-xs"
                min="0"
                type="number"
              />
            </div>
          </div>
          <div class="flex justify-end gap-3 mt-4">
            <button
              class="text-xs text-gray-500 underline"
              type="button"
              @click="fecharModal"
            >
              Cancelar
            </button>
            <button
              class="btn-primary max-w-[140px] text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
              :disabled="isSaving"
              type="submit"
            >
              {{ isSaving ? 'Salvando...' : 'Salvar produto' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>
