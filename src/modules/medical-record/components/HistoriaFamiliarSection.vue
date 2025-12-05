<template>
  <div class="space-y-4">
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Histórico do pai
      </label>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-2">
        <div>
          <label class="block text-[11px] font-semibold text-primary-700 mb-1">
            Doença hereditária
          </label>
          <select
            :value="historiaFamiliar.historicoPaiDoenca"
            class="form-input text-xs"
            @change="onDoencaHereditPaiSelectChange"
          >
            <option value="">
              Selecione a doença
            </option>
            <option
              v-for="nome in doencasHereditariasPool"
              :key="nome"
              :value="nome"
            >
              {{ nome }}
            </option>
            <option value="__outra__">
              Outra (cadastrar nova...)
            </option>
          </select>
        </div>
      </div>
      <textarea
        v-model="historiaFamiliar.historicoPai"
        class="form-input text-xs min-h-[72px] resize-y"
        placeholder="Digite detalhes sobre o histórico do pai"
      />
    </div>

    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Histórico da mãe
      </label>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-2">
        <div>
          <label class="block text-[11px] font-semibold text-primary-700 mb-1">
            Doença hereditária
          </label>
          <select
            :value="historiaFamiliar.historicoMaeDoenca"
            class="form-input text-xs"
            @change="onDoencaHereditMaeSelectChange"
          >
            <option value="">
              Selecione a doença
            </option>
            <option
              v-for="nome in doencasHereditariasPool"
              :key="nome"
              :value="nome"
            >
              {{ nome }}
            </option>
            <option value="__outra__">
              Outra (cadastrar nova...)
            </option>
          </select>
        </div>
      </div>
      <textarea
        v-model="historiaFamiliar.historicoMae"
        class="form-input text-xs min-h-[72px] resize-y"
        placeholder="Digite detalhes sobre o histórico da mãe"
      />
    </div>

    <div class="space-y-3">
      <div
        v-for="(parente, index) in historiaFamiliar.parentes"
        :key="index"
        class="space-y-1"
      >
        <div class="flex flex-wrap items-center gap-3">
          <p class="text-xs font-semibold text-gray-700">
            {{ parente.tipo }}
          </p>
        </div>
        <div
          class="grid grid-cols-1 md:grid-cols-[0.8fr,0.7fr,0.5fr,1.1fr,auto] gap-3 items-center"
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
          <div
            v-if="
              parente.tipo === 'Irmã' || parente.tipo === 'Irmão'
                ? parente.possui === 'sim'
                : true
            "
            class="flex flex-col md:flex-row gap-2"
          >
            <select
              v-if="parente.tipo === 'Outro parente'"
              v-model="parente.grauParentesco"
              class="form-input text-xs md:max-w-[160px]"
            >
              <option value="">
                Selecione...
              </option>
              <option value="avo_materna">
                Avó materna
              </option>
              <option value="avo_paterna">
                Avó paterna
              </option>
              <option value="avo_materno">
                Avô materno
              </option>
              <option value="avo_paterno">
                Avô paterno
              </option>
              <option value="filho">
                Filho(a)
              </option>
              <option value="irmao">
                Irmão(ã)
              </option>
              <option value="meio_irmao_materno">
                Meio-irmão(ã) materno
              </option>
              <option value="meio_irmao_paterno">
                Meio-irmão(ã) paterno
              </option>
              <option value="mae">
                Mãe
              </option>
              <option value="neto">
                Neto(a)
              </option>
              <option value="pai">
                Pai
              </option>
              <option value="primo">
                Primo(a)
              </option>
              <option value="sobrinho">
                Sobrinho(a)
              </option>
              <option value="tio_materno">
                Tio(a) materno(a)
              </option>
              <option value="tio_paterno">
                Tio(a) paterno(a)
              </option>
            </select>
            <select
              :value="parente.doenca"
              class="form-input text-xs flex-1"
              @change="(e) => onDoencaHereditParenteSelectChange(e, index)"
            >
              <option value="">
                Doença hereditária
              </option>
              <option
                v-for="nome in doencasHereditariasPool"
                :key="nome"
                :value="nome"
              >
                {{ nome }}
              </option>
              <option value="__outra__">
                Outra (cadastrar nova...)
              </option>
            </select>
          </div>
          <div v-else />

          <select
            v-if="
              parente.tipo === 'Irmã' || parente.tipo === 'Irmão'
                ? parente.possui === 'sim'
                : true
            "
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
          <div v-else />

          <input
            v-if="
              parente.tipo === 'Irmã' || parente.tipo === 'Irmão'
                ? parente.possui === 'sim'
                : true
            "
            v-model="parente.comentario"
            class="form-input text-xs"
            placeholder="Comentário"
            type="text"
          />
          <div v-else />

          <button
            v-if="parente.tipo === 'Outro parente'"
            class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
            type="button"
            @click="historiaFamiliar.parentes.splice(index, 1)"
          >
            <i class="fa-solid fa-trash" aria-hidden="true"></i>
          </button>
          <div v-else />
        </div>
      </div>
      <button
        class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
        type="button"
        @click="
          historiaFamiliar.parentes.push({
            tipo: 'Outro parente',
            possui: '',
            doenca: '',
            grauParentesco: '',
            quantidade: '',
            comentario: '',
          })
        "
      >
        <span class="text-base leading-none">+</span>
        <span>Adicionar outro parente</span>
      </button>
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
    historicoPaiDoenca: string
    historicoPai: string
    historicoMaeDoenca: string
    historicoMae: string
    parentes: {
      tipo: string
      possui: '' | 'sim' | 'nao'
      doenca: string
      grauParentesco: string
      quantidade: string
      comentario: string
    }[]
    observacao: string
  }
  doencasHereditariasPool: string[]
  onDoencaHereditPaiSelectChange: (event: Event) => void
  onDoencaHereditMaeSelectChange: (event: Event) => void
  onDoencaHereditParenteSelectChange: (event: Event, index: number) => void
}>()

const historiaFamiliar = props.historiaFamiliar
const doencasHereditariasPool = props.doencasHereditariasPool
const onDoencaHereditPaiSelectChange = props.onDoencaHereditPaiSelectChange
const onDoencaHereditMaeSelectChange = props.onDoencaHereditMaeSelectChange
const onDoencaHereditParenteSelectChange =
  props.onDoencaHereditParenteSelectChange
</script>
