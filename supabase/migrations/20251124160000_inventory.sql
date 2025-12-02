create table if not exists public.estoque_produto (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  nome text not null,
  descricao text,
  unidade text,
  quantidade_atual numeric not null default 0,
  quantidade_minima numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_estoque_produto
before update on public.estoque_produto
for each row
execute procedure public.set_updated_at();

create table if not exists public.movimento_estoque (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  produto_id uuid not null references public.estoque_produto (id) on delete cascade,
  tipo text not null check (tipo in ('entrada', 'saida')),
  quantidade numeric not null,
  motivo text,
  created_at timestamptz not null default now()
);

