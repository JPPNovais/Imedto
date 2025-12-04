<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import { useRoute } from 'vue-router'
import HistoriaFamiliarSection from '../components/HistoriaFamiliarSection.vue'
import HistoriaSocialSection from '../components/HistoriaSocialSection.vue'
import HistoriaPregressaSection from '../components/HistoriaPregressaSection.vue'
import ExamesRealizadosSection from '../components/ExamesRealizadosSection.vue'
import ExameFisicoSection from '../components/ExameFisicoSection.vue'
import EquipeCirurgicaSection from '../components/EquipeCirurgicaSection.vue'
import FotosPacienteSection from '../components/FotosPacienteSection.vue'
import EvolucaoPosOperatoriaSection from '../components/EvolucaoPosOperatoriaSection.vue'
import {
  alergiasDefault,
  cirurgiasDefault,
  medicacoesDefault,
  doencasCronicasDefault,
} from '../constants/medicalRecordConstants'

type ModeloProntuario = {
  id: string
  nome: string
  descricao: string | null
  estrutura: Record<string, unknown> | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()
const route = useRoute()

const estabelecimentoId = ref<string | null>(null)
const pacienteId = ref<string | null>(null)
const prontuarioId = ref<string | null>(null)
const profissionalId = ref<string | null>(null)
const pacienteSexo = ref<string | null>(null)
const isPacienteFeminino = computed(() => {
  const s = (pacienteSexo.value || '').toLowerCase().trim()
  if (!s) return false
  if (s === 'f' || s === 'feminino') return true
  return s.includes('feminino')
})
const modelos = ref<ModeloProntuario[]>([])
const selectedModeloId = ref<string>('')
const isLoading = ref(false)
const isLoadingModelos = ref(false)
const isSaving = ref(false)

type EvolucaoItem = {
  id: string
  criado_em: string
  modelo_nome: string | null
}

const evolucoes = ref<EvolucaoItem[]>([])
const secaoConteudo = reactive<Record<string, string>>({})
type AnexoItem = {
  nome: string
}

type ExameAnexo = {
  nome: string
  observacao: string
  file?: File | null
  previewUrl?: string
  tipo?: 'imagem' | 'pdf' | 'outro'
}

type ExameItem = {
  tipoExame: string
  materialExame: string
  nomeExame: string
  comentarioExame: string
  anexosImagem: ExameAnexo[]
  novoAnexoArquivo: File | null
  novoAnexoObservacao: string
}

const anexos = ref<AnexoItem[]>([])
const hasAnexos = computed(() => (anexos.value ?? []).length > 0)
const hasEvolucoes = computed(() => (evolucoes.value ?? []).length > 0)

const historiaAtual = reactive({
  historicoQueixa: '',
  procedimentos: [''] as string[],
})

const historiaPregressa = reactive({
  textoGeral: '',
  alergiaPossui: '' as '' | 'sim' | 'nao',
  alergiaDescricao: '',
  alergiasDetalhadas: [
    {
      alergia: '',
      observacao: '',
    },
  ] as { alergia: string; observacao: string }[],
  usoMedicamentos: '' as '' | 'sim' | 'nao',
  usoMedicamentosDescricao: '',
  medicacoes: [
    {
      medicamento: '',
      dose: '',
      frequencia: '',
      indicacao: '',
      observacao: '',
    },
  ] as {
    medicamento: string
    dose: string
    frequencia: string
    indicacao: string
    observacao: string
  }[],
  cirurgiasAnteriores: '' as '' | 'sim' | 'nao',
  cirurgiasDescricao: '',
  cirurgiasDetalhadas: [
    {
      cirurgia: '',
      ano: '',
      observacao: '',
    },
  ] as { cirurgia: string; ano: string; observacao: string }[],
  doencasPrevias: '' as '' | 'sim' | 'nao',
  doencasDescricao: '',
  doencasDetalhadas: [
    {
      doenca: '',
      observacao: '',
    },
  ] as { doenca: string; observacao: string }[],
  informarCicloMenstrual: '' as '' | 'sim' | 'nao',
  cicloMenarcaIdade: '',
  cicloMenopausa: '' as '' | 'sim' | 'nao',
  cicloTipo: '',
  cicloIntervaloDias: '',
  cicloDuracaoFluxoDias: '',
  cicloDum: '',
  cicloIntensidadeFluxo: '',
  cicloObservacoes: '',
  tipoCicatrizacaoNivel: '',
  tipoCicatrizacaoDescricao: '',
  usaAnticoncepcional: '' as '' | 'sim' | 'nao',
  usaAnticoncepcionalQual: '',
  usaOutroMetodo: '' as '' | 'sim' | 'nao',
  usaOutroMetodoQual: '',
  gravidaOuJaEsteve: '' as '' | 'sim' | 'nao',
  gravidaDescricao: '',
  gestacaoGpa: '',
  observacoes: '',
})

const alergiasPool = ref<string[]>([...alergiasDefault])

const cirurgiasPool = ref<string[]>([...cirurgiasDefault])

const isAlergiaModalOpen = ref(false)
const alergiaModalNome = ref('')
const alergiaModalIndex = ref<number | null>(null)

const isCirurgiaModalOpen = ref(false)
const cirurgiaModalNome = ref('')
const cirurgiaModalIndex = ref<number | null>(null)

const medicacoesPool = ref<string[]>([...medicacoesDefault])
const isMedicacaoModalOpen = ref(false)
const medicacaoModalNome = ref('')
const medicacaoModalIndex = ref<number | null>(null)

const doencasCronicasPool = ref<string[]>([...doencasCronicasDefault])
const isDoencaModalOpen = ref(false)
const doencaModalNome = ref('')
const doencaModalIndex = ref<number | null>(null)

async function loadAlergiasPool() {
  const filtros = supabase
    .from('prontuario_variaveis_pool')
    .select('nome, estabelecimento_id')
    .eq('tipo', 'alergia')

  if (estabelecimentoId.value) {
    filtros.or(
      `estabelecimento_id.is.null,estabelecimento_id.eq.${estabelecimentoId.value}`,
    )
  } else {
    filtros.is('estabelecimento_id', null)
  }

  const { data, error } = await filtros.order('nome')

  if (error) {
    console.error(error)
    return
  }

  const nomes = (data ?? []).map((row: { nome: string }) => row.nome)
  const set = new Set(alergiasDefault)
  nomes.forEach((n) => {
    if (n && !set.has(n)) {
      set.add(n)
    }
  })
  alergiasPool.value = Array.from(set)
}

async function loadCirurgiasPool() {
  const filtros = supabase
    .from('prontuario_variaveis_pool')
    .select('nome, estabelecimento_id')
    .eq('tipo', 'cirurgia_pregressa')

  if (estabelecimentoId.value) {
    filtros.or(
      `estabelecimento_id.is.null,estabelecimento_id.eq.${estabelecimentoId.value}`,
    )
  } else {
    filtros.is('estabelecimento_id', null)
  }

  const { data, error } = await filtros.order('nome')

  if (error) {
    console.error(error)
    return
  }

  const nomes = (data ?? []).map((row: { nome: string }) => row.nome)
  const set = new Set(cirurgiasDefault)
  nomes.forEach((n) => {
    if (n && !set.has(n)) {
      set.add(n)
    }
  })
  cirurgiasPool.value = Array.from(set)
}

async function loadMedicacoesPool() {
  const filtros = supabase
    .from('prontuario_variaveis_pool')
    .select('nome, estabelecimento_id')
    .eq('tipo', 'medicacao')

  if (estabelecimentoId.value) {
    filtros.or(
      `estabelecimento_id.is.null,estabelecimento_id.eq.${estabelecimentoId.value}`,
    )
  } else {
    filtros.is('estabelecimento_id', null)
  }

  const { data, error } = await filtros.order('nome')

  if (error) {
    console.error(error)
    return
  }

  const nomes = (data ?? []).map((row: { nome: string }) => row.nome)
  const set = new Set(medicacoesDefault)
  nomes.forEach((n) => {
    if (n && !set.has(n)) {
      set.add(n)
    }
  })
  medicacoesPool.value = Array.from(set)
}

async function loadDoencasCronicasPool() {
  const filtros = supabase
    .from('prontuario_variaveis_pool')
    .select('nome, estabelecimento_id')
    .eq('tipo', 'doenca_cronica')

  if (estabelecimentoId.value) {
    filtros.or(
      `estabelecimento_id.is.null,estabelecimento_id.eq.${estabelecimentoId.value}`,
    )
  } else {
    filtros.is('estabelecimento_id', null)
  }

  const { data, error } = await filtros.order('nome')

  if (error) {
    console.error(error)
    return
  }

  const nomes = (data ?? []).map((row: { nome: string }) => row.nome)
  const set = new Set(doencasCronicasDefault)
  nomes.forEach((n) => {
    if (n && !set.has(n)) {
      set.add(n)
    }
  })
  doencasCronicasPool.value = Array.from(set)
}

async function adicionarAlergiaAoPool(novaAlergia: string) {
  if (!estabelecimentoId.value) return
  const nome = novaAlergia.trim()
  if (!nome) return

  if (alergiasPool.value.includes(nome)) return

  alergiasPool.value = [...alergiasPool.value, nome].sort((a, b) =>
    a.localeCompare(b, 'pt-BR'),
  )

  const { error } = await supabase.from('prontuario_variaveis_pool').insert({
    estabelecimento_id: estabelecimentoId.value,
    tipo: 'alergia',
    nome,
  })

  if (error) {
    console.error(error)
    feedback.error('Não foi possível salvar a nova alergia.')
  }
}

async function adicionarCirurgiaAoPool(novaCirurgia: string) {
  if (!estabelecimentoId.value) return
  const nome = novaCirurgia.trim()
  if (!nome) return

  if (cirurgiasPool.value.includes(nome)) return

  cirurgiasPool.value = [...cirurgiasPool.value, nome].sort((a, b) =>
    a.localeCompare(b, 'pt-BR'),
  )

  const { error } = await supabase.from('prontuario_variaveis_pool').insert({
    estabelecimento_id: estabelecimentoId.value,
    tipo: 'cirurgia_pregressa',
    nome,
  })

  if (error) {
    console.error(error)
    feedback.error('Não foi possível salvar a nova cirurgia.')
  }
}

async function adicionarMedicacaoAoPool(novaMedicacao: string) {
  if (!estabelecimentoId.value) return
  const nome = novaMedicacao.trim()
  if (!nome) return

  if (medicacoesPool.value.includes(nome)) return

  medicacoesPool.value = [...medicacoesPool.value, nome].sort((a, b) =>
    a.localeCompare(b, 'pt-BR'),
  )

  const { error } = await supabase.from('prontuario_variaveis_pool').insert({
    estabelecimento_id: estabelecimentoId.value,
    tipo: 'medicacao',
    nome,
  })

  if (error) {
    console.error(error)
    feedback.error('Não foi possível salvar a nova medicação.')
  }
}

async function adicionarDoencaCronicaAoPool(novaDoenca: string) {
  if (!estabelecimentoId.value) return
  const nome = novaDoenca.trim()
  if (!nome) return

  if (doencasCronicasPool.value.includes(nome)) return

  doencasCronicasPool.value = [
    ...doencasCronicasPool.value,
    nome,
  ].sort((a, b) => a.localeCompare(b, 'pt-BR'))

  const { error } = await supabase.from('prontuario_variaveis_pool').insert({
    estabelecimento_id: estabelecimentoId.value,
    tipo: 'doenca_cronica',
    nome,
  })

  if (error) {
    console.error(error)
    feedback.error('Não foi possível salvar a nova doença.')
  }
}

function onAlergiaSelectChange(event: Event, index: number) {
  const target = event.target as HTMLSelectElement | null
  if (!target) return
  const value = target.value

  if (value === '__outra__') {
    alergiaModalIndex.value = index
    alergiaModalNome.value = ''
    isAlergiaModalOpen.value = true
    historiaPregressa.alergiasDetalhadas[index].alergia = ''
  } else {
    historiaPregressa.alergiasDetalhadas[index].alergia = value
  }
}

function onCirurgiaSelectChange(event: Event, index: number) {
  const target = event.target as HTMLSelectElement | null
  if (!target) return
  const value = target.value

  if (value === '__outra__') {
    cirurgiaModalIndex.value = index
    cirurgiaModalNome.value = ''
    isCirurgiaModalOpen.value = true
    historiaPregressa.cirurgiasDetalhadas[index].cirurgia = ''
  } else {
    historiaPregressa.cirurgiasDetalhadas[index].cirurgia = value
  }
}

function onMedicacaoSelectChange(event: Event, index: number) {
  const target = event.target as HTMLSelectElement | null
  if (!target) return
  const value = target.value

  if (value === '__outra__') {
    medicacaoModalIndex.value = index
    medicacaoModalNome.value = ''
    isMedicacaoModalOpen.value = true
    historiaPregressa.medicacoes[index].medicamento = ''
  } else {
    historiaPregressa.medicacoes[index].medicamento = value
  }
}

function onDoencaCronicaSelectChange(event: Event, index: number) {
  const target = event.target as HTMLSelectElement | null
  if (!target) return
  const value = target.value

  if (value === '__outra__') {
    doencaModalIndex.value = index
    doencaModalNome.value = ''
    isDoencaModalOpen.value = true
    historiaPregressa.doencasDetalhadas[index].doenca = ''
  } else {
    historiaPregressa.doencasDetalhadas[index].doenca = value
  }
}

async function salvarNovaAlergia() {
  if (alergiaModalIndex.value === null) return
  const nome = alergiaModalNome.value.trim()
  if (!nome) return

  await adicionarAlergiaAoPool(nome)
  historiaPregressa.alergiasDetalhadas[alergiaModalIndex.value].alergia =
    nome

  isAlergiaModalOpen.value = false
  alergiaModalIndex.value = null
  alergiaModalNome.value = ''
}

function fecharAlergiaModal() {
  isAlergiaModalOpen.value = false
  alergiaModalIndex.value = null
  alergiaModalNome.value = ''
}

async function salvarNovaCirurgia() {
  if (cirurgiaModalIndex.value === null) return
  const nome = cirurgiaModalNome.value.trim()
  if (!nome) return

  await adicionarCirurgiaAoPool(nome)
  historiaPregressa.cirurgiasDetalhadas[cirurgiaModalIndex.value].cirurgia =
    nome

  isCirurgiaModalOpen.value = false
  cirurgiaModalIndex.value = null
  cirurgiaModalNome.value = ''
}

function fecharCirurgiaModal() {
  isCirurgiaModalOpen.value = false
  cirurgiaModalIndex.value = null
  cirurgiaModalNome.value = ''
}

async function salvarNovaMedicacao() {
  if (medicacaoModalIndex.value === null) return
  const nome = medicacaoModalNome.value.trim()
  if (!nome) return

  await adicionarMedicacaoAoPool(nome)
  historiaPregressa.medicacoes[medicacaoModalIndex.value].medicamento = nome

  isMedicacaoModalOpen.value = false
  medicacaoModalIndex.value = null
  medicacaoModalNome.value = ''
}

function fecharMedicacaoModal() {
  isMedicacaoModalOpen.value = false
  medicacaoModalIndex.value = null
  medicacaoModalNome.value = ''
}

async function salvarNovaDoencaCronica() {
  if (doencaModalIndex.value === null) return
  const nome = doencaModalNome.value.trim()
  if (!nome) return

  await adicionarDoencaCronicaAoPool(nome)
  historiaPregressa.doencasDetalhadas[doencaModalIndex.value].doenca = nome

  isDoencaModalOpen.value = false
  doencaModalIndex.value = null
  doencaModalNome.value = ''
}

function fecharDoencaModal() {
  isDoencaModalOpen.value = false
  doencaModalIndex.value = null
  doencaModalNome.value = ''
}

const historiaFamiliar = reactive({
  historicoPai: '',
  historicoMae: '',
  parentes: [
    {
      tipo: 'Irmã',
      possui: '' as '' | 'sim' | 'nao',
      quantidade: '',
      comentario: '',
    },
    {
      tipo: 'Irmão',
      possui: '' as '' | 'sim' | 'nao',
      quantidade: '',
      comentario: '',
    },
  ] as {
    tipo: string
    possui: '' | 'sim' | 'nao'
    quantidade: string
    comentario: string
  }[],
  historicoNivel: '',
  historicoNivelDescricao: '',
  observacao: '',
})

const historiaSocial = reactive({
  estadoCivil: '',
  filhosTem: '' as '' | 'sim' | 'nao',
  filhosQuantidade: '',
  filhosIdades: '',
  filhosObservacoes: '',
  tabagismoTem: '' as '' | 'sim' | 'nao',
  tabagismoStatus: '' as
    | ''
    | 'nao_fuma'
    | 'fumante_ativo'
    | 'fumante_passivo'
    | 'ex_fumante',
  tabagismoTipos: [
    {
      tipo: '',
      quantidade: '',
      unidade: '',
      tempoQuantidade: '',
      tempoUnidade: '',
    },
  ] as {
    tipo: string
    quantidade: string
    unidade: string
    tempoQuantidade: string
    tempoUnidade: string
  }[],
  tabagismoObservacoes: '',
  etilismoTem: '' as '' | 'sim' | 'nao',
  etilismoStatus: '' as
    | ''
    | 'nao_bebe'
    | 'esporadico'
    | 'social'
    | 'moderado'
    | 'frequente'
    | 'ex_etilista',
  etilismoBebidas: [
    {
      tipo: '',
      frequencia: '',
      quantidade: '',
      unidade: '',
    },
  ] as {
    tipo: string
    frequencia: string
    quantidade: string
    unidade: string
  }[],
  etilismoObservacoes: '',
  outrasSubstanciasTem: '' as '' | 'sim' | 'nao',
  outrasSubstanciasStatus: '' as '' | 'nao' | 'uso_atual' | 'uso_previo',
  outrasSubstanciasLista: [
    {
      tipo: '',
      frequencia: '',
      observacoes: '',
    },
  ] as {
    tipo: string
    frequencia: string
    observacoes: string
  }[],
  atividadeFisicaTem: '' as '' | 'sim' | 'nao',
  atividadeFisicaNivel: '' as
    | ''
    | 'sedentario'
    | 'leve'
    | 'moderado'
    | 'intenso',
  atividadeFisicaAtividades: [
    {
      tipo: '',
      frequencia: '',
    },
  ] as {
    tipo: string
    frequencia: string
  }[],
  atividadeFisicaObservacoes: '',
  alimentacaoTipo: '',
  alimentacaoObservacoes: '',
  sonoRotinaQualidade: '',
  sonoRotinaObservacoes: '',
})

const exameFisico = reactive({
  peso: '',
  altura: '',
  ectoscopia: '' as '' | 'sim' | 'nao',
  ectoscopiaComentario: '',
  ectoscopiaDescricao: '',
  resumoPesoAlturaImcEctoscopia: '',
})

const examesRealizados = reactive({
  exames: [
    {
      tipoExame: '',
      materialExame: '',
      nomeExame: '',
      comentarioExame: '',
      anexosImagem: [] as ExameAnexo[],
      novoAnexoArquivo: null as File | null,
      novoAnexoObservacao: '',
    },
  ] as ExameItem[],
})

const equipe = reactive({
  profissionais: [
    {
      profissional: '',
      comentario: '',
    },
  ] as { profissional: string; comentario: string }[],
})

const fotosPaciente = reactive({
  anexos: [] as { nome: string; observacao: string; previewUrl?: string }[],
  novoArquivo: null as File | null,
  novaObservacao: '',
})

const evolucaoPosOperatoria = reactive({
  observacao: '',
  evolucaoPaciente: '' as '' | 'otima' | 'boa' | 'regular' | 'ruim',
  evolucaoComentario: '',
  seguindoOrientacoes: '' as '' | 'sim' | 'nao',
  orientacoesComentario: '',
  anexosImagem: [] as { nome: string; observacao: string }[],
  novoArquivo: null as File | null,
  novaObservacao: '',
})

const descricaoCirurgica = reactive({
  tipoProcedimento: '',
  dataInicioCirurgia: '',
  horaInicioCirurgia: '',
  dataFimCirurgia: '',
  horaFimCirurgia: '',
  dataAnestesia: '',
  horaAnestesia: '',
  duracaoAnestesiaTipo: 'horas' as 'horas' | 'minutos',
  duracaoAnestesiaQuantidade: 0,
  profissionais: [
    {
      profissional: '',
      funcao: '',
    },
  ] as { profissional: string; funcao: string }[],
})

const procedimentosIndicados = reactive({
  itens: [''] as string[],
})

const duracaoCirurgiaTexto = computed(() => {
  if (
    !descricaoCirurgica.dataInicioCirurgia ||
    !descricaoCirurgica.horaInicioCirurgia ||
    !descricaoCirurgica.dataFimCirurgia ||
    !descricaoCirurgica.horaFimCirurgia
  ) {
    return '00:00'
  }
  const inicio = new Date(
    `${descricaoCirurgica.dataInicioCirurgia}T${descricaoCirurgica.horaInicioCirurgia}:00`,
  )
  const fim = new Date(
    `${descricaoCirurgica.dataFimCirurgia}T${descricaoCirurgica.horaFimCirurgia}:00`,
  )
  const diffMs = fim.getTime() - inicio.getTime()
  if (!Number.isFinite(diffMs) || diffMs <= 0) return '00:00'
  const totalMin = Math.round(diffMs / 60000)
  const horas = Math.floor(totalMin / 60)
  const minutos = totalMin % 60
  return `${String(horas).padStart(2, '0')}:${String(minutos).padStart(2, '0')}`
})

const duracaoAnestesiaTexto = computed(() => {
  const qtd = descricaoCirurgica.duracaoAnestesiaQuantidade
  if (!qtd || Number.isNaN(qtd)) return '00:00'
  const totalMin =
    descricaoCirurgica.duracaoAnestesiaTipo === 'horas' ? qtd * 60 : qtd
  const horas = Math.floor(totalMin / 60)
  const minutos = totalMin % 60
  return `${String(horas).padStart(2, '0')}:${String(minutos).padStart(2, '0')}`
})

const imcValor = computed(() => {
  const peso = parseFloat(exameFisico.peso.replace(',', '.'))
  const altura = parseFloat(exameFisico.altura.replace(',', '.'))
  if (!peso || !altura || Number.isNaN(peso) || Number.isNaN(altura)) {
    return '00'
  }
  const imc = peso / (altura * altura)
  if (!Number.isFinite(imc)) return '00'
  return imc.toFixed(2)
})

function onAnexosChange(event: Event) {
  const target = event.target as HTMLInputElement | null
  if (!target?.files) return
  const files = Array.from(target.files)
  files.forEach((file) => {
    anexos.value.push({ nome: file.name })
  })
  // limpa o input para permitir selecionar o mesmo arquivo novamente, se necessário
  target.value = ''
}

function removeAnexo(index: number) {
  if (!anexos.value || index < 0 || index >= anexos.value.length) return
  anexos.value.splice(index, 1)
}

const secoesDictionary: Record<
  string,
  { key: string; label: string; placeholder: string }
> = {
  queixa: {
    key: 'queixa',
    label: 'Queixa principal (QP)',
    placeholder: 'Descreva a queixa principal do paciente...',
  },
  hda: {
    key: 'hda',
    label: 'História da doença atual (HDA)',
    placeholder: 'Detalhe a evolução da queixa, fatores relacionados, tentativas prévias...',
  },
  hpp: {
    key: 'hpp',
    label: 'História pregressa (HPP)',
    placeholder: 'Antecedentes pessoais, doenças prévias, cirurgias...',
  },
  'h-familiar': {
    key: 'h-familiar',
    label: 'História familiar',
    placeholder: 'Doenças familiares relevantes...',
  },
  'h-social': {
    key: 'h-social',
    label: 'História social e hábitos de vida',
    placeholder: 'Hábitos, profissão, uso de substâncias...',
  },
  'exame-fisico': {
    key: 'exame-fisico',
    label: 'Exame físico e sinais vitais',
    placeholder: 'Achados do exame físico e sinais vitais...',
  },
  'exames-realizados': {
    key: 'exames-realizados',
    label: 'Exames realizados',
    placeholder: 'Exames complementares realizados e resultados...',
  },
  'procedimentos-indicados': {
    key: 'procedimentos-indicados',
    label: 'Procedimentos indicados',
    placeholder: 'Procedimentos indicados ao paciente...',
  },
  'evolucao-pos-op': {
    key: 'evolucao-pos-op',
    label: 'Evolução pós-operatória',
    placeholder: 'Registre a evolução pós-operatória...',
  },
  'desc-cirurgica': {
    key: 'desc-cirurgica',
    label: 'Descrição cirúrgica',
    placeholder: 'Descrição detalhada do ato cirúrgico...',
  },
  'equipe-cirurgica': {
    key: 'equipe-cirurgica',
    label: 'Equipe cirúrgica',
    placeholder: 'Equipe envolvida no procedimento...',
  },
  'fotos-paciente': {
    key: 'fotos-paciente',
    label: 'Fotos do paciente',
    placeholder: 'Referência às fotos registradas do paciente...',
  },
  anexos: {
    key: 'anexos',
    label: 'Anexos',
    placeholder: 'Documentos, laudos ou outros anexos importantes...',
  },
  cid10: {
    key: 'cid10',
    label: 'CID-10',
    placeholder: 'Código e descrição CID-10 relevantes...',
  },
  conduta: {
    key: 'conduta',
    label: 'Conduta',
    placeholder: 'Conduta proposta, orientações e plano terapêutico...',
  },
  prescricao: {
    key: 'prescricao',
    label: 'Prescrição',
    placeholder:
      '1) Medicamento - dose - via - frequência - duração. Use uma linha por item.',
  },
  encaminhamento: {
    key: 'encaminhamento',
    label: 'Encaminhamento',
    placeholder: 'Especialidade e motivo do encaminhamento...',
  },
}

const selectedModelo = computed(() =>
  modelos.value.find((m) => m.id === selectedModeloId.value),
)

const activeSections = computed(() => {
  const modelo = selectedModelo.value
  if (!modelo?.estrutura) return []

  const estrutura = modelo.estrutura as {
    secoes?: Record<string, boolean> | undefined
    ordem?: string[] | undefined
  }

  const secoesConfig = estrutura.secoes ?? {}

  const baseKeys = Object.keys(secoesDictionary).filter(
    (key) => secoesConfig[key] === true,
  )

  if (estrutura.ordem && Array.isArray(estrutura.ordem)) {
    const ordemSet = new Set(estrutura.ordem)
    const ordered: string[] = []

    estrutura.ordem.forEach((key) => {
      if (secoesConfig[key] && key in secoesDictionary) {
        ordered.push(key)
      }
    })

    baseKeys.forEach((key) => {
      if (!ordemSet.has(key)) {
        ordered.push(key)
      }
    })

    return ordered
  }

  return baseKeys
})

const hasActiveSections = computed(
  () => (activeSections.value ?? []).length > 0,
)

watch(activeSections, (keys) => {
  keys.forEach((k) => {
    if (!(k in secaoConteudo)) {
      secaoConteudo[k] = ''
    }
  })
})

async function loadEstabelecimento() {
  if (!auth.currentUser?.id) return

  const { data, error } = await supabase
    .from('estabelecimentos')
    .select('id, nome_fantasia')
    .eq('owner_usuario_id', auth.currentUser.id)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível identificar o estabelecimento.')
    return
  }

  estabelecimentoId.value = data?.id ?? null
}

async function loadModelos() {
  if (!estabelecimentoId.value) return
  isLoadingModelos.value = true

  try {
    const { data, error } = await supabase
      .from('modelo_de_prontuario')
      .select('id, nome, descricao, estrutura')
      .eq('estabelecimento_id', estabelecimentoId.value)
      .order('nome')

    if (error) {
      console.error(error)
      feedback.error('Não foi possível carregar os modelos de prontuário.')
      return
    }

    modelos.value = (data ?? []) as ModeloProntuario[]
  } finally {
    isLoadingModelos.value = false
  }
}

async function loadProfissional() {
  if (!auth.currentUser?.id) return

  const { data, error } = await supabase
    .from('profissionais')
    .select('id')
    .eq('usuario_id', auth.currentUser.id)
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    return
  }

  profissionalId.value = data?.id ?? null
}

async function loadPacienteSexo() {
  if (!pacienteId.value) return

  const { data, error } = await supabase
    .from('pacientes')
    .select('sexo')
    .eq('id', pacienteId.value)
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    return
  }

  pacienteSexo.value = (data?.sexo as string | null) ?? null
}

async function ensureProntuario() {
  if (!estabelecimentoId.value || !pacienteId.value) return

  const { data, error } = await supabase
    .from('prontuarios')
    .select('id, modelo_de_prontuario_id')
    .eq('estabelecimento_id', estabelecimentoId.value)
    .eq('paciente_id', pacienteId.value)
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error(error)
    feedback.error('Não foi possível carregar o prontuário do paciente.')
    return
  }

  if (data?.id) {
    prontuarioId.value = data.id
    if (!selectedModeloId.value && data.modelo_de_prontuario_id) {
      selectedModeloId.value = data.modelo_de_prontuario_id
    }
    return
  }

  const { data: created, error: insertError } = await supabase
    .from('prontuarios')
    .insert({
      paciente_id: pacienteId.value,
      estabelecimento_id: estabelecimentoId.value,
      modelo_de_prontuario_id: selectedModeloId.value || null,
    })
    .select('id')
    .maybeSingle()

  if (insertError) {
    console.error(insertError)
    feedback.error('Não foi possível criar o prontuário do paciente.')
    return
  }

  prontuarioId.value = created?.id ?? null
}

async function loadEvolucoes() {
  if (!prontuarioId.value) return

  const { data, error } = await supabase
    .from('evolucao_prontuario')
    .select(
      `
      id,
      criado_em,
      modelo:modelo_de_prontuario ( nome )
    `,
    )
    .eq('prontuario_id', prontuarioId.value)
    .order('criado_em', { ascending: false })

  if (error) {
    console.error(error)
    return
  }

  evolucoes.value =
    data?.map((e: { id: string; criado_em: string; modelo?: { nome: string } }) => ({
      id: e.id,
      criado_em: e.criado_em,
      modelo_nome: e.modelo?.nome ?? null,
    })) ?? []
}

async function salvarEvolucao() {
  if (!estabelecimentoId.value || !pacienteId.value || !profissionalId.value) {
    feedback.error(
      'Não foi possível identificar estabelecimento, paciente ou profissional.',
    )
    return
  }

  if (!selectedModeloId.value) {
    feedback.error('Selecione um modelo de prontuário.')
    return
  }

  await ensureProntuario()
  if (!prontuarioId.value) return

  const secoesPayload: Record<string, unknown> = {}
  activeSections.value.forEach((key) => {
    if (key === 'anexos') {
      secoesPayload[key] = {
        arquivos: anexos.value.map((a) => ({ nome: a.nome })),
      }
    } else if (key === 'hda') {
      secoesPayload[key] = {
        historico_queixa: historiaAtual.historicoQueixa || '',
        procedimentos: historiaAtual.procedimentos
          .map((p) => p.trim())
          .filter(Boolean),
      }
    } else if (key === 'hpp') {
      secoesPayload[key] = {
        texto_geral: historiaPregressa.textoGeral || '',
        alergia_possui: historiaPregressa.alergiaPossui || null,
        alergia_descricao: historiaPregressa.alergiaDescricao || '',
        alergias_detalhadas: historiaPregressa.alergiasDetalhadas.filter(
          (item) => item.alergia.trim() || item.observacao.trim(),
        ),
        uso_medicamentos: historiaPregressa.usoMedicamentos || null,
        uso_medicamentos_descricao:
          historiaPregressa.usoMedicamentosDescricao || '',
        medicacoes_em_uso: historiaPregressa.medicacoes.filter(
          (item) =>
            item.medicamento.trim() ||
            item.dose.trim() ||
            item.frequencia.trim() ||
            item.indicacao.trim() ||
            item.observacao.trim(),
        ),
        cirurgias_anteriores: historiaPregressa.cirurgiasAnteriores || null,
        cirurgias_descricao: historiaPregressa.cirurgiasDescricao || '',
        cirurgias_detalhadas: historiaPregressa.cirurgiasDetalhadas.filter(
          (item) =>
            item.cirurgia.trim() ||
            item.ano.trim() ||
            item.observacao.trim(),
        ),
        doencas_previas: historiaPregressa.doencasPrevias || null,
        doencas_descricao: historiaPregressa.doencasDescricao || '',
        doencas_detalhadas: historiaPregressa.doencasDetalhadas.filter(
          (item) => item.doenca.trim() || item.observacao.trim(),
        ),
        ciclo_menstrual: {
          informar: historiaPregressa.informarCicloMenstrual || null,
          menarca_idade: historiaPregressa.cicloMenarcaIdade || '',
          menopausa: historiaPregressa.cicloMenopausa || null,
          ciclo_tipo: historiaPregressa.cicloTipo || '',
          intervalo_dias: historiaPregressa.cicloIntervaloDias || '',
          duracao_fluxo_dias: historiaPregressa.cicloDuracaoFluxoDias || '',
          dum: historiaPregressa.cicloDum || '',
          intensidade_fluxo: historiaPregressa.cicloIntensidadeFluxo || '',
          observacoes: historiaPregressa.cicloObservacoes || '',
        },
        tipo_cicatrizacao_nivel: historiaPregressa.tipoCicatrizacaoNivel || '',
        tipo_cicatrizacao_descricao:
          historiaPregressa.tipoCicatrizacaoDescricao || '',
        usa_anticoncepcional: historiaPregressa.usaAnticoncepcional || null,
        usa_anticoncepcional_qual:
          historiaPregressa.usaAnticoncepcionalQual || '',
        usa_outro_metodo: historiaPregressa.usaOutroMetodo || null,
        usa_outro_metodo_qual: historiaPregressa.usaOutroMetodoQual || '',
        gravida_ou_ja_esteve: historiaPregressa.gravidaOuJaEsteve || null,
        gravida_descricao: historiaPregressa.gravidaDescricao || '',
        gestacao_gpa: historiaPregressa.gestacaoGpa || '',
        observacoes: historiaPregressa.observacoes || '',
      }
    } else if (key === 'h-familiar') {
      secoesPayload[key] = {
        historico_pai: historiaFamiliar.historicoPai || '',
        historico_mae: historiaFamiliar.historicoMae || '',
        parentes: historiaFamiliar.parentes.filter(
          (p) =>
            p.tipo.trim() ||
            p.quantidade.trim() ||
            p.comentario.trim() ||
            !!p.possui,
        ),
        historico_nivel: historiaFamiliar.historicoNivel || '',
        historico_nivel_descricao:
          historiaFamiliar.historicoNivelDescricao || '',
        observacao: historiaFamiliar.observacao || '',
      }
    } else if (key === 'h-social') {
      secoesPayload[key] = {
        estado_civil: historiaSocial.estadoCivil || '',
        filhos_tem: historiaSocial.filhosTem || null,
        filhos_quantidade: historiaSocial.filhosQuantidade || '',
        filhos_idades: historiaSocial.filhosIdades || '',
        filhos_observacoes: historiaSocial.filhosObservacoes || '',
        tabagismo_status: historiaSocial.tabagismoStatus || null,
        tabagismo_tipos: historiaSocial.tabagismoTipos.filter(
          (t) =>
            t.tipo.trim() ||
            t.quantidade.trim() ||
            t.unidade.trim() ||
            t.tempoQuantidade.trim() ||
            t.tempoUnidade.trim(),
        ),
        tabagismo_observacoes: historiaSocial.tabagismoObservacoes || '',
        etilismo_status: historiaSocial.etilismoStatus || null,
        etilismo_bebidas: historiaSocial.etilismoBebidas.filter(
          (b) =>
            b.tipo.trim() ||
            b.frequencia.trim() ||
            b.quantidade.trim() ||
            b.unidade.trim(),
        ),
        etilismo_observacoes: historiaSocial.etilismoObservacoes || '',
        outras_substancias_status:
          historiaSocial.outrasSubstanciasStatus || null,
        outras_substancias_lista:
          historiaSocial.outrasSubstanciasLista.filter(
            (s) =>
              s.tipo.trim() ||
              s.frequencia.trim() ||
              s.observacoes.trim(),
          ),
        atividade_fisica_nivel: historiaSocial.atividadeFisicaNivel || null,
        atividade_fisica_atividades:
          historiaSocial.atividadeFisicaAtividades.filter(
            (a) => a.tipo.trim() || a.frequencia.trim(),
          ),
        atividade_fisica_observacoes:
          historiaSocial.atividadeFisicaObservacoes || '',
        alimentacao_tipo: historiaSocial.alimentacaoTipo || '',
        alimentacao_observacoes: historiaSocial.alimentacaoObservacoes || '',
        sono_rotina_qualidade: historiaSocial.sonoRotinaQualidade || '',
        sono_rotina_observacoes:
          historiaSocial.sonoRotinaObservacoes || '',
      }
    } else if (key === 'exame-fisico') {
      secoesPayload[key] = {
        peso: exameFisico.peso || '',
        altura: exameFisico.altura || '',
        imc: imcValor.value,
        ectoscopia: exameFisico.ectoscopia || null,
        ectoscopia_comentario: exameFisico.ectoscopiaComentario || '',
        ectoscopia_descricao: exameFisico.ectoscopiaDescricao || '',
        resumo_peso_altura_imc_ectoscopia:
          exameFisico.resumoPesoAlturaImcEctoscopia || '',
      }
    } else if (key === 'exames-realizados') {
      secoesPayload[key] = {
        exames: examesRealizados.exames
          .filter(
            (exame) =>
              exame.tipoExame.trim() ||
              exame.materialExame.trim() ||
              exame.nomeExame.trim() ||
              exame.comentarioExame.trim() ||
              (exame.anexosImagem && exame.anexosImagem.length > 0),
          )
          .map((exame) => ({
            tipo_exame: exame.tipoExame || '',
            material_exame: exame.materialExame || '',
            nome_exame: exame.nomeExame || '',
            comentario_exame: exame.comentarioExame || '',
            anexos_imagem:
              exame.anexosImagem?.map((anexo) => ({
                nome: anexo.nome,
                observacao: anexo.observacao,
              })) ?? [],
          })),
      }
    } else if (key === 'equipe-cirurgica') {
      secoesPayload[key] = {
        profissionais: equipe.profissionais.filter(
          (p) => p.profissional.trim() || p.comentario.trim(),
        ),
      }
    } else if (key === 'fotos-paciente') {
      secoesPayload[key] = {
        anexos:
          fotosPaciente.anexos?.map((anexo) => ({
            nome: anexo.nome,
            observacao: anexo.observacao,
          })) ?? [],
      }
    } else if (key === 'evolucao-pos-op') {
      secoesPayload[key] = {
        observacao: evolucaoPosOperatoria.observacao || '',
        evolucao_paciente: evolucaoPosOperatoria.evolucaoPaciente || null,
        evolucao_comentario: evolucaoPosOperatoria.evolucaoComentario || '',
        seguindo_orientacoes:
          evolucaoPosOperatoria.seguindoOrientacoes || null,
        orientacoes_comentario:
          evolucaoPosOperatoria.orientacoesComentario || '',
        anexos_imagem: evolucaoPosOperatoria.anexosImagem ?? [],
      }
    } else if (key === 'desc-cirurgica') {
      secoesPayload[key] = {
        tipo_procedimento: descricaoCirurgica.tipoProcedimento || '',
        data_inicio_cirurgia: descricaoCirurgica.dataInicioCirurgia || '',
        hora_inicio_cirurgia: descricaoCirurgica.horaInicioCirurgia || '',
        data_fim_cirurgia: descricaoCirurgica.dataFimCirurgia || '',
        hora_fim_cirurgia: descricaoCirurgica.horaFimCirurgia || '',
        data_anestesia: descricaoCirurgica.dataAnestesia || '',
        hora_anestesia: descricaoCirurgica.horaAnestesia || '',
        duracao_anestesia_tipo: descricaoCirurgica.duracaoAnestesiaTipo,
        duracao_anestesia_quantidade:
          descricaoCirurgica.duracaoAnestesiaQuantidade,
        duracao_cirurgia: duracaoCirurgiaTexto.value,
        duracao_anestesia: duracaoAnestesiaTexto.value,
        profissionais:
          descricaoCirurgica.profissionais.filter(
            (p) => p.profissional.trim() || p.funcao.trim(),
          ) ?? [],
      }
    } else if (key === 'procedimentos-indicados') {
      secoesPayload[key] = {
        procedimentos:
          procedimentosIndicados.itens
            .map((p) => p.trim())
            .filter((p) => p.length > 0) ?? [],
      }
    } else {
      secoesPayload[key] = {
        texto: secaoConteudo[key] || '',
      }
    }
  })

  const conteudo = {
    secoes: secoesPayload,
  }

  isSaving.value = true
  try {
    const eventoId =
      typeof route.query.eventoId === 'string'
        ? route.query.eventoId
        : null

    const { error } = await supabase
      .from('evolucao_prontuario')
      .insert({
        prontuario_id: prontuarioId.value,
        estabelecimento_id: estabelecimentoId.value,
        paciente_id: pacienteId.value,
        profissional_id: profissionalId.value,
        evento_de_agendamento_id: eventoId,
        modelo_de_prontuario_id: selectedModeloId.value,
        conteudo,
      })

    if (error) {
      console.error(error)
      feedback.error('Não foi possível salvar a evolução do prontuário.')
      return
    }

    feedback.success('Evolução do prontuário salva com sucesso.')

    activeSections.value.forEach((k) => {
      secaoConteudo[k] = ''
    })
    anexos.value = []
    historiaAtual.historicoQueixa = ''
    historiaAtual.procedimentos = ['']
    historiaPregressa.textoGeral = ''
    historiaPregressa.alergiaPossui = ''
    historiaPregressa.alergiaDescricao = ''
    historiaPregressa.alergiasDetalhadas = [
      { alergia: '', observacao: '' },
    ]
    historiaPregressa.usoMedicamentos = ''
    historiaPregressa.usoMedicamentosDescricao = ''
    historiaPregressa.cirurgiasAnteriores = ''
    historiaPregressa.cirurgiasDescricao = ''
    historiaPregressa.cirurgiasDetalhadas = [
      { cirurgia: '', ano: '', observacao: '' },
    ]
    historiaPregressa.doencasPrevias = ''
    historiaPregressa.doencasDescricao = ''
    historiaPregressa.doencasDetalhadas = [
      { doenca: '', observacao: '' },
    ]
    historiaPregressa.informarCicloMenstrual = ''
    historiaPregressa.cicloMenarcaIdade = ''
    historiaPregressa.cicloMenopausa = ''
    historiaPregressa.cicloTipo = ''
    historiaPregressa.cicloIntervaloDias = ''
    historiaPregressa.cicloDuracaoFluxoDias = ''
    historiaPregressa.cicloDum = ''
    historiaPregressa.cicloIntensidadeFluxo = ''
    historiaPregressa.cicloObservacoes = ''
    historiaPregressa.tipoCicatrizacaoNivel = ''
    historiaPregressa.tipoCicatrizacaoDescricao = ''
    historiaPregressa.usaAnticoncepcional = ''
    historiaPregressa.usaAnticoncepcionalQual = ''
    historiaPregressa.usaOutroMetodo = ''
    historiaPregressa.usaOutroMetodoQual = ''
    historiaPregressa.gravidaOuJaEsteve = ''
    historiaPregressa.gravidaDescricao = ''
    historiaPregressa.gestacaoGpa = ''
    historiaPregressa.observacoes = ''
    historiaFamiliar.historicoPai = ''
    historiaFamiliar.historicoMae = ''
    historiaFamiliar.parentes = [
      {
        tipo: 'Irmã',
        possui: '',
        quantidade: '',
        comentario: '',
      },
      {
        tipo: 'Irmão',
        possui: '',
        quantidade: '',
        comentario: '',
      },
    ]
    historiaFamiliar.historicoNivel = ''
    historiaFamiliar.historicoNivelDescricao = ''
    historiaFamiliar.observacao = ''
    historiaSocial.estadoCivil = ''
    historiaSocial.filhosTem = ''
    historiaSocial.filhosQuantidade = ''
    historiaSocial.filhosIdades = ''
    historiaSocial.filhosObservacoes = ''
    historiaSocial.tabagismoTem = ''
    historiaSocial.tabagismoStatus = ''
    historiaSocial.tabagismoTipos = [
      {
        tipo: '',
        quantidade: '',
        unidade: '',
        tempoQuantidade: '',
        tempoUnidade: '',
      },
    ]
    historiaSocial.tabagismoObservacoes = ''
    historiaSocial.etilismoTem = ''
    historiaSocial.etilismoStatus = ''
    historiaSocial.etilismoBebidas = [
      {
        tipo: '',
        frequencia: '',
        quantidade: '',
        unidade: '',
      },
    ]
    historiaSocial.etilismoObservacoes = ''
    historiaSocial.outrasSubstanciasTem = ''
    historiaSocial.outrasSubstanciasStatus = ''
    historiaSocial.outrasSubstanciasLista = [
      {
        tipo: '',
        frequencia: '',
        observacoes: '',
      },
    ]
    historiaSocial.atividadeFisicaTem = ''
    historiaSocial.atividadeFisicaNivel = ''
    historiaSocial.atividadeFisicaAtividades = [
      {
        tipo: '',
        frequencia: '',
      },
    ]
    historiaSocial.atividadeFisicaObservacoes = ''
    historiaSocial.alimentacaoTipo = ''
    historiaSocial.alimentacaoObservacoes = ''
    historiaSocial.sonoRotinaQualidade = ''
    historiaSocial.sonoRotinaObservacoes = ''
    exameFisico.peso = ''
    exameFisico.altura = ''
    exameFisico.ectoscopia = ''
    exameFisico.ectoscopiaComentario = ''
    exameFisico.ectoscopiaDescricao = ''
    exameFisico.resumoPesoAlturaImcEctoscopia = ''
    examesRealizados.exames = [
      {
        tipoExame: '',
        materialExame: '',
        nomeExame: '',
        comentarioExame: '',
        anexosImagem: [],
        novoAnexoArquivo: null,
        novoAnexoObservacao: '',
      },
    ]
    equipe.profissionais = [
      {
        profissional: '',
        comentario: '',
      },
    ]
    fotosPaciente.anexos = []
    fotosPaciente.novoArquivo = null
    fotosPaciente.novaObservacao = ''
    evolucaoPosOperatoria.observacao = ''
    evolucaoPosOperatoria.evolucaoPaciente = ''
    evolucaoPosOperatoria.evolucaoComentario = ''
    evolucaoPosOperatoria.seguindoOrientacoes = ''
    evolucaoPosOperatoria.orientacoesComentario = ''
    evolucaoPosOperatoria.anexosImagem = []
    evolucaoPosOperatoria.novoArquivo = null
    evolucaoPosOperatoria.novaObservacao = ''
    descricaoCirurgica.tipoProcedimento = ''
    descricaoCirurgica.dataInicioCirurgia = ''
    descricaoCirurgica.horaInicioCirurgia = ''
    descricaoCirurgica.dataFimCirurgia = ''
    descricaoCirurgica.horaFimCirurgia = ''
    descricaoCirurgica.dataAnestesia = ''
    descricaoCirurgica.horaAnestesia = ''
    descricaoCirurgica.duracaoAnestesiaTipo = 'horas'
    descricaoCirurgica.duracaoAnestesiaQuantidade = 0
    descricaoCirurgica.profissionais = [
      {
        profissional: '',
        funcao: '',
      },
    ]
    procedimentosIndicados.itens = ['']

    await loadEvolucoes()
  } finally {
    isSaving.value = false
  }
}

onMounted(async () => {
  isLoading.value = true
  try {
    const pId = route.params.pacienteId
    if (typeof pId === 'string') {
      pacienteId.value = pId
    }

    await loadEstabelecimento()
    if (!estabelecimentoId.value) return
    await loadProfissional()
    if (pacienteId.value) {
      await loadPacienteSexo()
    }
    await loadModelos()
    await Promise.all([
      loadAlergiasPool(),
      loadCirurgiasPool(),
      loadMedicacoesPool(),
      loadDoencasCronicasPool(),
    ])
    if (pacienteId.value) {
      await ensureProntuario()
      await loadEvolucoes()
    }
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Prontuário
        </h1>
        <p class="text-sm text-gray-500">
          Selecione um modelo de prontuário para visualizar as seções que serão
          utilizadas na evolução.
        </p>
      </div>
    </header>

    <div v-if="isLoading" class="text-xs text-gray-400">
      Carregando dados...
    </div>

    <div v-else-if="!estabelecimentoId" class="text-sm text-gray-500">
      Não foi possível identificar um estabelecimento vinculado ao seu usuário.
    </div>

    <div
      v-else
      class="bg-white rounded-xl shadow-sm border border-gray-100 p-6"
    >
      <div class="mb-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div class="flex-1">
          <label class="block text-xs font-semibold text-gray-700 mb-1">
            Modelo de prontuário
          </label>
          <select
            v-model="selectedModeloId"
            class="form-input text-xs max-w-xs"
          >
            <option value="">
              Selecione um modelo
            </option>
            <option
              v-for="modelo in modelos"
              :key="modelo.id"
              :value="modelo.id"
            >
              {{ modelo.nome }}
            </option>
          </select>
          <p
            v-if="selectedModelo && selectedModelo.descricao"
            class="mt-1 text-[11px] text-gray-500"
          >
            {{ selectedModelo.descricao }}
          </p>
        </div>
      </div>

      <div v-if="isLoadingModelos" class="text-xs text-gray-400">
        Carregando modelos...
      </div>

      <div
        v-else-if="!pacienteId"
        class="text-sm text-gray-500"
      >
        Nenhum paciente foi selecionado. Acesse o prontuário a partir da ficha
        do paciente ou da agenda.
      </div>

      <div v-else-if="!selectedModeloId" class="text-sm text-gray-500">
        Selecione um modelo de prontuário para exibir as seções.
      </div>

      <div
        v-else-if="!hasActiveSections"
        class="text-sm text-gray-500"
      >
        O modelo selecionado ainda não possui seções configuradas. Ajuste a
        configuração do modelo ou escolha outro.
      </div>

      <div
        v-else
        class="mt-4 grid grid-cols-1 gap-4"
      >
        <div
          v-for="secaoKey in activeSections"
          :key="secaoKey"
          class="border border-gray-100 rounded-lg p-4 bg-gray-50"
        >
          <h3 class="text-sm font-semibold text-primary-700 mb-2">
            {{ secoesDictionary[secaoKey]?.label || secaoKey }}
          </h3>
          <template v-if="secaoKey === 'anexos'">
            <input
              type="file"
              multiple
              class="text-xs mb-2"
              @change="onAnexosChange"
            />
            <div v-if="!hasAnexos" class="text-[11px] text-gray-500">
              Nenhum arquivo adicionado. Selecione arquivos para anexar ao
              prontuário.
            </div>
            <ul
              v-else
              class="text-[11px] text-gray-700 space-y-1"
            >
              <li
                v-for="(anexo, index) in anexos"
                :key="`${anexo.nome}-${index}`"
                class="flex items-center justify-between"
              >
                <span class="truncate max-w-[180px]">
                  {{ anexo.nome }}
                </span>
                <button
                  type="button"
                  class="text-[10px] text-red-500 hover:underline"
                  @click="removeAnexo(index)"
                >
                  Remover
                </button>
              </li>
            </ul>
          </template>
          <template v-else-if="secaoKey === 'hda'">
            <div class="space-y-4">
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Histórico da queixa
                </label>
                <textarea
                  v-model="historiaAtual.historicoQueixa"
                  class="form-input text-xs min-h-[120px] resize-y"
                  placeholder="Digite o histórico da(s) queixa(s) do paciente..."
                />
              </div>
              <div class="space-y-3">
                <div
                  v-for="(proc, index) in historiaAtual.procedimentos"
                  :key="index"
                >
                  <label class="block text-xs font-semibold text-gray-700 mb-1">
                    Procedimento desejado
                    <span v-if="historiaAtual.procedimentos.length > 1">
                      #{{ index + 1 }}
                    </span>
                  </label>
                  <input
                    v-model="historiaAtual.procedimentos[index]"
                    class="form-input text-xs"
                    placeholder="Digite o procedimento desejado"
                    type="text"
                  />
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
          </template>
          <template v-else-if="secaoKey === 'h-familiar'">
            <HistoriaFamiliarSection :historiaFamiliar="historiaFamiliar" />
          </template>
           <template v-else-if="secaoKey === 'h-social'">
            <HistoriaSocialSection :historiaSocial="historiaSocial" />
          </template>
          <template v-else-if="secaoKey === 'hpp'">
            <HistoriaPregressaSection
              :historiaPregressa="historiaPregressa"
              :alergiasPool="alergiasPool"
              :cirurgiasPool="cirurgiasPool"
              :medicacoesPool="medicacoesPool"
              :doencasCronicasPool="doencasCronicasPool"
              :pacienteSexo="pacienteSexo"
              :isPacienteFeminino="isPacienteFeminino"
              :onAlergiaSelectChange="onAlergiaSelectChange"
              :onCirurgiaSelectChange="onCirurgiaSelectChange"
              :onMedicacaoSelectChange="onMedicacaoSelectChange"
              :onDoencaCronicaSelectChange="onDoencaCronicaSelectChange"
            />
          </template>
          <template v-else-if="secaoKey === 'exame-fisico'">
            <ExameFisicoSection
              :exameFisico="exameFisico"
              :imcValor="imcValor"
            />
          </template>
          <template v-else-if="secaoKey === 'equipe-cirurgica'">
            <EquipeCirurgicaSection
              :equipe="equipe"
              :profissionaisOpcoes="['Cirurgião', 'Auxiliar', 'Anestesiologista', 'Enfermeiro', 'Outro profissional']"
            />
          </template>
          <template v-else-if="secaoKey === 'fotos-paciente'">
            <FotosPacienteSection :fotosPaciente="fotosPaciente" />
          </template>
          <template v-else-if="secaoKey === 'evolucao-pos-op'">
            <EvolucaoPosOperatoriaSection
              :evolucaoPosOperatoria="evolucaoPosOperatoria"
            />
          </template>
          <template v-else-if="secaoKey === 'procedimentos-indicados'">
            <div class="space-y-3">
              <div
                v-for="(proc, index) in procedimentosIndicados.itens"
                :key="index"
                class="grid grid-cols-1 md:grid-cols-[1.4fr,auto] gap-2 items-center"
              >
                <select
                  v-model="procedimentosIndicados.itens[index]"
                  class="form-input text-xs"
                >
                  <option value="">
                    Selecione o procedimento indicado
                  </option>
                  <option value="procedimento_a">
                    Procedimento A
                  </option>
                  <option value="procedimento_b">
                    Procedimento B
                  </option>
                  <option value="procedimento_c">
                    Procedimento C
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
          <template v-else-if="secaoKey === 'exames-realizados'">
            <ExamesRealizadosSection :examesRealizados="examesRealizados" />
          </template>
          <template v-else>
            <textarea
              v-model="secaoConteudo[secaoKey]"
              class="form-input text-xs min-h-[96px] resize-y"
              :placeholder="secoesDictionary[secaoKey]?.placeholder || ''"
            />
          </template>
        </div>

        <div class="flex justify-end">
          <button
            type="button"
            class="btn-primary max-w-xs text-xs py-2 disabled:opacity-60 disabled:cursor-not-allowed"
            :disabled="isSaving"
            @click="salvarEvolucao"
          >
            {{ isSaving ? 'Salvando evolução...' : 'Salvar evolução' }}
          </button>
        </div>

        <div v-if="hasEvolucoes" class="mt-6 border-t border-gray-100 pt-4">
          <h2 class="text-sm font-semibold text-primary-700 mb-3">
            Evoluções anteriores
          </h2>
          <ul class="space-y-2 text-xs text-gray-600">
            <li
              v-for="evo in evolucoes"
              :key="evo.id"
              class="flex items-center justify-between"
            >
              <span>
                {{
                  new Date(evo.criado_em).toLocaleString('pt-BR', {
                    dateStyle: 'short',
                    timeStyle: 'short',
                  })
                }}
              </span>
              <span class="text-[11px] text-gray-500">
                {{ evo.modelo_nome || 'Modelo não informado' }}
              </span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </section>
  <div
    v-if="isAlergiaModalOpen"
    class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
  >
    <div class="w-full max-w-sm bg-white rounded-2xl shadow-lg p-5">
      <h2 class="text-sm font-semibold text-primary-700 mb-2">
        Nova alergia
      </h2>
      <p class="text-xs text-gray-500 mb-3">
        Digite o nome da nova alergia. Ela ficará disponível apenas neste estabelecimento.
      </p>
      <input
        v-model="alergiaModalNome"
        class="form-input text-xs mb-4"
        placeholder="Ex.: Dipirona"
        type="text"
      />
      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="text-xs text-gray-500 underline"
          @click="fecharAlergiaModal"
        >
          Cancelar
        </button>
        <button
          type="button"
          class="btn-primary text-xs py-1.5 px-3 disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="!alergiaModalNome.trim()"
          @click="salvarNovaAlergia"
        >
          Salvar
        </button>
      </div>
    </div>
  </div>
  <div
    v-if="isCirurgiaModalOpen"
    class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
  >
    <div class="w-full max-w-sm bg-white rounded-2xl shadow-lg p-5">
      <h2 class="text-sm font-semibold text-primary-700 mb-2">
        Nova cirurgia
      </h2>
      <p class="text-xs text-gray-500 mb-3">
        Digite o nome da nova cirurgia. Ela ficará disponível apenas neste estabelecimento.
      </p>
      <input
        v-model="cirurgiaModalNome"
        class="form-input text-xs mb-4"
        placeholder="Ex.: Colecistectomia laparoscópica"
        type="text"
      />
      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="text-xs text-gray-500 underline"
          @click="fecharCirurgiaModal"
        >
          Cancelar
        </button>
        <button
          type="button"
          class="btn-primary text-xs py-1.5 px-3 disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="!cirurgiaModalNome.trim()"
          @click="salvarNovaCirurgia"
        >
          Salvar
        </button>
      </div>
    </div>
  </div>
  <div
    v-if="isMedicacaoModalOpen"
    class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
  >
    <div class="w-full max-w-sm bg-white rounded-2xl shadow-lg p-5">
      <h2 class="text-sm font-semibold text-primary-700 mb-2">
        Nova medicação
      </h2>
      <p class="text-xs text-gray-500 mb-3">
        Digite o nome da nova medicação. Ela ficará disponível apenas neste estabelecimento.
      </p>
      <input
        v-model="medicacaoModalNome"
        class="form-input text-xs mb-4"
        placeholder="Ex.: Losartana 50mg"
        type="text"
      />
      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="text-xs text-gray-500 underline"
          @click="fecharMedicacaoModal"
        >
          Cancelar
        </button>
        <button
          type="button"
          class="btn-primary text-xs py-1.5 px-3 disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="!medicacaoModalNome.trim()"
          @click="salvarNovaMedicacao"
        >
          Salvar
        </button>
      </div>
    </div>
  </div>
  <div
    v-if="isDoencaModalOpen"
    class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 px-4"
  >
    <div class="w-full max-w-sm bg-white rounded-2xl shadow-lg p-5">
      <h2 class="text-sm font-semibold text-primary-700 mb-2">
        Nova doença crônica / comorbidade
      </h2>
      <p class="text-xs text-gray-500 mb-3">
        Digite o nome da nova doença. Ela ficará disponível apenas neste estabelecimento.
      </p>
      <input
        v-model="doencaModalNome"
        class="form-input text-xs mb-4"
        placeholder="Ex.: Hipertensão arterial sistêmica"
        type="text"
      />
      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="text-xs text-gray-500 underline"
          @click="fecharDoencaModal"
        >
          Cancelar
        </button>
        <button
          type="button"
          class="btn-primary text-xs py-1.5 px-3 disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="!doencaModalNome.trim()"
          @click="salvarNovaDoencaCronica"
        >
          Salvar
        </button>
      </div>
    </div>
  </div>
</template>
