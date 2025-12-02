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
  secao_queixa_principal: {
    key: 'secao_queixa_principal',
    label: 'Queixa principal',
    placeholder: 'Descreva a queixa principal do paciente...',
  },
  secao_historia_atual: {
    key: 'secao_historia_atual',
    label: 'História atual',
    placeholder: 'Descreva a história atual da doença...',
  },
  secao_historia_pregressa: {
    key: 'secao_historia_pregressa',
    label: 'História pregressa',
    placeholder: 'Antecedentes pessoais, doenças prévias, cirurgias...',
  },
  secao_historia_familiar: {
    key: 'secao_historia_familiar',
    label: 'História familiar',
    placeholder: 'Doenças familiares relevantes...',
  },
  secao_historia_social: {
    key: 'secao_historia_social',
    label: 'História social',
    placeholder: 'Hábitos, profissão, uso de substâncias...',
  },
  secao_exame_fisico: {
    key: 'secao_exame_fisico',
    label: 'Exame físico',
    placeholder: 'Achados do exame físico...',
  },
  secao_evolucao: {
    key: 'secao_evolucao',
    label: 'Evolução',
    placeholder: 'Descrição da evolução clínica...',
  },
  secao_exames_realizados: {
    key: 'secao_exames_realizados',
    label: 'Exames realizados',
    placeholder: 'Exames complementares realizados e resultados...',
  },
  secao_procedimentos_indicados: {
    key: 'secao_procedimentos_indicados',
    label: 'Procedimentos indicados',
    placeholder: 'Procedimentos indicados ao paciente...',
  },
  secao_evolucao_pre_operatoria: {
    key: 'secao_evolucao_pre_operatoria',
    label: 'Evolução pré-operatória',
    placeholder: 'Registre a evolução pré-operatória...',
  },
  secao_evolucao_pos_operatoria: {
    key: 'secao_evolucao_pos_operatoria',
    label: 'Evolução pós-operatória',
    placeholder: 'Registre a evolução pós-operatória...',
  },
  secao_detalhes_da_cirurgia: {
    key: 'secao_detalhes_da_cirurgia',
    label: 'Informações da cirurgia realizada',
    placeholder: 'Data, tipo de cirurgia, tempo cirúrgico...',
  },
  secao_descricao_cirurgica: {
    key: 'secao_descricao_cirurgica',
    label: 'Descrição cirúrgica',
    placeholder: 'Descrição detalhada do ato cirúrgico...',
  },
  secao_equipe: {
    key: 'secao_equipe',
    label: 'Equipe',
    placeholder: 'Equipe envolvida no procedimento...',
  },
  secao_fotos_do_paciente: {
    key: 'secao_fotos_do_paciente',
    label: 'Fotos do paciente',
    placeholder: 'Referência às fotos registradas do paciente...',
  },
  secao_anexos: {
    key: 'secao_anexos',
    label: 'Anexos',
    placeholder: 'Documentos, laudos ou outros anexos importantes...',
  },
  secao_conduta: {
    key: 'secao_conduta',
    label: 'Conduta',
    placeholder: 'Conduta proposta, orientações e plano terapêutico...',
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
    if (key === 'secao_anexos') {
      secoesPayload[key] = {
        arquivos: anexos.value.map((a) => ({ nome: a.nome })),
      }
    } else if (key === 'secao_historia_atual') {
      secoesPayload[key] = {
        historico_queixa: historiaAtual.historicoQueixa || '',
        procedimentos: historiaAtual.procedimentos
          .map((p) => p.trim())
          .filter(Boolean),
      }
    } else if (key === 'secao_historia_pregressa') {
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
    } else if (key === 'secao_historia_familiar') {
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
    } else if (key === 'secao_historia_social') {
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
    } else if (key === 'secao_exame_fisico') {
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
    } else if (key === 'secao_exames_realizados') {
      secoesPayload[key] = {
        tipo_exame: examesRealizados.tipoExame || '',
        material_exame: examesRealizados.materialExame || '',
        nome_exame: examesRealizados.nomeExame || '',
        comentario_exame: examesRealizados.comentarioExame || '',
        anexos_imagem: examesRealizados.anexosImagem ?? [],
      }
    } else if (key === 'secao_equipe') {
      secoesPayload[key] = {
        profissionais: equipe.profissionais.filter(
          (p) => p.profissional.trim() || p.comentario.trim(),
        ),
      }
    } else if (key === 'secao_fotos_do_paciente') {
      secoesPayload[key] = {
        anexos: fotosPaciente.anexos ?? [],
      }
    } else if (key === 'secao_evolucao_pos_operatoria') {
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
    } else if (key === 'secao_descricao_cirurgica') {
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
    } else if (key === 'secao_procedimentos_indicados') {
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
            {{ secoesDictionary[secaoKey].label }}
          </h3>
          <template v-if="secaoKey === 'secao_anexos'">
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
          <template v-else-if="secaoKey === 'secao_historia_atual'">
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
          <template v-else-if="secaoKey === 'secao_historia_familiar'">
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
          <template v-else-if="secaoKey === 'secao_historia_social'">
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
          <template v-else-if="secaoKey === 'secao_historia_pregressa'">
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
                <div class="grid grid-cols-1 md:grid-cols-[0.5fr,1.5fr] gap-3 items-center">
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
                  <input
                    v-model="historiaPregressa.alergiaDescricao"
                    class="form-input text-xs"
                    placeholder="Digite qual a(s) alergia(s)"
                    type="text"
                  />
                </div>

                <div class="space-y-2">
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
                    class="grid grid-cols-[1.2fr,1.2fr,auto] gap-3 items-center"
                  >
                    <input
                      v-model="item.alergia"
                      class="form-input text-xs"
                      placeholder="Informe a alergia"
                      type="text"
                    />
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
                  <input
                    v-model="historiaPregressa.cirurgiasDescricao"
                    class="form-input text-xs"
                    placeholder="Digite qual a(s) cirurgia(s) anterior(es)"
                    type="text"
                  />
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
          <template v-else-if="secaoKey === 'secao_exame_fisico'">
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
          <template v-else-if="secaoKey === 'secao_equipe'">
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
          <template v-else-if="secaoKey === 'secao_fotos_do_paciente'">
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
          <template v-else-if="secaoKey === 'secao_evolucao_pos_operatoria'">
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
          <template v-else-if="secaoKey === 'secao_evolucao_pre_operatoria'">
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
          <template v-else-if="secaoKey === 'secao_procedimentos_indicados'">
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
          <template v-else-if="secaoKey === 'secao_exames_realizados'">
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
              :placeholder="secoesDictionary[secaoKey].placeholder"
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
</template>
