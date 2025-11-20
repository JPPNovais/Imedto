-- Adiciona campo de tipo de consulta ao evento de agendamento

alter table public.evento_de_agendamento
  add column if not exists tipo_consulta text
    check (tipo_consulta in ('consulta', 'retorno', 'procedimento', 'exame', 'outro'));

