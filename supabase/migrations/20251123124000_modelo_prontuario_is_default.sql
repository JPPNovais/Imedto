-- Adiciona flag para marcar modelos padrão de prontuário

alter table public.modelo_de_prontuario
  add column if not exists is_default boolean not null default false;

-- Marca como padrão os modelos semeados anteriormente
update public.modelo_de_prontuario
set is_default = true
where nome in (
  'Primeira consulta',
  'Evolução',
  'Evolução pré-operatória',
  'Evolução pós-operatória',
  'Descrição cirúrgica'
);

