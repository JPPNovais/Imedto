-- Adiciona campos separados para telefone celular e telefone fixo em pacientes

alter table public.pacientes
  add column if not exists telefone_celular text,
  add column if not exists telefone_fixo text;

-- Backfill simples: assume telefone atual como celular, se ainda não houver valor
update public.pacientes
set telefone_celular = telefone
where telefone_celular is null
  and telefone is not null;

