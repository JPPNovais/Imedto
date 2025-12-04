<template>
  <div class="space-y-4">
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Histórico da queixa
      </label>
      <textarea
        v-model="historiaAtual.historicoQueixa"
        class="form-input text-xs min-h-[120px] resize-y"
        placeholder="Descreva a evolução da queixa, fatores relacionados, tentativas prévias..."
      />
    </div>
    <div>
      <div class="flex items-center justify-between mb-2">
        <label class="block text-xs font-semibold text-gray-700">
          Procedimentos desejados / Expectativas do paciente
        </label>
        <span class="text-[11px] text-gray-400">
          Use um atalho do cadastro ou descreva manualmente
        </span>
      </div>
      <div class="space-y-3">
        <div
          v-for="(procedimento, index) in historiaAtual.procedimentos"
          :key="index"
        >
          <select
            class="form-input text-xs"
            :value="
              expectativasPool.includes(procedimento) ? procedimento : ''
            "
            @change="(event) => onProcedimentoSelectChange?.(event, index)"
          >
            <option value="">
              Selecione uma expectativa cadastrada
            </option>
            <option
              v-for="expectativa in expectativasPool"
              :key="expectativa"
              :value="expectativa"
            >
              {{ expectativa }}
            </option>
            <option value="__nova__">
              Cadastrar nova expectativa
            </option>
          </select>
        </div>
        <button
          class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
          type="button"
          @click="historiaAtual.procedimentos.push('')"
        >
          <span class="text-base leading-none">+</span>
          <span>Adicionar outro procedimento</span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  historiaAtual: {
    historicoQueixa: string
    procedimentos: string[]
  }
  expectativasPool: string[]
  onProcedimentoSelectChange?: (event: Event, index: number) => void
}>()

const historiaAtual = props.historiaAtual
const expectativasPool = props.expectativasPool
const onProcedimentoSelectChange = props.onProcedimentoSelectChange
</script>
