-- Função auxiliar para verificar se já existe vínculo ativo
-- entre um profissional (por e-mail do usuário) e um estabelecimento.

create or replace function public.is_professional_linked_to_establishment(
  p_email text,
  p_estabelecimento_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from auth.users u
    join public.profissionais p on p.usuario_id = u.id
    join public.vinculo_profissional_estabelecimento v
      on v.profissional_id = p.id
    where lower(u.email) = lower(p_email)
      and v.estabelecimento_id = p_estabelecimento_id
      and v.ativo = true
  );
$$;

grant execute on function public.is_professional_linked_to_establishment(text, uuid)
  to authenticated;
