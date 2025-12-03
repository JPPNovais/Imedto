-- Pool genérico de variáveis de prontuário (alergias, cirurgias, etc)

create table if not exists public.prontuario_variaveis_pool (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid references public.estabelecimentos (id) on delete cascade,
  tipo text not null,
  nome text not null,
  created_at timestamptz not null default now()
);

alter table public.prontuario_variaveis_pool enable row level security;

create policy "Variaveis pool select" on public.prontuario_variaveis_pool
for select
using (
  estabelecimento_id is null
  or public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id)
);

create policy "Variaveis pool manage own" on public.prontuario_variaveis_pool
for all
using (
  estabelecimento_id is not null
  and public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id)
)
with check (
  estabelecimento_id is not null
  and public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id)
);
