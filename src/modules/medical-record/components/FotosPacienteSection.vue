<template>
  <div class="space-y-3">
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Anexo de imagem
      </label>
      <div class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center">
        <input
          class="form-input text-xs"
          type="file"
          accept="image/*"
          @change="onFileChange"
        />
        <input
          v-model="fotosPaciente.novaObservacao"
          class="form-input text-xs"
          placeholder="Digite observação do arquivo"
          type="text"
        />
        <button
          class="h-9 w-9 inline-flex items-center justify-center rounded-md bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-100"
          type="button"
          @click="adicionarAnexo"
        >
          <i class="fa-solid fa-plus" aria-hidden="true"></i>
        </button>
      </div>
    </div>

    <div
      v-for="(anexo, index) in fotosPaciente.anexos"
      :key="`${anexo.nome}-${index}`"
      class="grid grid-cols-1 md:grid-cols-[auto,1.4fr,auto] gap-3 items-center"
    >
      <div class="flex items-center gap-2">
        <div
          v-if="anexo.previewUrl"
          class="h-10 w-10 rounded overflow-hidden border border-gray-200 bg-white flex items-center justify-center"
        >
          <img
            :src="anexo.previewUrl"
            alt="Pré-visualização da foto"
            class="h-full w-full object-cover"
          />
        </div>
        <div
          v-else
          class="h-10 w-10 flex items-center justify-center"
        >
          <i class="fa-regular fa-image text-gray-400" aria-hidden="true"></i>
        </div>
        <div class="form-input text-xs flex-1 flex items-center bg-gray-50">
          <span class="text-gray-500 truncate">
            {{ anexo.nome }}
          </span>
        </div>
      </div>
      <input
        v-model="anexo.observacao"
        class="form-input text-xs"
        placeholder="Digite observação do arquivo"
        type="text"
      />
      <button
        class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
        type="button"
        @click="fotosPaciente.anexos.splice(index, 1)"
      >
        <i class="fa-solid fa-trash" aria-hidden="true"></i>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useFeedbackStore } from '@/stores/feedback'

const props = defineProps<{
  fotosPaciente: {
    anexos: { nome: string; observacao: string; previewUrl?: string }[]
    novoArquivo: File | null
    novaObservacao: string
  }
}>()

const fotosPaciente = props.fotosPaciente
const feedback = useFeedbackStore()

function onFileChange(e: Event) {
  const input = e.target as HTMLInputElement | null
  const file = input?.files && input.files[0] ? input.files[0] : null
  if (!file) {
    fotosPaciente.novoArquivo = null
    return
  }

  if (file.size > 2 * 1024 * 1024) {
    feedback.error('A imagem deve ter no máximo 2MB.')
    if (input) input.value = ''
    fotosPaciente.novoArquivo = null
    return
  }

  fotosPaciente.novoArquivo = file
}

function adicionarAnexo() {
  if (!fotosPaciente.novoArquivo) return

  const previewUrl = URL.createObjectURL(fotosPaciente.novoArquivo)

  fotosPaciente.anexos.push({
    nome: fotosPaciente.novoArquivo.name,
    observacao: fotosPaciente.novaObservacao,
    previewUrl,
  })
  fotosPaciente.novoArquivo = null
  fotosPaciente.novaObservacao = ''
}
</script>
