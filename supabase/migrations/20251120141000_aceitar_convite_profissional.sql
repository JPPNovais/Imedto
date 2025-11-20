-- Função para aceitar convite de vínculo profissional

create or replace function public.aceitar_convite_profissional(solicitacao_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  prof_id uuid;
begin
  -- Solicitação deve existir, ser do usuário logado e estar pendente
  select *
    into s
  from public.solicitacao_vinculo_profissional_estabelecimento
  where id = solicitacao_id
    and lower(email_profissional) = lower((auth.jwt() ->> 'email'))
    and status = 'pendente';

  if not found then
    raise exception 'Solicitação não encontrada, não é sua ou já foi processada';
  end if;

  -- Busca ou cria o profissional para o usuário logado
  select id into prof_id
  from public.profissionais
  where usuario_id = auth.uid()
  limit 1;

  if prof_id is null then
    insert into public.profissionais (usuario_id, nome_exibicao, profissao_id)
    values (
      auth.uid(),
      coalesce((select nome_completo from public.usuarios where id = auth.uid()), 'Profissional'),
      s.profissao_id
    )
    returning id into prof_id;
  end if;

  -- Cria o vínculo se ainda não existir
  insert into public.vinculo_profissional_estabelecimento (
    estabelecimento_id,
    profissional_id,
    modelo_permissao_estabelecimento_id,
    is_admin
  )
  values (
    s.estabelecimento_id,
    prof_id,
    s.modelo_permissao_estabelecimento_id,
    false
  )
  on conflict (estabelecimento_id, profissional_id) do nothing;

  -- Atualiza o status da solicitação
  update public.solicitacao_vinculo_profissional_estabelecimento
  set status = 'aceito'
  where id = solicitacao_id;
end;
$$;

grant execute on function public.aceitar_convite_profissional(uuid) to authenticated;

