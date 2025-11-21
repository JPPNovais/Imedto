-- Relaxa a RLS de SELECT em paciente_estabelecimento
-- para permitir upsert via REST (ON CONFLICT ...) sem erro 42501.

drop policy if exists "Paciente_estabelecimento select linked"
  on public.paciente_estabelecimento;

create policy "Paciente_estabelecimento select any_authenticated"
on public.paciente_estabelecimento
for select
using (auth.uid() is not null);

