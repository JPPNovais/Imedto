-- Dashboard summary com flag de profissional completo

-- Como estamos alterando o tipo de retorno da função,
-- é necessário descartá-la antes de recriá-la.
drop function if exists public.dashboard_resumo_usuario();

create function public.dashboard_resumo_usuario()
returns table (
  cadastro_usuario_percentual integer,
  cadastro_estabelecimento_percentual integer,
  profissional_completo boolean,
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
    pr.nome as profissao_nome,
    -- campos sempre obrigatórios
    (case when p.nome_exibicao is not null and p.nome_exibicao <> '' then 1 else 0 end) +
    (case when p.profissao_id is not null then 1 else 0 end) as campos_basicos,
    2 as total_basico,
    -- campos extras apenas se for médico
    (case
      when pr.nome ilike 'médico%' then
        (case when p.registro_profissional is not null and p.registro_profissional <> '' then 1 else 0 end) +
        (case when p.conselho is not null and p.conselho <> '' then 1 else 0 end) +
        (case when p.uf_conselho is not null and p.uf_conselho <> '' then 1 else 0 end)
      else 0
    end) as campos_medico,
    (case
      when pr.nome ilike 'médico%' then 3
      else 0
    end) as total_medico
  from public.profissionais p
  left join public.profissoes pr on pr.id = p.profissao_id
  where p.usuario_id = auth.uid()
  order by p.created_at
  limit 1
),
salas as (
  select count(*) as total_salas
  from public.sala_atendimento s
  where s.estabelecimento_id = (select id from estab)
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

  -- Percentual de cadastro do estabelecimento (nome fantasia, documento, ter ao menos uma sala)
  coalesce(
    round(
      (
        (case when estab.nome_fantasia is not null and estab.nome_fantasia <> '' then 1 else 0 end) +
        (case when estab.cpf_cnpj is not null and estab.cpf_cnpj <> '' then 1 else 0 end) +
        (case when coalesce(salas.total_salas, 0) > 0 then 1 else 0 end)
      ) * 100.0 / 3
    ),
    0
  )::int as cadastro_estabelecimento_percentual,

  -- Profissional completo?
  (
    case
      when prof.id is null then false
      when prof.campos_basicos < prof.total_basico then false
      when prof.profissao_nome ilike 'médico%' and prof.campos_medico < prof.total_medico then false
      else true
    end
  ) as profissional_completo,

  -- Tarefas pendentes:
  -- 1) concluir onboarding
  -- 2) criar primeiro estabelecimento
  -- 3) preencher cadastro básico do profissional
  -- 4) se for médico, preencher CRM/Conselho/UF
  -- 5) configurar ao menos uma sala de atendimento
  (
    case when coalesce(u.onboarding_concluido, false) = false then 1 else 0 end +
    case when estab.id is null then 1 else 0 end +
    case
      when prof.id is null then 1
      when prof.campos_basicos < prof.total_basico then 1
      else 0
    end +
    case
      when prof.id is not null
       and prof.profissao_nome ilike 'médico%'
       and prof.campos_medico < prof.total_medico
      then 1
      else 0
    end +
    case when coalesce(salas.total_salas, 0) = 0 then 1 else 0 end
  ) as tarefas_pendentes
from u
left join estab on true
left join prof on true
left join salas on true;
$$;

grant execute on function public.dashboard_resumo_usuario() to authenticated;
