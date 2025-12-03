-- Criação da tabela genérica de variáveis de prontuário

create table if not exists public.prontuario_variaveis_pool (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid references public.estabelecimentos (id) on delete cascade,
  tipo text not null,
  nome text not null,
  created_at timestamptz not null default now()
);

alter table public.prontuario_variaveis_pool enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'prontuario_variaveis_pool'
      and policyname = 'Variaveis pool select'
  ) then
    create policy "Variaveis pool select" on public.prontuario_variaveis_pool
    for select
    using (
      estabelecimento_id is null
      or public.is_usuario_vinculado_ao_estabelecimento(estabelecimento_id)
    );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'prontuario_variaveis_pool'
      and policyname = 'Variaveis pool manage own'
  ) then
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
  end if;
end;
$$;
