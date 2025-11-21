-- Campos adicionais para cadastro mais completo de pacientes

alter table public.pacientes
  add column if not exists sexo text
    check (sexo in ('masculino', 'feminino', 'outro', 'nao_informado')),
  add column if not exists logradouro text,
  add column if not exists numero text,
  add column if not exists complemento text,
  add column if not exists bairro text,
  add column if not exists cidade text,
  add column if not exists estado char(2),
  add column if not exists cep text;

