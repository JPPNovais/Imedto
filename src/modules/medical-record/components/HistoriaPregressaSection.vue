<template>
  <div class="space-y-4">
    <div>
      <label class="block text-xs font-semibold text-gray-700 mb-1">
        História pregressa
      </label>
      <textarea
        v-model="historiaPregressa.textoGeral"
        class="form-input text-xs min-h-[120px] resize-y"
        placeholder="Digite a história pregressa do paciente"
      />
    </div>

    <!-- Alergias -->
    <div class="space-y-4">
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Alergia
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaPregressa.alergiaPossui"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
          />
          <span>Não</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaPregressa.alergiaPossui"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
      </div>

      <div
        v-if="historiaPregressa.alergiaPossui === 'sim'"
        class="space-y-2"
      >
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Alergia
            </label>
          </div>
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Observações
            </label>
          </div>
        </div>
        <div
          v-for="(item, index) in historiaPregressa.alergiasDetalhadas"
          :key="index"
          class="grid grid-cols-[1.4fr,1.4fr,auto] gap-3 items-center"
        >
          <div class="flex gap-2">
            <select
              :value="item.alergia"
              class="form-input text-xs flex-1"
              @change="(e) => onAlergiaSelectChange(e, index)"
            >
              <option value="">
                Selecione a alergia
              </option>
              <option
                v-for="nome in alergiasPool"
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
          <input
            v-model="item.observacao"
            class="form-input text-xs"
            placeholder="Digite uma observação"
            type="text"
          />
          <button
            v-if="historiaPregressa.alergiasDetalhadas.length > 1"
            class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
            type="button"
            @click="historiaPregressa.alergiasDetalhadas.splice(index, 1)"
          >
            <i class="fa-solid fa-trash" aria-hidden="true"></i>
          </button>
        </div>
        <button
          class="mt-1 inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
          type="button"
          @click="
            historiaPregressa.alergiasDetalhadas.push({
              alergia: '',
              observacao: '',
            })
          "
        >
          <span class="text-base leading-none">+</span>
          <span>Adicionar alergia</span>
        </button>
      </div>

      <!-- Uso de medicamentos -->
      <div class="flex items-center gap-4 text-xs">
        <span class="font-semibold text-gray-700">
          Uso de medicamento(s)
        </span>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaPregressa.usoMedicamentos"
            class="text-primary focus:ring-primary"
            type="radio"
            value="nao"
          />
          <span>Não</span>
        </label>
        <label class="inline-flex items-center gap-1">
          <input
            v-model="historiaPregressa.usoMedicamentos"
            class="text-primary focus:ring-primary"
            type="radio"
            value="sim"
          />
          <span>Sim</span>
        </label>
      </div>

      <div
        v-if="historiaPregressa.usoMedicamentos === 'sim'"
        class="space-y-3"
      >
        <p class="text-xs font-semibold text-gray-700">
          Medicações em uso
        </p>

        <div
          v-for="(med, index) in historiaPregressa.medicacoes"
          :key="index"
          class="border border-gray-100 rounded-lg p-3 bg-gray-50"
        >
          <div class="flex items-center justify-between mb-2">
            <span class="text-xs font-semibold text-green-700">
              Medicação {{ index + 1 }}
            </span>
            <button
              v-if="historiaPregressa.medicacoes.length > 1"
              type="button"
              class="h-8 px-2 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 text-[11px] hover:bg-red-50"
              @click="historiaPregressa.medicacoes.splice(index, 1)"
            >
              Remover
            </button>
          </div>

          <div class="space-y-3 text-xs">
            <div>
              <label class="block font-semibold text-gray-700 mb-1">
                Nome do medicamento
              </label>
              <div class="flex gap-2">
                <select
                  :value="med.medicamento"
                  class="form-input text-xs flex-1"
                  @change="(e) => onMedicacaoSelectChange(e, index)"
                >
                  <option value="">
                    Selecione...
                  </option>
                  <option
                    v-for="nome in medicacoesPool"
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

            <div class="grid grid-cols-1 md:grid-cols-[1.1fr,0.9fr] gap-3">
              <div>
                <label class="block font-semibold text-gray-700 mb-1">
                  Dose
                </label>
                <input
                  v-model="med.dose"
                  class="form-input text-xs"
                  placeholder="Ex.: 50mg"
                  type="text"
                />
              </div>
              <div>
                <label class="block font-semibold text-gray-700 mb-1">
                  Frequência
                </label>
                <select
                  v-model="med.frequencia"
                  class="form-input text-xs"
                >
                  <option value="">
                    Selecione...
                  </option>
                  <option value="1x/dia">
                    1x/dia
                  </option>
                  <option value="2x/dia">
                    2x/dia
                  </option>
                  <option value="3x/dia">
                    3x/dia
                  </option>
                  <option value="4x/dia">
                    4x/dia
                  </option>
                  <option value="6/6h">
                    6/6h
                  </option>
                  <option value="8/8h">
                    8/8h
                  </option>
                  <option value="12/12h">
                    12/12h
                  </option>
                  <option value="sob_demanda">
                    Sob demanda
                  </option>
                </select>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label class="block font-semibold text-gray-700 mb-1">
                  Motivo / Indicação
                </label>
                <input
                  v-model="med.indicacao"
                  class="form-input text-xs"
                  placeholder="Ex.: Hipertensão"
                  type="text"
                />
              </div>
              <div>
                <label class="block font-semibold text-gray-700 mb-1">
                  Observações
                </label>
                <input
                  v-model="med.observacao"
                  class="form-input text-xs"
                  placeholder="Informações adicionais sobre a medicação..."
                  type="text"
                />
              </div>
            </div>
          </div>
        </div>

        <button
          class="inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
          type="button"
          @click="
            historiaPregressa.medicacoes.push({
              medicamento: '',
              dose: '',
              frequencia: '',
              indicacao: '',
              observacao: '',
            })
          "
        >
          <span class="text-base leading-none">+</span>
          <span>Adicionar medicação</span>
        </button>
      </div>

      <!-- Cirurgias anteriores -->
      <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.4fr] gap-3 items-center">
        <div class="flex items-center gap-4 text-xs">
          <span class="font-semibold text-gray-700">
            Cirurgia(s) anterior(es)
          </span>
          <label class="inline-flex items-center gap-1">
            <input
              v-model="historiaPregressa.cirurgiasAnteriores"
              class="text-primary focus:ring-primary"
              type="radio"
              value="nao"
            />
            <span>Não</span>
          </label>
          <label class="inline-flex items-center gap-1">
            <input
              v-model="historiaPregressa.cirurgiasAnteriores"
              class="text-primary focus:ring-primary"
              type="radio"
              value="sim"
            />
            <span>Sim</span>
          </label>
        </div>
      </div>

      <div
        v-if="historiaPregressa.cirurgiasAnteriores === 'sim'"
        class="space-y-3"
      >
        <div class="grid grid-cols-1 md:grid-cols-[1.1fr,0.7fr,1.4fr] gap-3">
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Cirurgia
            </label>
          </div>
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Ano
            </label>
          </div>
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Observações
            </label>
          </div>
        </div>
        <div
          v-for="(item, index) in historiaPregressa.cirurgiasDetalhadas"
          :key="index"
          class="grid grid-cols-[1.4fr,0.7fr,1.4fr,auto] gap-3 items-center"
        >
          <div class="flex gap-2">
            <select
              :value="item.cirurgia"
              class="form-input text-xs flex-1"
              @change="(e) => onCirurgiaSelectChange(e, index)"
            >
              <option value="">
                Selecione a cirurgia
              </option>
              <option
                v-for="nome in cirurgiasPool"
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
          <input
            v-model="item.ano"
            class="form-input text-xs"
            placeholder="Ano"
            type="number"
            min="1900"
            max="2100"
          />
          <input
            v-model="item.observacao"
            class="form-input text-xs"
            placeholder="Digite uma observação"
            type="text"
          />
          <button
            v-if="historiaPregressa.cirurgiasDetalhadas.length > 1"
            class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
            type="button"
            @click="historiaPregressa.cirurgiasDetalhadas.splice(index, 1)"
          >
            <i class="fa-solid fa-trash" aria-hidden="true"></i>
          </button>
        </div>
        <button
          class="mt-1 inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
          type="button"
          @click="
            historiaPregressa.cirurgiasDetalhadas.push({
              cirurgia: '',
              ano: '',
              observacao: '',
            })
          "
        >
          <span class="text-base leading-none">+</span>
          <span>Adicionar cirurgia</span>
        </button>
      </div>

      <!-- Doenças prévias -->
      <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.4fr] gap-3 items-center">
        <div class="flex items-center gap-4 text-xs">
          <span class="font-semibold text-gray-700">
            Doença(s) prévia(s)
          </span>
          <label class="inline-flex items-center gap-1">
            <input
              v-model="historiaPregressa.doencasPrevias"
              class="text-primary focus:ring-primary"
              type="radio"
              value="nao"
            />
            <span>Não</span>
          </label>
          <label class="inline-flex items-center gap-1">
            <input
              v-model="historiaPregressa.doencasPrevias"
              class="text-primary focus:ring-primary"
              type="radio"
              value="sim"
            />
            <span>Sim</span>
          </label>
        </div>
      </div>

      <div
        v-if="historiaPregressa.doencasPrevias === 'sim'"
        class="space-y-2"
      >
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Doença
            </label>
          </div>
          <div>
            <label class="block text-[11px] font-semibold text-primary-700 mb-1">
              Observações
            </label>
          </div>
        </div>
        <div
          v-for="(item, index) in historiaPregressa.doencasDetalhadas"
          :key="index"
          class="grid grid-cols-[1.4fr,1.4fr,auto] gap-3 items-center"
        >
          <div class="flex gap-2">
            <select
              :value="item.doenca"
              class="form-input text-xs flex-1"
              @change="(e) => onDoencaCronicaSelectChange(e, index)"
            >
              <option value="">
                Selecione a doença
              </option>
              <option
                v-for="nome in doencasCronicasPool"
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
          <input
            v-model="item.observacao"
            class="form-input text-xs"
            placeholder="Digite uma observação"
            type="text"
          />
          <button
            v-if="historiaPregressa.doencasDetalhadas.length > 1"
            class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
            type="button"
            @click="historiaPregressa.doencasDetalhadas.splice(index, 1)"
          >
            <i class="fa-solid fa-trash" aria-hidden="true"></i>
          </button>
        </div>
        <button
          class="mt-1 inline-flex items-center gap-1 text-xs text-primary-700 font-semibold hover:underline"
          type="button"
          @click="
            historiaPregressa.doencasDetalhadas.push({
              doenca: '',
              observacao: '',
            })
          "
        >
          <span class="text-base leading-none">+</span>
          <span>Adicionar doença</span>
        </button>
      </div>

      <!-- Tipo de cicatrização -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Tipo de cicatrização
          </label>
          <select
            v-model="historiaPregressa.tipoCicatrizacaoNivel"
            class="form-input text-xs"
          >
            <option value="">
              Selecione o nível
            </option>
            <option value="boa">
              Boa
            </option>
            <option value="regular">
              Regular
            </option>
            <option value="ruim">
              Ruim / queloide
            </option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Descrição
          </label>
          <input
            v-model="historiaPregressa.tipoCicatrizacaoDescricao"
            class="form-input text-xs"
            placeholder="Descrição"
            type="text"
          />
        </div>
      </div>

      <!-- Sexo / Gineco-obstétrica -->
      <div class="border-t border-gray-100 pt-3 mt-2 space-y-3">
        <p class="text-xs font-semibold text-gray-700">
          Sexo
          <span
            v-if="pacienteSexo"
            class="ml-2 text-[11px] font-normal text-gray-600"
          >
            ({{ pacienteSexo }})
          </span>
        </p>
        <div
          v-if="isPacienteFeminino"
          class="space-y-3"
        >
          <div class="grid grid-cols-1 md:grid-cols-[0.9fr,1.3fr] gap-3 items-center">
            <div class="flex items-center gap-4 text-xs">
              <span class="font-semibold text-gray-700">
                Usa anticoncepcional?
              </span>
              <label class="inline-flex items-center gap-1">
                <input
                  v-model="historiaPregressa.usaAnticoncepcional"
                  class="text-primary focus:ring-primary"
                  type="radio"
                  value="sim"
                />
                <span>Sim</span>
              </label>
              <label class="inline-flex items-center gap-1">
                <input
                  v-model="historiaPregressa.usaAnticoncepcional"
                  class="text-primary focus:ring-primary"
                  type="radio"
                  value="nao"
                />
                <span>Não</span>
              </label>
            </div>
            <input
              v-model="historiaPregressa.usaAnticoncepcionalQual"
              class="form-input text-xs"
              placeholder="Qual?"
              type="text"
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-[0.9fr,1.3fr] gap-3 items-center">
            <div class="flex items-center gap-4 text-xs">
              <span class="font-semibold text-gray-700">
                Usa algum outro método contraceptivo?
              </span>
              <label class="inline-flex items-center gap-1">
                <input
                  v-model="historiaPregressa.usaOutroMetodo"
                  class="text-primary focus:ring-primary"
                  type="radio"
                  value="sim"
                />
                <span>Sim</span>
              </label>
              <label class="inline-flex items-center gap-1">
                <input
                  v-model="historiaPregressa.usaOutroMetodo"
                  class="text-primary focus:ring-primary"
                  type="radio"
                  value="nao"
                />
                <span>Não</span>
              </label>
            </div>
            <input
              v-model="historiaPregressa.usaOutroMetodoQual"
              class="form-input text-xs"
              placeholder="Qual?"
              type="text"
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-[0.9fr,1.3fr] gap-3 items-center">
            <div class="flex items-center gap-4 text-xs">
              <span class="font-semibold text-gray-700">
                Está ou já passou por gravidez?
              </span>
              <label class="inline-flex items-center gap-1">
                <input
                  v-model="historiaPregressa.gravidaOuJaEsteve"
                  class="text-primary focus:ring-primary"
                  type="radio"
                  value="sim"
                />
                <span>Sim</span>
              </label>
              <label class="inline-flex items-center gap-1">
                <input
                  v-model="historiaPregressa.gravidaOuJaEsteve"
                  class="text-primary focus:ring-primary"
                  type="radio"
                  value="nao"
                />
                <span>Não</span>
              </label>
            </div>
            <input
              v-model="historiaPregressa.gravidaDescricao"
              class="form-input text-xs"
              placeholder="Descreva se foi parto normal ou cesáreas e quantos"
              type="text"
            />
          </div>

          <div>
            <label class="block text-xs font-semibold text-gray-700 mb-1">
              G(x) P(y) A(z)
            </label>
            <input
              v-model="historiaPregressa.gestacaoGpa"
              class="form-input text-xs"
              placeholder="Digite..."
              type="text"
            />
          </div>

          <div class="flex items-center gap-4 text-xs pt-1">
            <span class="font-semibold text-gray-700">
              Informar ciclo menstrual?
            </span>
            <label class="inline-flex items-center gap-1">
              <input
                v-model="historiaPregressa.informarCicloMenstrual"
                class="text-primary focus:ring-primary"
                type="radio"
                value="nao"
              />
              <span>Não</span>
            </label>
            <label class="inline-flex items-center gap-1">
              <input
                v-model="historiaPregressa.informarCicloMenstrual"
                class="text-primary focus:ring-primary"
                type="radio"
                value="sim"
              />
              <span>Sim</span>
            </label>
          </div>

          <div
            v-if="historiaPregressa.informarCicloMenstrual === 'sim'"
            class="space-y-3"
          >
            <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
              <div class="flex items-end gap-2">
                <div class="flex-1">
                  <label class="block text-xs font-semibold text-gray-700 mb-1">
                    Menarca (1ª menstruação)
                  </label>
                  <input
                    v-model="historiaPregressa.cicloMenarcaIdade"
                    class="form-input text-xs"
                    placeholder="Ex.: 12"
                    type="number"
                    min="8"
                    max="20"
                  />
                </div>
                <span class="text-[11px] text-gray-500 mb-2">
                  anos
                </span>
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Menopausa
                </label>
                <select
                  v-model="historiaPregressa.cicloMenopausa"
                  class="form-input text-xs"
                >
                  <option value="">
                    Selecione...
                  </option>
                  <option value="nao">
                    Não
                  </option>
                  <option value="sim">
                    Sim
                  </option>
                </select>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Ciclo
                </label>
                <select
                  v-model="historiaPregressa.cicloTipo"
                  class="form-input text-xs"
                >
                  <option value="">
                    Selecione...
                  </option>
                  <option value="regular">
                    Regular
                  </option>
                  <option value="irregular">
                    Irregular
                  </option>
                  <option value="oligomenorreia">
                    Oligomenorreia
                  </option>
                  <option value="polimenorreia">
                    Polimenorreia
                  </option>
                  <option value="amenorreia">
                    Amenorreia
                  </option>
                </select>
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Intervalo (dias)
                </label>
                <input
                  v-model="historiaPregressa.cicloIntervaloDias"
                  class="form-input text-xs"
                  placeholder="Ex.: 28-30"
                  type="text"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Duração do fluxo (dias)
                </label>
                <input
                  v-model="historiaPregressa.cicloDuracaoFluxoDias"
                  class="form-input text-xs"
                  placeholder="Ex.: 5"
                  type="number"
                  min="1"
                  max="15"
                />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  DUM (Última menstruação)
                </label>
                <input
                  v-model="historiaPregressa.cicloDum"
                  class="form-input text-xs"
                  placeholder="dd/mm/aaaa"
                  type="date"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Intensidade do fluxo
                </label>
                <select
                  v-model="historiaPregressa.cicloIntensidadeFluxo"
                  class="form-input text-xs"
                >
                  <option value="">
                    Selecione...
                  </option>
                  <option value="leve">
                    Leve
                  </option>
                  <option value="moderado">
                    Moderado
                  </option>
                  <option value="intenso">
                    Intenso
                  </option>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-700 mb-1">
                Observações sobre ciclo menstrual
              </label>
              <textarea
                v-model="historiaPregressa.cicloObservacoes"
                class="form-input text-xs min-h-[64px] resize-y"
                placeholder="Ex.: Dismenorreia, TPM intensa, sangramento intermenstrual, uso de medicação para cólica..."
              />
            </div>
          </div>
        </div>
      </div>

      <div>
        <label class="block text-xs font-semibold text-gray-700 mb-1">
          Observações
        </label>
        <textarea
          v-model="historiaPregressa.observacoes"
          class="form-input text-xs min-h-[80px] resize-y"
          placeholder="Digite uma observação..."
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
 
type RadioSimNao = '' | 'sim' | 'nao'

const props = defineProps<{
  historiaPregressa: {
    textoGeral: string
    alergiaPossui: RadioSimNao
    alergiasDetalhadas: { alergia: string; observacao: string }[]
    usoMedicamentos: RadioSimNao
    medicacoes: {
      medicamento: string
      dose: string
      frequencia: string
      indicacao: string
      observacao: string
    }[]
    cirurgiasAnteriores: RadioSimNao
    cirurgiasDetalhadas: { cirurgia: string; ano: string; observacao: string }[]
    doencasPrevias: RadioSimNao
    doencasDetalhadas: { doenca: string; observacao: string }[]
    informarCicloMenstrual: RadioSimNao
    cicloMenarcaIdade: string
    cicloMenopausa: RadioSimNao
    cicloTipo: string
    cicloIntervaloDias: string
    cicloDuracaoFluxoDias: string
    cicloDum: string
    cicloIntensidadeFluxo: string
    cicloObservacoes: string
    tipoCicatrizacaoNivel: string
    tipoCicatrizacaoDescricao: string
    usaAnticoncepcional: RadioSimNao
    usaAnticoncepcionalQual: string
    usaOutroMetodo: RadioSimNao
    usaOutroMetodoQual: string
    gravidaOuJaEsteve: RadioSimNao
    gravidaDescricao: string
    gestacaoGpa: string
    observacoes: string
  }
  alergiasPool: string[]
  cirurgiasPool: string[]
  medicacoesPool: string[]
  doencasCronicasPool: string[]
  pacienteSexo: string | null
  isPacienteFeminino: boolean
   
  onAlergiaSelectChange: (event: Event, index: number) => void
   
  onCirurgiaSelectChange: (event: Event, index: number) => void
   
  onMedicacaoSelectChange: (event: Event, index: number) => void
   
  onDoencaCronicaSelectChange: (event: Event, index: number) => void
}>()

const historiaPregressa = props.historiaPregressa
const alergiasPool = props.alergiasPool
const cirurgiasPool = props.cirurgiasPool
const medicacoesPool = props.medicacoesPool
const doencasCronicasPool = props.doencasCronicasPool
const pacienteSexo = props.pacienteSexo
const isPacienteFeminino = props.isPacienteFeminino

const onAlergiaSelectChange = props.onAlergiaSelectChange
const onCirurgiaSelectChange = props.onCirurgiaSelectChange
const onMedicacaoSelectChange = props.onMedicacaoSelectChange
const onDoencaCronicaSelectChange = props.onDoencaCronicaSelectChange
 
</script>
