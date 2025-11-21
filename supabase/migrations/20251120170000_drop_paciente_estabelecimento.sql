-- Remove tabela paciente_estabelecimento e referências associadas,
-- agora que pacientes são únicos por estabelecimento.

-- Primeiro, remove usos em funções que ainda possam existir na base
-- antiga (proteção caso a migration anterior exista).
create or replace function public.criar_paciente_e_vincular(
  p_nome_completo text,
  p_cpf_cnpj text,
  p_telefone text,
  p_data_nascimento date,
  p_sexo text,
  p_cep text,
  p_logradouro text,
  p_numero text,
  p_complemento text,
  p_bairro text,
  p_cidade text,
  p_estado text,
  p_estabelecimento_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paciente_id uuid;
begin
  insert into public.pacientes (
    nome_completo,
    cpf_cnpj,
    telefone,
    data_nascimento,
    sexo,
    cep,
    logradouro,
    numero,
    complemento,
    bairro,
    cidade,
    estado,
    estabelecimento_id
  )
  values (
    p_nome_completo,
    p_cpf_cnpj,
    p_telefone,
    p_data_nascimento,
    p_sexo,
    p_cep,
    p_logradouro,
    p_numero,
    p_complemento,
    p_bairro,
    p_cidade,
    p_estado,
    p_estabelecimento_id
  )
  returning id into v_paciente_id;

  return v_paciente_id;
end;
$$;

grant execute on function public.criar_paciente_e_vincular(
  text, text, text, date, text, text, text, text, text, text, text, text, uuid
) to authenticated;

-- Por segurança, derruba qualquer política restante e a própria tabela.
drop policy if exists "Paciente_estabelecimento select linked"
  on public.paciente_estabelecimento;

drop policy if exists "Paciente_estabelecimento select any_authenticated"
  on public.paciente_estabelecimento;

drop policy if exists "Paciente_estabelecimento insert linked"
  on public.paciente_estabelecimento;

drop policy if exists "Paciente_estabelecimento insert any_authenticated"
  on public.paciente_estabelecimento;

alter table if exists public.paciente_estabelecimento
  disable row level security;

drop table if exists public.paciente_estabelecimento;

