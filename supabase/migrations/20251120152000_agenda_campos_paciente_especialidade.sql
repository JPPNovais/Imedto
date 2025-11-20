-- Campos adicionais no evento de agendamento para dados básicos do paciente e especialidade

alter table public.evento_de_agendamento
  add column if not exists paciente_nome_agenda text,
  add column if not exists paciente_telefone_agenda text,
  add column if not exists especialidade_id uuid references public.especialidades (id);

