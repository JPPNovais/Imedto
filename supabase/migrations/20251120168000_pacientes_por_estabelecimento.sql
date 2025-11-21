-- Adiciona vínculo direto de paciente com estabelecimento
-- e garante unicidade de documento dentro do estabelecimento.

alter table public.pacientes
  add column if not exists estabelecimento_id uuid
    references public.estabelecimentos (id) on delete cascade;

-- Backfill simples: se ainda não houver estabelecimento_id,
-- tenta pegar o primeiro vínculo em paciente_estabelecimento.
update public.pacientes p
set estabelecimento_id = pe.estabelecimento_id
from public.paciente_estabelecimento pe
where p.estabelecimento_id is null
  and pe.paciente_id = p.id;

-- Índice de unicidade de documento por estabelecimento
create unique index if not exists pacientes_estab_cpf_unique
  on public.pacientes (estabelecimento_id, cpf_cnpj)
  where cpf_cnpj is not null;

