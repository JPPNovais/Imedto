<template>
  <div class="space-y-4">
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Peso
        </label>
        <input
          v-model="exameFisico.peso"
          class="form-input text-xs"
          placeholder="Digite o peso em Kg"
          type="text"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Altura
        </label>
        <input
          v-model="exameFisico.altura"
          class="form-input text-xs"
          placeholder="Digite a altura em Metros"
          type="text"
        />
      </div>
      <div class="flex flex-col justify-end">
        <span class="block text-xs font-semibold text-gray-700 mb-1">
          IMC
        </span>
        <span class="text-sm font-semibold text-gray-800">
          {{ imcValor }}
        </span>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Ectoscopia
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="exameFisico.ectoscopia"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="exameFisico.ectoscopia"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
          />
          <span>Não</span>
        </label>
      </div>
      <input
        v-model="exameFisico.ectoscopiaComentario"
        class="form-input text-xs"
        placeholder="Comentário"
        type="text"
      />
    </div>

    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Ectoscopia
      </label>
      <textarea
        v-model="exameFisico.ectoscopiaDescricao"
        class="form-input text-xs min-h-[72px] resize-y"
        placeholder="Digite..."
      />
    </div>

    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Peso / Altura / IMC / Ectoscopia
      </label>
      <textarea
        v-model="exameFisico.resumoPesoAlturaImcEctoscopia"
        class="form-input text-xs min-h-[72px] resize-y"
        placeholder="Digite..."
      />
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  exameFisico: {
    peso: string
    altura: string
    ectoscopia: '' | 'sim' | 'nao'
    ectoscopiaComentario: string
    ectoscopiaDescricao: string
    resumoPesoAlturaImcEctoscopia: string
  }
  imcValor: string
}>()

const exameFisico = props.exameFisico
const imcValor = props.imcValor
</script>

