create table if not exists public.procedimento_cirurgico (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid not null references public.estabelecimentos (id) on delete cascade,
  nome text not null,
  tipo_cirurgia text,
  duracao_minutos integer,
  valor_sugerido numeric,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_timestamp_procedimento_cirurgico
before update on public.procedimento_cirurgico
for each row
execute procedure public.set_updated_at();

alter table if exists public.orcamento_itens
  add column if not exists procedimento_id uuid references public.procedimento_cirurgico (id),
  add column if not exists tipo_cirurgia text,
  add column if not exists tempo_previsto_minutos integer;

