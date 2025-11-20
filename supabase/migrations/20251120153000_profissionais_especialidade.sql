-- Especialidade vinculada ao profissional

alter table public.profissionais
  add column if not exists especialidade_id uuid references public.especialidades (id);

