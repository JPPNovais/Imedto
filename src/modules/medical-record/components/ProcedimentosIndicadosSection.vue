<template>
  <div class="space-y-3">
    <div
      v-for="(proc, index) in procedimentosIndicados.itens"
      :key="index"
      class="grid grid-cols-1 md:grid-cols-[1.4fr,auto] gap-2 items-center"
    >
      <select
        :value="proc"
        class="form-input text-xs"
        @change="(e) => onProcedimentoSelectChange(e, index)"
      >
        <option value="">
          Selecione o procedimento indicado
        </option>
        <option
          v-for="nome in procedimentosIndicadosPool"
          :key="nome"
          :value="nome"
        >
          {{ nome }}
        </option>
        <option value="__outra__">
          Outro (cadastrar novo...)
        </option>
      </select>
      <button
        v-if="procedimentosIndicados.itens.length > 1"
        class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
        type="button"
        @click="procedimentosIndicados.itens.splice(index, 1)"
      >
        <i class="fa-solid fa-trash" aria-hidden="true"></i>
      </button>
    </div>
    <button
      class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
      type="button"
      @click="procedimentosIndicados.itens.push('')"
    >
      <span class="text-base leading-none">+</span>
      <span>Adicionar outro procedimento</span>
    </button>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  procedimentosIndicados: {
    itens: string[]
  }
  procedimentosIndicadosPool: string[]
  onProcedimentoSelectChange: (event: Event, index: number) => void
}>()

const procedimentosIndicados = props.procedimentosIndicados
const procedimentosIndicadosPool = props.procedimentosIndicadosPool
const onProcedimentoSelectChange = props.onProcedimentoSelectChange
</script>

