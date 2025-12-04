<template>
  <div class="space-y-4">
    <div>
      <textarea
        v-model="evolucaoPosOperatoria.observacao"
        class="form-input text-xs min-h-[120px] resize-y"
        placeholder="Digite a observação"
      />
    </div>

    <div class="grid grid-cols-1 md:grid-cols-[1.4fr,1.2fr] gap-3 items-center">
      <div class="flex flex-wrap items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Como está a evolução do paciente?
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="evolucaoPosOperatoria.evolucaoPaciente"
            class="text-primary focus:ring-primary"
            type="radio"
            value="otima"
          />
          <span>Ótima</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="evolucaoPosOperatoria.evolucaoPaciente"
            class="text-primary focus:ring-primary"
            type="radio"
            value="boa"
          />
          <span>Boa</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="evolucaoPosOperatoria.evolucaoPaciente"
            class="text-primary focus:ring-primary"
            type="radio"
            value="regular"
          />
          <span>Regular</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="evolucaoPosOperatoria.evolucaoPaciente"
            class="text-primary focus:ring-primary"
            type="radio"
            value="ruim"
          />
          <span>Ruim</span>
        </label>
      </div>
      <input
        v-model="evolucaoPosOperatoria.evolucaoComentario"
        class="form-input text-xs"
        placeholder="Comentário"
        type="text"
      />
    </div>

    <div class="grid grid-cols-1 md:grid-cols-[1.4fr,1.2fr] gap-3 items-center">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Seguindo orientações?
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="evolucaoPosOperatoria.seguindoOrientacoes"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="evolucaoPosOperatoria.seguindoOrientacoes"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
          />
          <span>Não</span>
        </label>
      </div>
      <input
        v-model="evolucaoPosOperatoria.orientacoesComentario"
        class="form-input text-xs"
        placeholder="Comentário sobre orientações"
        type="text"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  evolucaoPosOperatoria: {
    observacao: string
    evolucaoPaciente: '' | 'otima' | 'boa' | 'regular' | 'ruim'
    evolucaoComentario: string
    seguindoOrientacoes: '' | 'sim' | 'nao'
    orientacoesComentario: string
  }
}>()

const evolucaoPosOperatoria = props.evolucaoPosOperatoria
</script>

