<template>
  <div class="space-y-3">
    <p class="text-xs font-semibold text-gray-700">
      Profissionais
    </p>
    <div
      v-for="(item, index) in equipe.profissionais"
      :key="index"
      class="grid grid-cols-1 md:grid-cols-2 gap-3 items-center"
    >
      <select
        v-model="item.profissional"
        class="form-input text-xs"
      >
        <option value="">
          Selecione o profissional
        </option>
        <option
          v-for="prof in profissionaisOpcoes"
          :key="prof"
          :value="prof"
        >
          {{ prof }}
        </option>
      </select>
      <div class="grid grid-cols-[1fr,auto] gap-2 items-center">
        <input
          v-model="item.comentario"
          class="form-input text-xs"
          placeholder="Comentário"
          type="text"
        />
        <button
          v-if="equipe.profissionais.length > 1"
          class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
          type="button"
          @click="equipe.profissionais.splice(index, 1)"
        >
          <i class="fa-solid fa-trash" aria-hidden="true"></i>
        </button>
      </div>
    </div>
    <button
      class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
      type="button"
      @click="
        equipe.profissionais.push({
          profissional: '',
          comentario: '',
        })
      "
    >
      <span class="text-base leading-none">+</span>
      <span>Adicionar outro profissional</span>
    </button>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  equipe: {
    profissionais: {
      profissional: string
      comentario: string
    }[]
  }
  profissionaisOpcoes: string[]
}>()

const equipe = props.equipe
const profissionaisOpcoes = props.profissionaisOpcoes
</script>

