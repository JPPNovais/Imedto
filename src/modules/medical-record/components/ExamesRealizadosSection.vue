<template>
  <div class="space-y-4">
    <div
      v-for="(exame, index) in examesRealizados.exames"
      :key="index"
      class="bg-gray-50 rounded-lg p-3 border border-gray-100 space-y-3"
    >
      <div class="flex items-center justify-between mb-1">
        <p class="text-xs font-semibold text-gray-700">
          Exame {{ index + 1 }}
        </p>
        <button
          v-if="examesRealizados.exames.length > 1"
          type="button"
          class="h-8 px-2 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 text-[11px] hover:bg-red-50"
          @click="examesRealizados.exames.splice(index, 1)"
        >
          Remover
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Tipo de exame
          </label>
          <select
            v-model="exame.tipoExame"
            class="form-input text-xs"
          >
            <option value="">
              Tipo de exame
            </option>
            <option
              v-for="opt in tiposExame"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Material
          </label>
          <input
            v-model="exame.materialExame"
            class="form-input text-xs"
            placeholder="Ex.: Sangue, urina, tecido..."
            type="text"
          />
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Nome do exame
          </label>
          <input
            v-model="exame.nomeExame"
            class="form-input text-xs"
            placeholder="Ex.: Hemograma completo, RX tórax..."
            type="text"
          />
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Comentário
          </label>
          <input
            v-model="exame.comentarioExame"
            class="form-input text-xs"
            placeholder="Comentário"
            type="text"
          />
        </div>
      </div>

      <div class="space-y-3">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Anexos
          </label>
          <div class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center">
            <input
              class="form-input text-xs"
              type="file"
              accept="image/*,application/pdf"
              @change="(e) => onFileChange(exame, e)"
            />
            <input
              v-model="exame.novoAnexoObservacao"
              class="form-input text-xs"
              placeholder="Digite observação do arquivo"
              type="text"
            />
            <button
              class="h-9 w-9 inline-flex items-center justify-center rounded-md bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-100"
              type="button"
              @click="adicionarAnexo(exame)"
            >
              <i class="fa-solid fa-plus" aria-hidden="true"></i>
            </button>
          </div>
          <p class="mt-1 text-[11px] text-gray-500">
            Tamanho máximo do arquivo: 2MB. Formatos suportados: imagens e PDF.
          </p>
        </div>

        <div
          v-for="(anexo, idx) in exame.anexosImagem"
          :key="`${anexo.nome}-${idx}`"
          class="grid grid-cols-1 md:grid-cols-[auto,1.2fr,1.2fr,auto] gap-3 items-center"
        >
          <div class="flex items-center gap-2">
            <div
              v-if="anexo.tipo === 'imagem' && anexo.previewUrl"
              class="h-10 w-10 rounded overflow-hidden border border-gray-200 bg-white flex items-center justify-center"
            >
              <img
                :src="anexo.previewUrl"
                alt="Pré-visualização do exame"
                class="h-full w-full object-cover"
              />
            </div>
            <div
              v-else-if="anexo.tipo === 'pdf' && anexo.previewUrl"
              class="flex items-center"
            >
              <a
                :href="anexo.previewUrl"
                target="_blank"
                rel="noopener noreferrer"
                class="text-[11px] text-primary-700 underline"
              >
                Abrir PDF
              </a>
            </div>
            <div v-else class="h-10 w-10 flex items-center justify-center">
              <i class="fa-regular fa-file text-gray-400" aria-hidden="true"></i>
            </div>
            <span class="text-[11px] text-gray-600 truncate max-w-[160px]">
              {{ anexo.nome }}
            </span>
          </div>
          <input
            v-model="anexo.observacao"
            class="form-input text-xs"
            placeholder="Observação do arquivo"
            type="text"
          />
          <div class="text-[11px] text-gray-500 truncate">
            {{ anexo.tipo === 'imagem' ? 'Imagem' : anexo.tipo === 'pdf' ? 'PDF' : 'Arquivo' }}
          </div>
          <button
            class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
            type="button"
            @click="exame.anexosImagem.splice(idx, 1)"
          >
            <i class="fa-solid fa-trash" aria-hidden="true"></i>
          </button>
        </div>
      </div>
    </div>

    <button
      class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
      type="button"
      @click="adicionarExame"
    >
      <span class="text-base leading-none">+</span>
      <span>Adicionar outro exame</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { useFeedbackStore } from '@/stores/feedback'

type ExameAnexo = {
  nome: string
  observacao: string
  file?: File | null
  previewUrl?: string
  tipo?: 'imagem' | 'pdf' | 'outro'
}

type ExameItem = {
  tipoExame: string
  materialExame: string
  nomeExame: string
  comentarioExame: string
  anexosImagem: ExameAnexo[]
  novoAnexoArquivo: File | null
  novoAnexoObservacao: string
}

const props = defineProps<{
  examesRealizados: {
    exames: ExameItem[]
  }
}>()

const feedback = useFeedbackStore()
const examesRealizados = props.examesRealizados

const tiposExame = [
  { value: 'laboratorial', label: 'Laboratorial' },
  { value: 'imagem', label: 'Imagem' },
  { value: 'funcional', label: 'Funcional' },
  { value: 'endoscopico', label: 'Endoscópico' },
  { value: 'outro', label: 'Outro' },
]

function onFileChange(exame: ExameItem, event: Event) {
  const input = event.target as HTMLInputElement | null
  const file = input?.files && input.files[0] ? input.files[0] : null
  if (!file) return

  if (file.size > 2 * 1024 * 1024) {
    feedback.error('O arquivo deve ter no máximo 2MB.')
    if (input) input.value = ''
    return
  }

  exame.novoAnexoArquivo = file
}

function adicionarAnexo(exame: ExameItem) {
  const file = exame.novoAnexoArquivo
  if (!file) return

  let tipo: ExameAnexo['tipo'] = 'outro'
  if (file.type.startsWith('image/')) {
    tipo = 'imagem'
  } else if (file.type === 'application/pdf') {
    tipo = 'pdf'
  }

  const previewUrl =
    tipo === 'imagem' || tipo === 'pdf'
      ? URL.createObjectURL(file)
      : undefined

  exame.anexosImagem.push({
    nome: file.name,
    observacao: exame.novoAnexoObservacao,
    file,
    previewUrl,
    tipo,
  })

  exame.novoAnexoArquivo = null
  exame.novoAnexoObservacao = ''
}

function adicionarExame() {
  examesRealizados.exames.push({
    tipoExame: '',
    materialExame: '',
    nomeExame: '',
    comentarioExame: '',
    anexosImagem: [],
    novoAnexoArquivo: null,
    novoAnexoObservacao: '',
  })
}
</script>

