-- Resumo de agendamentos por profissional logado

create or replace function public.agenda_resumo_profissional()
returns table (
  total_hoje integer,
  total_semana integer,
  total_mes integer,
  proximo_horario timestamptz,
  proximo_titulo text
)
language sql
security definer
set search_path = public
as $$
with prof as (
  select id
  from public.profissionais
  where usuario_id = auth.uid()
  limit 1
),
bounds as (
  select
    current_date as hoje,
    date_trunc('week', current_date)::date as inicio_semana,
    (date_trunc('week', current_date) + interval '7 days')::date as fim_semana,
    date_trunc('month', current_date)::date as inicio_mes,
    (date_trunc('month', current_date) + interval '1 month')::date as fim_mes
),
base as (
  select e.*
  from public.evento_de_agendamento e
  join prof on e.profissional_id = prof.id
)
select
  -- Total de hoje
  (
    select count(*)
    from base b
    join bounds on true
    where b.data_hora_inicio::date = bounds.hoje
  )::int as total_hoje,
  -- Total da semana (segunda a domingo corrente)
  (
    select count(*)
    from base b
    join bounds on true
    where b.data_hora_inicio::date >= bounds.inicio_semana
      and b.data_hora_inicio::date < bounds.fim_semana
  )::int as total_semana,
  -- Total do mês corrente
  (
    select count(*)
    from base b
    join bounds on true
    where b.data_hora_inicio::date >= bounds.inicio_mes
      and b.data_hora_inicio::date < bounds.fim_mes
  )::int as total_mes,
  -- Próximo horário agendado (incluindo hoje em diante)
  (
    select b.data_hora_inicio
    from base b
    where b.data_hora_inicio >= now()
    order by b.data_hora_inicio
    limit 1
  ) as proximo_horario,
  (
    select coalesce(b.titulo, 'Atendimento')
    from base b
    where b.data_hora_inicio >= now()
    order by b.data_hora_inicio
    limit 1
  ) as proximo_titulo;
$$;

grant execute on function public.agenda_resumo_profissional() to authenticated;

