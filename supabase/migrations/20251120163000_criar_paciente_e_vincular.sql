-- Função helper para criar paciente e já vinculá-lo a um estabelecimento

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
    estado
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
    p_estado
  )
  returning id into v_paciente_id;

  insert into public.paciente_estabelecimento (paciente_id, estabelecimento_id)
  values (v_paciente_id, p_estabelecimento_id)
  on conflict (paciente_id, estabelecimento_id) do nothing;

  return v_paciente_id;
end;
$$;

grant execute on function public.criar_paciente_e_vincular(
  text, text, text, date, text, text, text, text, text, text, text, text, uuid
) to authenticated;

