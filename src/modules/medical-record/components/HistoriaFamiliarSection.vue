<template>
  <div class="space-y-4">
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Histórico do pai
      </label>
      <textarea
        v-model="historiaFamiliar.historicoPai"
        class="form-input text-xs min-h-[72px] resize-y"
        placeholder="Digite o histórico do pai"
      />
    </div>

    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Histórico da mãe
      </label>
      <textarea
        v-model="historiaFamiliar.historicoMae"
        class="form-input text-xs min-h-[72px] resize-y"
        placeholder="Digite o histórico da mãe"
      />
    </div>

    <div class="space-y-3">
      <div
        v-for="(parente, index) in historiaFamiliar.parentes"
        :key="index"
        class="space-y-1"
      >
        <p class="text-xs font-semibold text-gray-700">
          {{ parente.tipo }}
        </p>
        <div
          class="grid grid-cols-1 md:grid-cols-[0.8fr,0.5fr,1.1fr] gap-3 items-center"
        >
          <div class="flex items-center gap-4 text-xs">
            <label class="inline-flex items-center gap-1">
              <input
                v-model="parente.possui"
                :name="`parente-${index}`"
                class="text-primary focus:ring-primary"
                type="radio"
                value="sim"
              />
              <span>Sim</span>
            </label>
            <label class="inline-flex items-center gap-1">
              <input
                v-model="parente.possui"
                :name="`parente-${index}`"
                class="text-primary focus:ring-primary"
                type="radio"
                value="nao"
              />
              <span>Não</span>
            </label>
          </div>
          <select
            v-model="parente.quantidade"
            class="form-input text-xs"
          >
            <option value="">
              Quantos
            </option>
            <option
              v-for="q in 10"
              :key="q"
              :value="String(q)"
            >
              {{ q }}
            </option>
          </select>
          <input
            v-model="parente.comentario"
            class="form-input text-xs"
            placeholder="Comentário"
            type="text"
          />
        </div>
      </div>
      <button
        class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
        type="button"
        @click="
          historiaFamiliar.parentes.push({
            tipo: 'Outro parente',
            possui: '',
            quantidade: '',
            comentario: '',
          })
        "
      >
        <span class="text-base leading-none">+</span>
        <span>Adicionar outro parente</span>
      </button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-[0.7fr,1.3fr] gap-3">
      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Histórico familiar
        </label>
        <select
          v-model="historiaFamiliar.historicoNivel"
          class="form-input text-xs"
        >
          <option value="">
            Nível familiar
          </option>
          <option value="primeiro_grau">
            1º grau
          </option>
          <option value="segundo_grau">
            2º grau
          </option>
          <option value="terceiro_grau">
            3º grau
          </option>
        </select>
      </div>
      <div class="pt-5 md:pt-0">
        <input
          v-model="historiaFamiliar.historicoNivelDescricao"
          class="form-input text-xs"
          placeholder="Digite o histórico familiar"
          type="text"
        />
      </div>
    </div>

    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Observação
      </label>
      <textarea
        v-model="historiaFamiliar.observacao"
        class="form-input text-xs min-h-[80px] resize-y"
        placeholder="Digite uma observação..."
      />
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  historiaFamiliar: {
    historicoPai: string
    historicoMae: string
    parentes: {
      tipo: string
      possui: '' | 'sim' | 'nao'
      quantidade: string
      comentario: string
    }[]
    historicoNivel: string
    historicoNivelDescricao: string
    observacao: string
  }
}>()

const historiaFamiliar = props.historiaFamiliar
</script>

