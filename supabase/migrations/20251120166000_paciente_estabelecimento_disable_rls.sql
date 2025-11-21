-- Remove completamente RLS de paciente_estabelecimento, pois a tabela
-- contém apenas chaves (sem dados sensíveis do paciente) e estava
-- impedindo o uso de upsert via REST.

drop policy if exists "Paciente_estabelecimento select linked"
  on public.paciente_estabelecimento;

drop policy if exists "Paciente_estabelecimento select any_authenticated"
  on public.paciente_estabelecimento;

drop policy if exists "Paciente_estabelecimento insert linked"
  on public.paciente_estabelecimento;

drop policy if exists "Paciente_estabelecimento insert any_authenticated"
  on public.paciente_estabelecimento;

alter table public.paciente_estabelecimento
  disable row level security;

