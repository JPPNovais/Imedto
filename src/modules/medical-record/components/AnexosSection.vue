<template>
  <div class="space-y-4">
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Adicionar arquivos
      </label>
      <input
        class="text-xs"
        type="file"
        multiple
        @change="onFilesSelected"
      />
      <p class="text-[11px] text-gray-500 mt-1">
        Limite de 2MB por arquivo. Arquivos de imagem exibem prévia; PDFs podem ser visualizados.
      </p>
    </div>

    <div v-if="!hasArquivos" class="text-[11px] text-gray-500">
      Nenhum arquivo adicionado até o momento.
    </div>

    <ul v-else class="space-y-3">
      <li
        v-for="(anexo, index) in anexos.arquivos"
        :key="`${anexo.nome}-${index}`"
        class="flex items-center justify-between gap-3 rounded-md border border-gray-200 bg-white p-3"
      >
        <div class="flex items-center gap-3 flex-1 min-w-0">
          <div
            class="h-12 w-12 flex items-center justify-center rounded-md border border-gray-200 overflow-hidden bg-gray-50"
          >
            <img
              v-if="anexo.tipo === 'imagem' && anexo.previewUrl"
              :src="anexo.previewUrl"
              alt="Pré-visualização do anexo"
              class="h-full w-full object-cover"
            />
            <button
              v-else-if="anexo.tipo === 'pdf' && anexo.previewUrl"
              class="text-[11px] text-primary-700 underline"
              type="button"
              @click="visualizarPdf(anexo)"
            >
              Abrir PDF
            </button>
            <i
              v-else
              class="fa-regular fa-file text-gray-400"
              aria-hidden="true"
            ></i>
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-xs font-semibold text-gray-700 truncate">
              {{ anexo.nome }}
            </p>
            <p class="text-[11px] text-gray-500">
              {{ formatarTamanho(anexo.tamanho) }}
            </p>
          </div>
        </div>
        <button
          class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
          type="button"
          @click="removerAnexo(index)"
        >
          <i class="fa-solid fa-trash" aria-hidden="true"></i>
        </button>
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount } from 'vue'
import { useFeedbackStore } from '@/stores/feedback'
import type { AnexoItem } from '../types'

const MAX_FILE_SIZE = 2 * 1024 * 1024

const props = defineProps<{
  anexos: {
    arquivos: AnexoItem[]
  }
}>()

const anexos = props.anexos
const feedback = useFeedbackStore()
const hasArquivos = computed(() => anexos.arquivos.length > 0)

function onFilesSelected(event: Event) {
  const input = event.target as HTMLInputElement | null
  const arquivosSelecionados = Array.from(input?.files ?? [])

  arquivosSelecionados.forEach((arquivo) => {
    if (arquivo.size > MAX_FILE_SIZE) {
      feedback.error(`"${arquivo.name}" excede o limite de 2MB.`)
      return
    }

    const tipoArquivo = definirTipoArquivo(arquivo.type)
    const previewUrl =
      tipoArquivo === 'imagem' || tipoArquivo === 'pdf'
        ? URL.createObjectURL(arquivo)
        : undefined

    anexos.arquivos.push({
      nome: arquivo.name,
      tamanho: arquivo.size,
      tipo: tipoArquivo,
      previewUrl,
    })
  })

  if (input) {
    input.value = ''
  }
}

function removerAnexo(index: number) {
  const [removido] = anexos.arquivos.splice(index, 1)
  if (removido?.previewUrl) {
    URL.revokeObjectURL(removido.previewUrl)
  }
}

function visualizarPdf(anexo: AnexoItem) {
  if (anexo.previewUrl) {
    window.open(anexo.previewUrl, '_blank', 'noopener,noreferrer')
  }
}

function definirTipoArquivo(mimeType: string): AnexoItem['tipo'] {
  if (mimeType.startsWith('image/')) {
    return 'imagem'
  }
  if (mimeType === 'application/pdf') {
    return 'pdf'
  }
  return 'outro'
}

function formatarTamanho(bytes: number) {
  if (!bytes) return '0 KB'
  return `${(bytes / 1024).toFixed(1)} KB`
}

onBeforeUnmount(() => {
  anexos.arquivos.forEach((anexo) => {
    if (anexo.previewUrl) {
      URL.revokeObjectURL(anexo.previewUrl)
    }
  })
})
</script>

