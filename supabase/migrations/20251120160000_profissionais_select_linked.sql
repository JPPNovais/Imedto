-- Permite que usuários vinculados ao mesmo estabelecimento
-- enxerguem os profissionais desse estabelecimento.

create policy "Profissionais select linked via vinculo"
on public.profissionais
for select
using (
  exists (
    select 1
    from public.vinculo_profissional_estabelecimento v
    where v.profissional_id = profissionais.id
      and public.is_usuario_vinculado_ao_estabelecimento(v.estabelecimento_id)
  )
);

