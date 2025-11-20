-- Initial schema for Imedto platform
-- Run via: supabase db reset / db push

-- Extensions -----------------------------------------------------------------

create extension if not exists "pgcrypto" with schema "extensions";

-- Shared helpers --------------------------------------------------------------

-- Generic updated_at trigger
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Core tables -----------------------------------------------------------------

-- Users table linked to Supabase auth.users
create table if not exists public.usuarios (
  id uuid primary key references auth.users (id) on delete cascade,
  nome_completo text,
  cpf_cnpj text,
  tipo_pessoa text check (tipo_pessoa in ('PF', 'PJ')),
  onboarding_concluido boolean not null default false,
  tutorial_visto boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_usuarios
before update on public.usuarios
for each row
execute procedure public.set_updated_at();

-- Establishments --------------------------------------------------------------

create table if not exists public.estabelecimentos (
  id uuid primary key default extensions.gen_random_uuid(),
  nome_fantasia text not null,
  razao_social text,
  tipo_pessoa text not null check (tipo_pessoa in ('PF', 'PJ')),
  cpf_cnpj text,
  owner_usuario_id uuid not null references public.usuarios (id) on delete restrict,
  foto_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_estabelecimentos
before update on public.estabelecimentos
for each row
execute procedure public.set_updated_at();

-- Domain tables ---------------------------------------------------------------

create table if not exists public.profissoes (
  id uuid primary key default extensions.gen_random_uuid(),
  nome text not null unique
);

create table if not exists public.especialidades (
  id uuid primary key default extensions.gen_random_uuid(),
  nome text not null unique
);

-- Professionals ---------------------------------------------------------------

create table if not exists public.profissionais (
  id uuid primary key default extensions.gen_random_uuid(),
  usuario_id uuid references public.usuarios (id) on delete set null,
  nome_exibicao text,
  profissao_id uuid references public.profissoes (id),
  registro_profissional text,
  conselho text,
  uf_conselho char(2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_profissionais
before update on public.profissionais
for each row
execute procedure public.set_updated_at();

-- Permission models per establishment ----------------------------------------

create table if not exists public.modelo_permissao_estabelecimento (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  nome text not null,
  permissoes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_modelo_permissao_estabelecimento
before update on public.modelo_permissao_estabelecimento
for each row
execute procedure public.set_updated_at();

-- Link between professional and establishment --------------------------------

create table if not exists public.vinculo_profissional_estabelecimento (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  profissional_id uuid not null references public.profissionais (id) on delete cascade,
  modelo_permissao_estabelecimento_id uuid references public.modelo_permissao_estabelecimento (id),
  is_admin boolean not null default false,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (estabelecimento_id, profissional_id)
);

create trigger set_timestamp_vinculo_profissional_estabelecimento
before update on public.vinculo_profissional_estabelecimento
for each row
execute procedure public.set_updated_at();

-- Invite flow for professionals ----------------------------------------------

create table if not exists public.solicitacao_vinculo_profissional_estabelecimento (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  modelo_permissao_estabelecimento_id uuid references public.modelo_permissao_estabelecimento (id),
  profissao_id uuid references public.profissoes (id),
  especialidade_id uuid references public.especialidades (id),
  email_profissional text not null,
  status text not null default 'pendente' check (status in ('pendente', 'aceito', 'recusado', 'cancelado')),
  mensagem text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_solicitacao_vinculo_profissional_estabelecimento
before update on public.solicitacao_vinculo_profissional_estabelecimento
for each row
execute procedure public.set_updated_at();

-- Patients --------------------------------------------------------------------

create table if not exists public.pacientes (
  id uuid primary key default extensions.gen_random_uuid(),
  nome_completo text not null,
  cpf_cnpj text,
  data_nascimento date,
  telefone text,
  email text,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_pacientes
before update on public.pacientes
for each row
execute procedure public.set_updated_at();

-- Many-to-many between pacientes and estabelecimentos
create table if not exists public.paciente_estabelecimento (
  id uuid primary key default extensions.gen_random_uuid(),
  paciente_id uuid not null references public.pacientes (id) on delete cascade,
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (paciente_id, estabelecimento_id)
);

-- Scheduling ------------------------------------------------------------------

create table if not exists public.evento_de_agendamento (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  profissional_id uuid references public.profissionais (id),
  paciente_id uuid references public.pacientes (id),
  data_hora_inicio timestamptz not null,
  data_hora_fim timestamptz,
  status text not null default 'agendado' check (status in ('agendado', 'confirmado', 'cancelado', 'concluido')),
  titulo text,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_evento_de_agendamento
before update on public.evento_de_agendamento
for each row
execute procedure public.set_updated_at();

-- Medical record templates ----------------------------------------------------

create table if not exists public.modelo_de_prontuario (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  nome text not null,
  descricao text,
  estrutura jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_modelo_de_prontuario
before update on public.modelo_de_prontuario
for each row
execute procedure public.set_updated_at();

-- Medical record per patient per establishment -------------------------------

create table if not exists public.prontuarios (
  id uuid primary key default extensions.gen_random_uuid(),
  paciente_id uuid not null references public.pacientes (id) on delete cascade,
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  modelo_de_prontuario_id uuid references public.modelo_de_prontuario (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (paciente_id, estabelecimento_id)
);

create trigger set_timestamp_prontuarios
before update on public.prontuarios
for each row
execute procedure public.set_updated_at();

-- Evolutions inside a medical record -----------------------------------------

create table if not exists public.evolucao_prontuario (
  id uuid primary key default extensions.gen_random_uuid(),
  prontuario_id uuid not null references public.prontuarios (id) on delete cascade,
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  paciente_id uuid not null references public.pacientes (id) on delete cascade,
  profissional_id uuid not null references public.profissionais (id),
  evento_de_agendamento_id uuid references public.evento_de_agendamento (id),
  modelo_de_prontuario_id uuid references public.modelo_de_prontuario (id),
  conteudo jsonb not null,
  criado_em timestamptz not null default now()
);

-- Helper function to know if auth user is linked to an establishment ---------

create or replace function public.is_usuario_vinculado_ao_estabelecimento(estab_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuarios u
    join public.profissionais p on p.usuario_id = u.id
    join public.vinculo_profissional_estabelecimento v on v.profissional_id = p.id
    where u.id = auth.uid()
      and v.estabelecimento_id = estab_id
      and v.ativo = true
  )
  or exists (
    select 1
    from public.estabelecimentos e
    where e.id = estab_id
      and e.owner_usuario_id = auth.uid()
  );
$$;

grant execute on function public.is_usuario_vinculado_ao_estabelecimento(uuid) to authenticated;

-- Row Level Security ----------------------------------------------------------

-- Usuarios: user can only see/update themselves
alter table public.usuarios enable row level security;

create policy "Usuarios select self" on public.usuarios
for select
using (auth.uid() = id);

create policy "Usuarios update self" on public.usuarios
for update
using (auth.uid() = id);

create policy "Usuarios insert self" on public.usuarios
for insert
with check (auth.uid() = id);

-- Estabelecimentos
alter table public.estabelecimentos enable row level security;

create policy "Estabelecimentos select owner or linked" on public.estabelecimentos
for select
using (
  owner_usuario_id = auth.uid()
  or public.is_usuario_vinculado_ao_estabelecimento(id)
);

create policy "Estabelecimentos insert owner" on public.estabelecimentos
for insert
with check (owner_usuario_id = auth.uid());

create policy "Estabelecimentos update owner" on public.estabelecimentos
for update
using (owner_usuario_id = auth.uid());

-- Profissionais: user can see/update their own professional profile
alter table public.profissionais enable row level security;

create policy "Profissionais select self" on public.profissionais
for select
using (usuario_id = auth.uid());

create policy "Profissionais update self" on public.profissionais
for update
using (usuario_id = auth.uid());

create policy "Profissionais insert self" on public.profissionais
for insert
with check (usuario_id = auth.uid());

-- Vinculo profissional-estabelecimento
alter table public.vinculo_profissional_estabelecimento enable row level security;

create policy "Vinculo select linked" on public.vinculo_profissional_estabelecimento
for select
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Vinculo manage by owner" on public.vinculo_profissional_estabelecimento
for all
using (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
);

-- Pacientes
alter table public.pacientes enable row level security;

create policy "Pacientes select via estabelecimento vinculado" on public.pacientes
for select
using (
  exists (
    select 1
    from public.paciente_estabelecimento pe
    where pe.paciente_id = id
      and public.is_usuario_vinculado_ao_estabelecimento(pe.estabelecimento_id)
  )
);

create policy "Pacientes insert via estabelecimento vinculado" on public.pacientes
for insert
with check (true); -- Inserção será normalmente acompanhada por paciente_estabelecimento

create policy "Pacientes update via estabelecimento vinculado" on public.pacientes
for update
using (
  exists (
    select 1
    from public.paciente_estabelecimento pe
    where pe.paciente_id = id
      and public.is_usuario_vinculado_ao_estabelecimento(pe.estabelecimento_id)
  )
);

-- Paciente_estabelecimento
alter table public.paciente_estabelecimento enable row level security;

create policy "Paciente_estabelecimento select linked" on public.paciente_estabelecimento
for select
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Paciente_estabelecimento insert linked" on public.paciente_estabelecimento
for insert
with check (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

-- Evento de agendamento
alter table public.evento_de_agendamento enable row level security;

create policy "Evento select linked" on public.evento_de_agendamento
for select
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Evento insert linked" on public.evento_de_agendamento
for insert
with check (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Evento update linked" on public.evento_de_agendamento
for update
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

-- Modelo de prontuario
alter table public.modelo_de_prontuario enable row level security;

create policy "Modelo prontuario select linked" on public.modelo_de_prontuario
for select
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Modelo prontuario manage owner" on public.modelo_de_prontuario
for all
using (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
);

-- Prontuarios
alter table public.prontuarios enable row level security;

create policy "Prontuarios select linked" on public.prontuarios
for select
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Prontuarios insert linked" on public.prontuarios
for insert
with check (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Prontuarios update linked" on public.prontuarios
for update
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

-- Evolucao prontuario
alter table public.evolucao_prontuario enable row level security;

create policy "Evolucao select medico_or_admin" on public.evolucao_prontuario
for select
using (
  public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id)
  and exists (
    select 1
    from public.profissionais p
    where p.id = profissional_id
      and p.usuario_id = auth.uid()
  )
  or exists (
    select 1
    from public.vinculo_profissional_estabelecimento v
    join public.profissionais p2 on p2.id = v.profissional_id
    where v.estabelecimento_id = estabelecimento_id
      and v.is_admin = true
      and p2.usuario_id = auth.uid()
  )
);

create policy "Evolucao insert medico_or_admin" on public.evolucao_prontuario
for insert
with check (
  public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id)
  and (
    exists (
      select 1
      from public.profissionais p
      where p.id = profissional_id
        and p.usuario_id = auth.uid()
    )
    or exists (
      select 1
      from public.vinculo_profissional_estabelecimento v
      join public.profissionais p2 on p2.id = v.profissional_id
      where v.estabelecimento_id = estabelecimento_id
        and v.is_admin = true
        and p2.usuario_id = auth.uid()
    )
  )
);

-- Solicitações de vínculo: visíveis para owner do estabelecimento
alter table public.solicitacao_vinculo_profissional_estabelecimento enable row level security;

create policy "Solicitacao select owner" on public.solicitacao_vinculo_profissional_estabelecimento
for select
using (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
);

create policy "Solicitacao manage owner" on public.solicitacao_vinculo_profissional_estabelecimento
for all
using (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.estabelecimentos e
    where e.id = estabelecimento_id
      and e.owner_usuario_id = auth.uid()
  )
);

