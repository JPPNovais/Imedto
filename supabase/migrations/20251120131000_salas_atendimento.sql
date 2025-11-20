-- Tabelas de salas de atendimento por estabelecimento

create table if not exists public.tipo_sala_atendimento (
  id uuid primary key default extensions.gen_random_uuid(),
  nome text not null unique,
  descricao text
);

create table if not exists public.sala_atendimento (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  nome text not null,
  tipo_sala_id uuid references public.tipo_sala_atendimento (id),
  descricao text,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_sala_atendimento
before update on public.sala_atendimento
for each row
execute procedure public.set_updated_at();

-- RLS
alter table public.tipo_sala_atendimento enable row level security;
alter table public.sala_atendimento enable row level security;

-- tipos de sala podem ser visíveis para qualquer usuário autenticado
create policy "Tipo sala select all" on public.tipo_sala_atendimento
for select
using (true);

-- salas por estabelecimento: apenas usuários vinculados ou owner
create policy "Sala atendimento select linked" on public.sala_atendimento
for select
using (public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id));

create policy "Sala atendimento manage owner" on public.sala_atendimento
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

