-- Cria modelos de prontuário padrão para cada estabelecimento existente

insert into public.modelo_de_prontuario (
  estabelecimento_id,
  nome,
  descricao,
  estrutura
)
select
  e.id,
  'Primeira consulta',
  'Modelo padrão para primeira consulta.',
  jsonb_build_object(
    'secoes',
    jsonb_build_object(
      'secao_queixa_principal', true,
      'secao_historia_atual', true,
      'secao_historia_pregressa', true,
      'secao_historia_familiar', true,
      'secao_historia_social', true,
      'secao_exame_fisico', true,
      'secao_conduta', true
    )
  )
from public.estabelecimentos e;

insert into public.modelo_de_prontuario (
  estabelecimento_id,
  nome,
  descricao,
  estrutura
)
select
  e.id,
  'Evolução',
  'Modelo padrão para evolução ambulatorial.',
  jsonb_build_object(
    'secoes',
    jsonb_build_object(
      'secao_evolucao', true,
      'secao_conduta', true
    )
  )
from public.estabelecimentos e;

insert into public.modelo_de_prontuario (
  estabelecimento_id,
  nome,
  descricao,
  estrutura
)
select
  e.id,
  'Evolução pré-operatória',
  'Modelo para evolução pré-operatória.',
  jsonb_build_object(
    'secoes',
    jsonb_build_object(
      'secao_exames_realizados', true,
      'secao_procedimentos_indicados', true,
      'secao_evolucao_pre_operatoria', true,
      'secao_conduta', true
    )
  )
from public.estabelecimentos e;

insert into public.modelo_de_prontuario (
  estabelecimento_id,
  nome,
  descricao,
  estrutura
)
select
  e.id,
  'Evolução pós-operatória',
  'Modelo para evolução pós-operatória.',
  jsonb_build_object(
    'secoes',
    jsonb_build_object(
      'secao_detalhes_da_cirurgia', true,
      'secao_evolucao_pos_operatoria', true,
      'secao_conduta', true
    )
  )
from public.estabelecimentos e;

insert into public.modelo_de_prontuario (
  estabelecimento_id,
  nome,
  descricao,
  estrutura
)
select
  e.id,
  'Descrição cirúrgica',
  'Modelo para descrição cirúrgica detalhada.',
  jsonb_build_object(
    'secoes',
    jsonb_build_object(
      'secao_detalhes_da_cirurgia', true,
      'secao_equipe', true,
      'secao_descricao_cirurgica', true,
      'secao_fotos_do_paciente', true,
      'secao_anexos', true,
      'secao_conduta', true
    )
  )
from public.estabelecimentos e;

