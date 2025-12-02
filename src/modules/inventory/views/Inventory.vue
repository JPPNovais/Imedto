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

const auth = useAuthStore()
const feedback = useFeedbackStore()

const estabelecimentoId = ref<string | null>(null)
const isLoading = ref(false)
const isSaving = ref(false)
const isSavingMovimento = ref(false)
const produtos = ref<ProdutoEstoque[]>([])
const filtroBuscar = ref('')

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
      data?.map((p: any) => ({
        id: p.id,
        nome: p.nome,
        descricao: p.descricao ?? null,
        unidade: p.unidade ?? null,
        quantidadeAtual: p.quantidade_atual ?? 0,
        quantidadeMinima: p.quantidade_minima ?? null,
      })) ?? []
  } finally {
    isLoading.value = false
  }
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

const produtoSelecionadoMovimento = computed(() =>
  produtos.value.find((p) => p.id === movimentoForm.produtoId) ?? null,
)

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
  } finally {
    isSavingMovimento.value = false
  }
}

onMounted(async () => {
  await loadEstabelecimento()
  if (!estabelecimentoId.value) return
  await loadProdutos()
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
      <div v-else-if="!produtosFiltrados.length" class="text-sm text-gray-500">
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
                @click="abrirMovimento(produto, 'saida')"
              >
                Registrar uso
              </button>
              <button
                class="text-[11px] text-primary-600 hover:text-primary-700 underline"
                type="button"
                @click="abrirMovimento(produto, 'entrada')"
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

      <div
        v-if="movimentoForm.produtoId && produtoSelecionadoMovimento"
        class="mt-4 border-t border-gray-100 pt-4"
      >
        <h3 class="text-xs font-semibold text-primary-700 mb-2">
          Registrar movimento de estoque
        </h3>
        <div class="text-[11px] text-gray-600 mb-2">
          Produto:
          <span class="font-semibold">
            {{ produtoSelecionadoMovimento.nome }}
          </span>
          · Quantidade atual:
          <span class="font-semibold">
            {{ produtoSelecionadoMovimento.quantidadeAtual }}
          </span>
        </div>
        <form
          class="grid grid-cols-1 md:grid-cols-[0.6fr,0.6fr,1.2fr,auto] gap-3 items-end"
          @submit.prevent="salvarMovimento"
        >
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
          <div>
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
          <button
            class="btn-primary text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
            :disabled="isSavingMovimento"
            type="submit"
          >
            {{ isSavingMovimento ? 'Salvando...' : 'Registrar' }}
          </button>
        </form>
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
