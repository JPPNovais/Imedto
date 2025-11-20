-- Refined dashboard summary to considerar cadastro de profissional

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
),
prof as (
  select
    p.*,
    (
      (case when p.nome_exibicao is not null and p.nome_exibicao <> '' then 1 else 0 end) +
      (case when p.profissao_id is not null then 1 else 0 end) +
      (case when p.registro_profissional is not null and p.registro_profissional <> '' then 1 else 0 end) +
      (case when p.conselho is not null and p.conselho <> '' then 1 else 0 end) +
      (case when p.uf_conselho is not null and p.uf_conselho <> '' then 1 else 0 end)
    ) as campos_preenchidos,
    5 as total_campos
  from public.profissionais p
  where p.usuario_id = auth.uid()
  order by p.created_at
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

  -- Tarefas pendentes:
  -- 1) concluir onboarding
  -- 2) criar primeiro estabelecimento (se for um usuário que terá estabelecimento)
  -- 3) preencher cadastro básico do profissional (nome, profissão, registro, conselho, UF)
  (
    case when coalesce(u.onboarding_concluido, false) = false then 1 else 0 end +
    case when estab.id is null then 1 else 0 end +
    case
      when prof.id is null then 1
      when prof.campos_preenchidos < prof.total_campos then 1
      else 0
    end
  ) as tarefas_pendentes
from u
left join estab on true
left join prof on true;
$$;

grant execute on function public.dashboard_resumo_usuario() to authenticated;

