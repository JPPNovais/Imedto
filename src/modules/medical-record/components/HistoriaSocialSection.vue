<template>
  <div class="space-y-4">
    <!-- Estado civil -->
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Estado civil
      </label>
      <select
        v-model="historiaSocial.estadoCivil"
        class="form-input text-xs"
      >
        <option value="">
          Selecione o estado civil
        </option>
        <option value="solteiro">
          Solteiro(a)
        </option>
        <option value="casado">
          Casado(a)
        </option>
        <option value="uniao_estavel">
          União estável
        </option>
        <option value="divorciado">
          Divorciado(a)
        </option>
        <option value="separado">
          Separado(a)
        </option>
        <option value="viuvo">
          Viúvo(a)
        </option>
      </select>
    </div>

    <!-- Filhos -->
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        Filhos?
      </label>
      <div class="flex items-center gap-4 text-xs">
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.filhosTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.filhosTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
          />
          <span>Não</span>
        </label>
      </div>
    </div>

    <div
      v-if="historiaSocial.filhosTem === 'sim'"
      class="grid grid-cols-1 md:grid-cols-3 gap-3"
    >
      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Quantos filhos?
        </label>
        <input
          v-model="historiaSocial.filhosQuantidade"
          class="form-input text-xs"
          type="number"
          min="0"
          placeholder="Número"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Idades
        </label>
        <input
          v-model="historiaSocial.filhosIdades"
          class="form-input text-xs"
          type="text"
          placeholder="Ex: 5, 8, 12 anos"
        />
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Observações
        </label>
        <input
          v-model="historiaSocial.filhosObservacoes"
          class="form-input text-xs"
          type="text"
          placeholder="Digite observações"
        />
      </div>
    </div>

    <!-- Tabagismo -->
    <div class="border-t border-gray-100 pt-3 space-y-3">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Tabagismo?
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.tabagismoTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.tabagismoTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
            @change="
              historiaSocial.tabagismoStatus = 'nao_fuma';
              historiaSocial.tabagismoTipos = [
                {
                  tipo: '',
                  quantidade: '',
                  unidade: '',
                  tempoQuantidade: '',
                  tempoUnidade: '',
                },
              ];
              historiaSocial.tabagismoObservacoes = '';
            "
          />
          <span>Não</span>
        </label>
      </div>

      <div
        v-if="historiaSocial.tabagismoTem === 'sim'"
        class="space-y-3"
      >
        <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
          <div>
            <select
              v-model="historiaSocial.tabagismoStatus"
              class="form-input text-xs"
            >
              <option value="">
                Selecione...
              </option>
              <option value="nao_fuma">
                Não fuma / Nunca fumou
              </option>
              <option value="fumante_ativo">
                Fumante ativo
              </option>
              <option value="fumante_passivo">
                Fumante passivo
              </option>
              <option value="ex_fumante">
                Ex-fumante
              </option>
            </select>
          </div>
          <input
            v-model="historiaSocial.tabagismoObservacoes"
            class="form-input text-xs"
            placeholder="Observações gerais (tentativas de parar, carga tabágica...)"
            type="text"
          />
        </div>

        <div
          v-if="historiaSocial.tabagismoStatus && historiaSocial.tabagismoStatus !== 'nao_fuma'"
          class="space-y-2"
        >
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-semibold text-gray-700">
              Tipos de fumo
            </p>
            <button
              class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
              type="button"
              @click="
                historiaSocial.tabagismoTipos.push({
                  tipo: '',
                  quantidade: '',
                  unidade: '',
                  tempoQuantidade: '',
                  tempoUnidade: '',
                })
              "
            >
              <span class="text-base leading-none">+</span>
              <span>Adicionar tipo de fumo</span>
            </button>
          </div>

          <div
            v-for="(item, index) in historiaSocial.tabagismoTipos"
            :key="index"
            class="grid grid-cols-1 md:grid-cols-[1.1fr,0.7fr,0.7fr] gap-3 items-center"
          >
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Tipo
              </label>
              <select
                v-model="item.tipo"
                class="form-input text-xs"
              >
                <option value="">
                  Selecione o tipo
                </option>
                <option value="cigarro_industrial">
                  Cigarro industrial
                </option>
                <option value="cigarro_palha">
                  Cigarro de palha
                </option>
                <option value="charuto">
                  Charuto
                </option>
                <option value="cigarro_eletronico">
                  Cigarro eletrônico / Pod
                </option>
                <option value="narguile">
                  Narguilé
                </option>
                <option value="outro">
                  Outro
                </option>
              </select>
            </div>
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Quantidade
              </label>
              <div class="grid grid-cols-[0.8fr,1.2fr] gap-2">
                <input
                  v-model="item.quantidade"
                  class="form-input text-xs"
                  placeholder="Qtd"
                  type="number"
                  min="0"
                />
                <select
                  v-model="item.unidade"
                  class="form-input text-xs"
                >
                  <option value="">
                    Unidade
                  </option>
                  <option value="macos_dia">
                    maços/dia
                  </option>
                  <option value="cigarros_dia">
                    cigarros/dia
                  </option>
                  <option value="cigarros_semana">
                    cigarros/semana
                  </option>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Tempo de uso
              </label>
              <div class="grid grid-cols-[0.8fr,1.2fr] gap-2">
                <input
                  v-model="item.tempoQuantidade"
                  class="form-input text-xs"
                  placeholder="Tempo"
                  type="number"
                  min="0"
                />
                <select
                  v-model="item.tempoUnidade"
                  class="form-input text-xs"
                >
                  <option value="">
                    Unidade
                  </option>
                  <option value="anos">
                    anos
                  </option>
                  <option value="meses">
                    meses
                  </option>
                </select>
              </div>
            </div>
            <div class="md:col-span-3 flex justify-end">
              <button
                v-if="historiaSocial.tabagismoTipos.length > 1"
                class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                type="button"
                @click="historiaSocial.tabagismoTipos.splice(index, 1)"
              >
                <i class="fa-solid fa-trash" aria-hidden="true"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Etilismo -->
    <div class="border-t border-gray-100 pt-3 space-y-3">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Etilismo?
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.etilismoTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.etilismoTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
            @change="
              historiaSocial.etilismoStatus = 'nao_bebe';
              historiaSocial.etilismoBebidas = [
                {
                  tipo: '',
                  frequencia: '',
                  quantidade: '',
                  unidade: '',
                },
              ];
              historiaSocial.etilismoObservacoes = '';
            "
          />
          <span>Não</span>
        </label>
      </div>

      <div
        v-if="historiaSocial.etilismoTem === 'sim'"
        class="space-y-3"
      >
        <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
          <div>
            <select
              v-model="historiaSocial.etilismoStatus"
              class="form-input text-xs"
            >
              <option value="">
                Selecione...
              </option>
              <option value="nao_bebe">
                Não bebe / Nunca bebeu
              </option>
              <option value="esporadico">
                Esporádico (1–2x/ano)
              </option>
              <option value="social">
                Social (ocasiões)
              </option>
              <option value="moderado">
                Moderado (semanal)
              </option>
              <option value="frequente">
                Frequente (diário)
              </option>
              <option value="ex_etilista">
                Ex-etilista
              </option>
            </select>
          </div>
          <input
            v-model="historiaSocial.etilismoObservacoes"
            class="form-input text-xs"
            placeholder="Observações gerais"
            type="text"
          />
        </div>

        <div
          v-if="historiaSocial.etilismoStatus && historiaSocial.etilismoStatus !== 'nao_bebe'"
          class="space-y-2"
        >
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-semibold text-gray-700">
              Tipos de bebida
            </p>
            <button
              class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
              type="button"
              @click="
                historiaSocial.etilismoBebidas.push({
                  tipo: '',
                  frequencia: '',
                  quantidade: '',
                  unidade: '',
                })
              "
            >
              <span class="text-base leading-none">+</span>
              <span>Adicionar tipo de bebida</span>
            </button>
          </div>

          <div
            v-for="(item, index) in historiaSocial.etilismoBebidas"
            :key="index"
            class="grid grid-cols-1 md:grid-cols-[1.1fr,0.7fr,0.7fr] gap-3 items-center"
          >
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Tipo de bebida
              </label>
              <input
                v-model="item.tipo"
                class="form-input text-xs"
                placeholder="Ex: Cerveja, vinho..."
                type="text"
              />
            </div>
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Frequência
              </label>
              <select
                v-model="item.frequencia"
                class="form-input text-xs"
              >
                <option value="">
                  Selecione...
                </option>
                <option value="esporadico">
                  Esporádico
                </option>
                <option value="semanal">
                  Semanal
                </option>
                <option value="diario">
                  Diário
                </option>
              </select>
            </div>
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Quantidade
              </label>
              <div class="grid grid-cols-[0.8fr,1.2fr] gap-2">
                <input
                  v-model="item.quantidade"
                  class="form-input text-xs"
                  placeholder="Qtd"
                  type="number"
                  min="0"
                />
                <select
                  v-model="item.unidade"
                  class="form-input text-xs"
                >
                  <option value="">
                    Unidade
                  </option>
                  <option value="latas_dia">
                    latas/dia
                  </option>
                  <option value="tacas_dia">
                    taças/dia
                  </option>
                  <option value="doses_semana">
                    doses/semana
                  </option>
                </select>
              </div>
            </div>
            <div class="md:col-span-3 flex justify-end">
              <button
                v-if="historiaSocial.etilismoBebidas.length > 1"
                class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                type="button"
                @click="historiaSocial.etilismoBebidas.splice(index, 1)"
              >
                <i class="fa-solid fa-trash" aria-hidden="true"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Outras drogas / substâncias -->
    <div class="border-t border-gray-100 pt-3 space-y-3">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Outras drogas/substâncias?
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.outrasSubstanciasTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.outrasSubstanciasTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
            @change="
              historiaSocial.outrasSubstanciasStatus = 'nao';
              historiaSocial.outrasSubstanciasLista = [
                {
                  tipo: '',
                  frequencia: '',
                  observacoes: '',
                },
              ];
            "
          />
          <span>Não</span>
        </label>
      </div>

      <div
        v-if="historiaSocial.outrasSubstanciasTem === 'sim'"
        class="space-y-3"
      >
        <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
          <div>
            <select
              v-model="historiaSocial.outrasSubstanciasStatus"
              class="form-input text-xs"
            >
              <option value="">
                Selecione...
              </option>
              <option value="uso_atual">
                Uso atual
              </option>
              <option value="uso_previo">
                Uso prévio
              </option>
            </select>
          </div>
        </div>

        <div
          v-if="historiaSocial.outrasSubstanciasStatus && historiaSocial.outrasSubstanciasStatus !== 'nao'"
          class="space-y-2"
        >
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-semibold text-gray-700">
              Substâncias
            </p>
            <button
              class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
              type="button"
              @click="
                historiaSocial.outrasSubstanciasLista.push({
                  tipo: '',
                  frequencia: '',
                  observacoes: '',
                })
              "
            >
              <span class="text-base leading-none">+</span>
              <span>Adicionar substância</span>
            </button>
          </div>

          <div
            v-for="(item, index) in historiaSocial.outrasSubstanciasLista"
            :key="index"
            class="grid grid-cols-1 md:grid-cols-[1.1fr,0.9fr] gap-3 items-start"
          >
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Tipo
              </label>
              <input
                v-model="item.tipo"
                class="form-input text-xs"
                placeholder="Ex: Maconha, cocaína..."
                type="text"
              />
            </div>
            <div>
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Frequência
              </label>
              <select
                v-model="item.frequencia"
                class="form-input text-xs"
              >
                <option value="">
                  Selecione...
                </option>
                <option value="esporadico">
                  Esporádico
                </option>
                <option value="semanal">
                  Semanal
                </option>
                <option value="diario">
                  Diário
                </option>
              </select>
            </div>
            <div class="md:col-span-2">
              <label class="block text-[11px] font-semibold text-gray-700 mb-1">
                Observações
              </label>
              <textarea
                v-model="item.observacoes"
                class="form-input text-xs min-h-[60px] resize-y"
                placeholder="Via de uso, há quanto tempo, tentativas de parar..."
              />
            </div>
            <div class="md:col-span-2 flex justify-end">
              <button
                v-if="historiaSocial.outrasSubstanciasLista.length > 1"
                class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                type="button"
                @click="historiaSocial.outrasSubstanciasLista.splice(index, 1)"
              >
                <i class="fa-solid fa-trash" aria-hidden="true"></i>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Atividade física -->
    <div class="border-t border-gray-100 pt-3 space-y-3">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Pratica atividade física?
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.atividadeFisicaTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaSocial.atividadeFisicaTem"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
            @change="
              historiaSocial.atividadeFisicaNivel = 'sedentario';
              historiaSocial.atividadeFisicaAtividades = [
                {
                  tipo: '',
                  frequencia: '',
                },
              ];
              historiaSocial.atividadeFisicaObservacoes = '';
            "
          />
          <span>Não</span>
        </label>
      </div>

      <div
        v-if="historiaSocial.atividadeFisicaTem === 'sim'"
        class="space-y-3"
      >
        <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
          <div>
            <select
              v-model="historiaSocial.atividadeFisicaNivel"
              class="form-input text-xs"
            >
              <option value="">
                Selecione...
              </option>
              <option value="leve">
                Leve (1–2x/semana)
              </option>
              <option value="moderado">
                Moderado (3–4x/semana)
              </option>
              <option value="intenso">
                Intenso (5+x/semana)
              </option>
            </select>
          </div>
          <input
            v-model="historiaSocial.atividadeFisicaObservacoes"
            class="form-input text-xs"
            placeholder="Observações gerais"
            type="text"
          />
        </div>

        <div
          v-if="historiaSocial.atividadeFisicaNivel"
          class="space-y-2"
        >
          <div class="flex items-center justify-between">
            <p class="text-[11px] font-semibold text-gray-700">
              Atividades
            </p>
            <button
              class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
              type="button"
              @click="
                historiaSocial.atividadeFisicaAtividades.push({
                  tipo: '',
                  frequencia: '',
                })
              "
            >
              <span class="text-base leading-none">+</span>
              <span>Adicionar atividade</span>
            </button>
          </div>

          <div
            v-for="(item, index) in historiaSocial.atividadeFisicaAtividades"
            :key="index"
            class="grid grid-cols-1 md:grid-cols-[1.2fr,0.8fr,auto] gap-3 items-center"
          >
            <input
              v-model="item.tipo"
              class="form-input text-xs"
              placeholder="Ex: Caminhada, musculação..."
              type="text"
            />
            <select
              v-model="item.frequencia"
              class="form-input text-xs"
            >
              <option value="">
                Selecione a frequência
              </option>
              <option value="leve">
                1–2x/semana
              </option>
              <option value="moderado">
                3–4x/semana
              </option>
              <option value="intenso">
                5+x/semana
              </option>
            </select>
            <button
              v-if="historiaSocial.atividadeFisicaAtividades.length > 1"
              class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
              type="button"
              @click="historiaSocial.atividadeFisicaAtividades.splice(index, 1)"
            >
              <i class="fa-solid fa-trash" aria-hidden="true"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Alimentação -->
    <div class="border-t border-gray-100 pt-3 space-y-3">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Alimentação
          </label>
          <select
            v-model="historiaSocial.alimentacaoTipo"
            class="form-input text-xs"
          >
            <option value="">
              Selecione...
            </option>
            <option value="equilibrada">
              Equilibrada / Saudável
            </option>
            <option value="irregular">
              Irregular
            </option>
            <option value="restritiva">
              Restritiva / Dieta
            </option>
            <option value="vegetariana">
              Vegetariana
            </option>
            <option value="vegana">
              Vegana
            </option>
            <option value="hipossodica">
              Hipossódica
            </option>
            <option value="diabetico">
              Para diabético
            </option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Observações sobre alimentação
          </label>
          <textarea
            v-model="historiaSocial.alimentacaoObservacoes"
            class="form-input text-xs min-h-[60px] resize-y"
            placeholder="Ex: Restrições alimentares, número de refeições/dia, preferências..."
          />
        </div>
      </div>
    </div>

    <!-- Sono e rotina -->
    <div class="border-t border-gray-100 pt-3 space-y-3">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Sono e rotina
          </label>
          <select
            v-model="historiaSocial.sonoRotinaQualidade"
            class="form-input text-xs"
          >
            <option value="">
              Selecione...
            </option>
            <option value="bom">
              Bom (7–8h, reparador)
            </option>
            <option value="regular">
              Regular (5–6h)
            </option>
            <option value="ruim">
              Ruim (insônia, fragmentado)
            </option>
            <option value="irregular">
              Irregular (horários variados)
            </option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Observações sobre sono e rotina
          </label>
          <textarea
            v-model="historiaSocial.sonoRotinaObservacoes"
            class="form-input text-xs min-h-[60px] resize-y"
            placeholder="Ex: Horas de sono, qualidade, uso de medicações para dormir, trabalho noturno..."
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  historiaSocial: {
    estadoCivil: string
    filhosTem: '' | 'sim' | 'nao'
    filhosQuantidade: string
    filhosIdades: string
    filhosObservacoes: string
    tabagismoTem: '' | 'sim' | 'nao'
    tabagismoStatus:
      | ''
      | 'nao_fuma'
      | 'fumante_ativo'
      | 'fumante_passivo'
      | 'ex_fumante'
    tabagismoTipos: {
      tipo: string
      quantidade: string
      unidade: string
      tempoQuantidade: string
      tempoUnidade: string
    }[]
    tabagismoObservacoes: string
    etilismoTem: '' | 'sim' | 'nao'
    etilismoStatus:
      | ''
      | 'nao_bebe'
      | 'esporadico'
      | 'social'
      | 'moderado'
      | 'frequente'
      | 'ex_etilista'
    etilismoBebidas: {
      tipo: string
      frequencia: string
      quantidade: string
      unidade: string
    }[]
    etilismoObservacoes: string
    outrasSubstanciasTem: '' | 'sim' | 'nao'
    outrasSubstanciasStatus: '' | 'nao' | 'uso_atual' | 'uso_previo'
    outrasSubstanciasLista: {
      tipo: string
      frequencia: string
      observacoes: string
    }[]
    atividadeFisicaTem: '' | 'sim' | 'nao'
    atividadeFisicaNivel: '' | 'sedentario' | 'leve' | 'moderado' | 'intenso'
    atividadeFisicaAtividades: {
      tipo: string
      frequencia: string
    }[]
    atividadeFisicaObservacoes: string
    alimentacaoTipo: string
    alimentacaoObservacoes: string
    sonoRotinaQualidade: string
    sonoRotinaObservacoes: string
  }
}>()

const historiaSocial = props.historiaSocial
</script>
