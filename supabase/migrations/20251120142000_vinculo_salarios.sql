-- Campos de remuneração no vínculo profissional-estabelecimento

alter table public.vinculo_profissional_estabelecimento
  add column if not exists salario_base numeric(12,2),
  add column if not exists valor_dia numeric(12,2);

