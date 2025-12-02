create table if not exists public.orcamentos (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  paciente_id uuid not null references public.pacientes (id) on delete restrict,
  profissional_id uuid references public.profissionais (id),
  titulo text,
  observacoes text,
  valor_total numeric not null default 0,
  status text not null default 'rascunho' check (status in ('rascunho', 'enviado', 'aprovado', 'recusado', 'cancelado', 'expirado')),
  validade date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_orcamentos
before update on public.orcamentos
for each row
execute procedure public.set_updated_at();

create table if not exists public.orcamento_itens (
  id uuid primary key default extensions.gen_random_uuid(),
  orcamento_id uuid not null references public.orcamentos (id) on delete cascade,
  descricao text not null,
  quantidade numeric not null default 1,
  valor_unitario numeric not null default 0,
  valor_total numeric not null default 0,
  created_at timestamptz not null default now()
);

