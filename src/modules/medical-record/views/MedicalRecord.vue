<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'
import { useRoute } from 'vue-router'

type ModeloProntuario = {
  id: string
  nome: string
  descricao: string | null
  estrutura: Record<string, any> | null
}

const auth = useAuthStore()
const feedback = useFeedbackStore()
const route = useRoute()

const estabelecimentoId = ref<string | null>(null)
const pacienteId = ref<string | null>(null)
const prontuarioId = ref<string | null>(null)
const profissionalId = ref<string | null>(null)
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

const alergiasDefault = [
  'Dipirona',
  'AAS (Ácido acetilsalicílico)',
  'Ibuprofeno',
  'Diclofenaco',
  'Penicilina',
  'Amoxicilina',
  'Cefalosporinas',
  'Quinolonas',
  'Contraste iodado',
  'Látex',
  'Anestésicos locais',
]

const alergiasPool = ref<string[]>([...alergiasDefault])

const cirurgiasDefault = [
  'Apendicectomia',
  'Colecistectomia',
  'Cesárea',
  'Histerectomia',
  'Cirurgia bariátrica',
  'Herniorrafia inguinal',
  'Artroplastia de quadril/joelho',
]

const cirurgiasPool = ref<string[]>([...cirurgiasDefault])

const isAlergiaModalOpen = ref(false)
const alergiaModalNome = ref('')
const alergiaModalIndex = ref<number | null>(null)

const isCirurgiaModalOpen = ref(false)
const cirurgiaModalNome = ref('')
const cirurgiaModalIndex = ref<number | null>(null)

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
  tabagismo: '' as '' | 'sim' | 'nao',
  tabagismoComentario: '',
  etilismo: '' as '' | 'sim' | 'nao',
  etilismoComentario: '',
  outrasSubstancias: '' as '' | 'sim' | 'nao',
  outrasSubstanciasComentario: '',
  atividadeFisica: '' as '' | 'sim' | 'nao',
  atividadeFisicaComentario: '',
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
  tipoExame: '',
  materialExame: '',
  nomeExame: '',
  comentarioExame: '',
  anexosImagem: [] as { nome: string; observacao: string }[],
  novoAnexoArquivo: null as File | null,
  novoAnexoObservacao: '',
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
  anexos: [] as { nome: string; observacao: string }[],
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
    data?.map((e: any) => ({
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

  const secoesPayload: Record<string, any> = {}
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
        tabagismo: historiaSocial.tabagismo || null,
        tabagismo_comentario: historiaSocial.tabagismoComentario || '',
        etilismo: historiaSocial.etilismo || null,
        etilismo_comentario: historiaSocial.etilismoComentario || '',
        outras_substancias: historiaSocial.outrasSubstancias || null,
        outras_substancias_comentario:
          historiaSocial.outrasSubstanciasComentario || '',
        atividade_fisica: historiaSocial.atividadeFisica || null,
        atividade_fisica_comentario:
          historiaSocial.atividadeFisicaComentario || '',
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
        tipo_exame: examesRealizados.tipoExame || '',
        material_exame: examesRealizados.materialExame || '',
        nome_exame: examesRealizados.nomeExame || '',
        comentario_exame: examesRealizados.comentarioExame || '',
        anexos_imagem: examesRealizados.anexosImagem ?? [],
      }
    } else if (key === 'equipe-cirurgica') {
      secoesPayload[key] = {
        profissionais: equipe.profissionais.filter(
          (p) => p.profissional.trim() || p.comentario.trim(),
        ),
      }
    } else if (key === 'fotos-paciente') {
      secoesPayload[key] = {
        anexos: fotosPaciente.anexos ?? [],
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
    historiaSocial.tabagismo = ''
    historiaSocial.tabagismoComentario = ''
    historiaSocial.etilismo = ''
    historiaSocial.etilismoComentario = ''
    historiaSocial.outrasSubstancias = ''
    historiaSocial.outrasSubstanciasComentario = ''
    historiaSocial.atividadeFisica = ''
    historiaSocial.atividadeFisicaComentario = ''
    exameFisico.peso = ''
    exameFisico.altura = ''
    exameFisico.ectoscopia = ''
    exameFisico.ectoscopiaComentario = ''
    exameFisico.ectoscopiaDescricao = ''
    exameFisico.resumoPesoAlturaImcEctoscopia = ''
    examesRealizados.tipoExame = ''
    examesRealizados.materialExame = ''
    examesRealizados.nomeExame = ''
    examesRealizados.comentarioExame = ''
    examesRealizados.anexosImagem = []
    examesRealizados.novoAnexoArquivo = null
    examesRealizados.novoAnexoObservacao = ''
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
    await loadModelos()
    await loadAlergiasPool()
    await loadCirurgiasPool()
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
          <template v-else-if="secaoKey === 'h-social'">
            <div class="space-y-3">
              <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
                <div class="flex items-center gap-4 text-xs">
                  <span class="font-semibold text-gray-700">
                    Tabagismo?
                  </span>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.tabagismo"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="sim"
                    />
                    <span>Sim</span>
                  </label>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.tabagismo"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="nao"
                    />
                    <span>Não</span>
                  </label>
                </div>
                <input
                  v-model="historiaSocial.tabagismoComentario"
                  class="form-input text-xs"
                  placeholder="Comentário"
                  type="text"
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
                <div class="flex items-center gap-4 text-xs">
                  <span class="font-semibold text-gray-700">
                    Etilismo?
                  </span>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.etilismo"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="sim"
                    />
                    <span>Sim</span>
                  </label>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.etilismo"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="nao"
                    />
                    <span>Não</span>
                  </label>
                </div>
                <input
                  v-model="historiaSocial.etilismoComentario"
                  class="form-input text-xs"
                  placeholder="Comentário"
                  type="text"
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
                <div class="flex items-center gap-4 text-xs">
                  <span class="font-semibold text-gray-700">
                    Outro tipo de substância?
                  </span>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.outrasSubstancias"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="sim"
                    />
                    <span>Sim</span>
                  </label>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.outrasSubstancias"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="nao"
                    />
                    <span>Não</span>
                  </label>
                </div>
                <input
                  v-model="historiaSocial.outrasSubstanciasComentario"
                  class="form-input text-xs"
                  placeholder="Comentário"
                  type="text"
                />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.2fr] gap-3 items-center">
                <div class="flex items-center gap-4 text-xs">
                  <span class="font-semibold text-gray-700">
                    Prática atividade física?
                  </span>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.atividadeFisica"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="sim"
                    />
                    <span>Sim</span>
                  </label>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="historiaSocial.atividadeFisica"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="nao"
                    />
                    <span>Não</span>
                  </label>
                </div>
                <input
                  v-model="historiaSocial.atividadeFisicaComentario"
                  class="form-input text-xs"
                  placeholder="Comentário"
                  type="text"
                />
              </div>
            </div>
          </template>
          <template v-else-if="secaoKey === 'hpp'">
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
                        @change="onAlergiaSelectChange($event, index)"
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

                <div class="grid grid-cols-1 md:grid-cols-[0.8fr,1.4fr] gap-3 items-center">
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
                  <input
                    v-model="historiaPregressa.usoMedicamentosDescricao"
                    class="form-input text-xs"
                    placeholder="Digite qual o(s) medicamento(s)"
                    type="text"
                  />
                </div>

                <div class="grid grid-cols-1 md:grid-cols-[0.9fr,1.3fr] gap-3 items-center">
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
                  class="space-y-2"
                >
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
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
                        @change="onCirurgiaSelectChange($event, index)"
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
                  <input
                    v-model="historiaPregressa.doencasDescricao"
                    class="form-input text-xs"
                    placeholder="Digite qual(is) a(s) doença(s) prévia(s)"
                    type="text"
                  />
                </div>

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

                <div class="border-t border-gray-100 pt-3 mt-2 space-y-3">
                  <p class="text-xs font-semibold text-gray-700">
                    Sexo
                  </p>

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
            </div>
          </template>
          <template v-else-if="secaoKey === 'exame-fisico'">
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
          <template v-else-if="secaoKey === 'equipe-cirurgica'">
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
                    Selecione os profissionais
                  </option>
                  <option value="cirurgiao">
                    Cirurgião
                  </option>
                  <option value="auxiliar">
                    Auxiliar
                  </option>
                  <option value="anestesiologista">
                    Anestesiologista
                  </option>
                  <option value="enfermeiro">
                    Enfermeiro
                  </option>
                  <option value="outro">
                    Outro profissional
                  </option>
                </select>
                <div class="flex items-center gap-2">
                  <input
                    v-model="item.comentario"
                    class="form-input text-xs flex-1"
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
          <template v-else-if="secaoKey === 'fotos-paciente'">
            <div class="space-y-3">
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Anexo de imagem
                </label>
                <div class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center">
                  <input
                    class="form-input text-xs"
                    type="file"
                    @change="
                      (e: Event) => {
                        const input = e.target as HTMLInputElement | null
                        fotosPaciente.novoArquivo =
                          input?.files && input.files[0] ? input.files[0] : null
                      }
                    "
                  />
                  <input
                    v-model="fotosPaciente.novaObservacao"
                    class="form-input text-xs"
                    placeholder="Digite observação do arquivo"
                    type="text"
                  />
                  <button
                    class="h-9 w-9 inline-flex items-center justify-center rounded-md bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-100"
                    type="button"
                    @click="
                      fotosPaciente.novoArquivo &&
                        fotosPaciente.anexos.push({
                          nome: fotosPaciente.novoArquivo.name,
                          observacao: fotosPaciente.novaObservacao,
                        });
                      fotosPaciente.novoArquivo = null;
                      fotosPaciente.novaObservacao = '';
                    "
                  >
                    <i class="fa-solid fa-plus" aria-hidden="true"></i>
                  </button>
                </div>
              </div>

              <div
                v-for="(anexo, index) in fotosPaciente.anexos"
                :key="`${anexo.nome}-${index}`"
                class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center"
              >
                <div class="form-input text-xs flex items-center gap-2 bg-gray-50">
                  <span class="text-gray-500 truncate">
                    {{ anexo.nome }}
                  </span>
                </div>
                <input
                  v-model="anexo.observacao"
                  class="form-input text-xs"
                  placeholder="Digite observação do arquivo"
                  type="text"
                />
                <button
                  class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                  type="button"
                  @click="fotosPaciente.anexos.splice(index, 1)"
                >
                  <i class="fa-solid fa-trash" aria-hidden="true"></i>
                </button>
              </div>
            </div>
          </template>
          <template v-else-if="secaoKey === 'evolucao-pos-op'">
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

              <div class="grid grid-cols-1 md:grid-cols-[1.2fr,1.4fr] gap-3 items-center">
                <div class="flex items-center gap-4 text-xs">
                  <span class="font-semibold text-gray-700">
                    Está seguindo corretamente as orientações pós operatórias?
                  </span>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="evolucaoPosOperatoria.seguindoOrientacoes"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="nao"
                    />
                    <span>Não</span>
                  </label>
                  <label class="inline-flex items-center gap-1">
                    <input
                      v-model="evolucaoPosOperatoria.seguindoOrientacoes"
                      class="text-primary focus:ring-primary"
                      type="radio"
                      value="sim"
                    />
                    <span>Sim</span>
                  </label>
                </div>
                <input
                  v-model="evolucaoPosOperatoria.orientacoesComentario"
                  class="form-input text-xs"
                  placeholder="Comentário"
                  type="text"
                />
              </div>

              <div class="space-y-3">
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">
                    Anexo de imagem do pós operatório
                  </label>
                  <div class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center">
                    <input
                      class="form-input text-xs"
                      type="file"
                      @change="
                        (e: Event) => {
                          const input = e.target as HTMLInputElement | null
                          evolucaoPosOperatoria.novoArquivo =
                            input?.files && input.files[0] ? input.files[0] : null
                        }
                      "
                    />
                    <input
                      v-model="evolucaoPosOperatoria.novaObservacao"
                      class="form-input text-xs"
                      placeholder="Digite observação do arquivo"
                      type="text"
                    />
                    <button
                      class="h-9 w-9 inline-flex items-center justify-center rounded-md bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-100"
                      type="button"
                      @click="
                        evolucaoPosOperatoria.novoArquivo &&
                          evolucaoPosOperatoria.anexosImagem.push({
                            nome: evolucaoPosOperatoria.novoArquivo.name,
                            observacao: evolucaoPosOperatoria.novaObservacao,
                          });
                        evolucaoPosOperatoria.novoArquivo = null;
                        evolucaoPosOperatoria.novaObservacao = '';
                      "
                    >
                      <i class="fa-solid fa-plus" aria-hidden="true"></i>
                    </button>
                  </div>
                </div>

                <div
                  v-for="(anexo, index) in evolucaoPosOperatoria.anexosImagem"
                  :key="`${anexo.nome}-${index}`"
                  class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center"
                >
                  <div class="form-input text-xs flex items-center gap-2 bg-gray-50">
                    <span class="text-gray-500 truncate">
                      {{ anexo.nome }}
                    </span>
                  </div>
                  <input
                    v-model="anexo.observacao"
                    class="form-input text-xs"
                    placeholder="Digite observação do arquivo"
                    type="text"
                  />
                  <button
                    class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                    type="button"
                    @click="evolucaoPosOperatoria.anexosImagem.splice(index, 1)"
                  >
                    <i class="fa-solid fa-trash" aria-hidden="true"></i>
                  </button>
                </div>
              </div>
            </div>
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
            <div class="space-y-4">
              <div class="bg-gray-50 rounded-lg p-3 border border-gray-100 space-y-3">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <label class="block text-xs font-semibold text-gray-700 mb-1">
                      Tipo de exame
                    </label>
                    <select
                      v-model="examesRealizados.tipoExame"
                      class="form-input text-xs"
                    >
                      <option value="">
                        Tipo de exame (Laboratorial)
                      </option>
                      <option value="laboratorial">
                        Laboratorial
                      </option>
                      <option value="imagem">
                        Imagem
                      </option>
                      <option value="clinico">
                        Clínico
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs font-semibold text-gray-700 mb-1">
                      Material do exame
                    </label>
                    <input
                      v-model="examesRealizados.materialExame"
                      class="form-input text-xs"
                      placeholder="Material do exame (Sangue)"
                      type="text"
                    />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <label class="block text-xs font-semibold text-gray-700 mb-1">
                      Nome de exame
                    </label>
                    <input
                      v-model="examesRealizados.nomeExame"
                      class="form-input text-xs"
                      placeholder="Nome de exame"
                      type="text"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-semibold text-gray-700 mb-1">
                      Comentário
                    </label>
                    <input
                      v-model="examesRealizados.comentarioExame"
                      class="form-input text-xs"
                      placeholder="Comentário"
                      type="text"
                    />
                  </div>
                </div>
              </div>

              <div class="space-y-3">
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">
                    Anexo de imagem
                  </label>
                  <div class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center">
                    <input
                      class="form-input text-xs"
                      type="file"
                      @change="
                        (e: Event) => {
                          const input = e.target as HTMLInputElement | null
                          examesRealizados.novoAnexoArquivo =
                            input?.files && input.files[0] ? input.files[0] : null
                        }
                      "
                    />
                    <input
                      v-model="examesRealizados.novoAnexoObservacao"
                      class="form-input text-xs"
                      placeholder="Digite observação do arquivo"
                      type="text"
                    />
                    <button
                      class="h-9 w-9 inline-flex items-center justify-center rounded-md bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-100"
                      type="button"
                      @click="
                        examesRealizados.novoAnexoArquivo &&
                          examesRealizados.anexosImagem.push({
                            nome: examesRealizados.novoAnexoArquivo.name,
                            observacao: examesRealizados.novoAnexoObservacao,
                          });
                        examesRealizados.novoAnexoArquivo = null;
                        examesRealizados.novoAnexoObservacao = '';
                      "
                    >
                      <i class="fa-solid fa-plus" aria-hidden="true"></i>
                    </button>
                  </div>
                </div>

                <div
                  v-for="(anexo, index) in examesRealizados.anexosImagem"
                  :key="`${anexo.nome}-${index}`"
                  class="grid grid-cols-1 md:grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center"
                >
                  <div class="form-input text-xs flex items-center gap-2 bg-gray-50">
                    <span class="text-gray-500 truncate">
                      {{ anexo.nome }}
                    </span>
                  </div>
                  <input
                    v-model="anexo.observacao"
                    class="form-input text-xs"
                    placeholder="Esta foto contempla a frente do rosto do paciente que estará..."
                    type="text"
                  />
                  <button
                    class="h-8 w-8 inline-flex items-center justify-center rounded-md border border-red-100 text-red-600 hover:bg-red-50"
                    type="button"
                    @click="examesRealizados.anexosImagem.splice(index, 1)"
                  >
                    <i class="fa-solid fa-trash" aria-hidden="true"></i>
                  </button>
                </div>
              </div>
            </div>
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
</template>
