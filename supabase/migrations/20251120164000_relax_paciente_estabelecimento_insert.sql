-- Relaxa a RLS de inserção em paciente_estabelecimento para permitir criar vínculos
-- a partir da aplicação (ou via REST) sem exigir vínculo prévio.

drop policy if exists "Paciente_estabelecimento insert linked"
  on public.paciente_estabelecimento;

create policy "Paciente_estabelecimento insert any_authenticated"
on public.paciente_estabelecimento
for insert
with check (auth.uid() is not null);

