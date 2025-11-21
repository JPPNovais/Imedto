-- Remove RLS da tabela pacientes para permitir listagem
-- de pacientes vinculados via aplicação e via joins.
-- Os controles de privacidade passam a ser feitos na aplicação.

drop policy if exists "Pacientes select via estabelecimento vinculado"
  on public.pacientes;

drop policy if exists "Pacientes insert via estabelecimento vinculado"
  on public.pacientes;

drop policy if exists "Pacientes update via estabelecimento vinculado"
  on public.pacientes;

alter table public.pacientes
  disable row level security;

