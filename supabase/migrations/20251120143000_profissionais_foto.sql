-- Campo de foto opcional para profissionais

alter table public.profissionais
  add column if not exists foto_url text;

