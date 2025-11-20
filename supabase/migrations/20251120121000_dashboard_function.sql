-- Dashboard summary function for the logged user

create or replace function public.dashboard_resumo_usuario()
returns table (
  cadastro_usuario_percentual integer,
  cadastro_estabelecimento_percentual integer,
  tarefas_pendentes integer
)
language sql
security definer
set search_path = public
as $$
with u as (
  select *
  from public.usuarios
  where id = auth.uid()
),
estab as (
  select e.*
  from public.estabelecimentos e
  where e.owner_usuario_id = auth.uid()
  order by e.created_at
  limit 1
)
select
  -- Percentual de cadastro do usuário (nome, documento, tipo pessoa)
  coalesce(
    round(
      (
        (case when u.nome_completo is not null and u.nome_completo <> '' then 1 else 0 end) +
        (case when u.cpf_cnpj is not null and u.cpf_cnpj <> '' then 1 else 0 end) +
        (case when u.tipo_pessoa is not null and u.tipo_pessoa <> '' then 1 else 0 end)
      ) * 100.0 / 3
    ),
    0
  )::int as cadastro_usuario_percentual,

  -- Percentual de cadastro do estabelecimento (nome fantasia, documento)
  coalesce(
    round(
      (
        (case when estab.nome_fantasia is not null and estab.nome_fantasia <> '' then 1 else 0 end) +
        (case when estab.cpf_cnpj is not null and estab.cpf_cnpj <> '' then 1 else 0 end)
      ) * 100.0 / 2
    ),
    0
  )::int as cadastro_estabelecimento_percentual,

  -- Tarefas pendentes simples: concluir onboarding e criar primeiro estabelecimento
  (
    case when coalesce(u.onboarding_concluido, false) = false then 1 else 0 end +
    case when estab.id is null then 1 else 0 end
  ) as tarefas_pendentes
from u
left join estab on true;
$$;

grant execute on function public.dashboard_resumo_usuario() to authenticated;

