-- Permite que o profissional convidado atualize o status de suas solicitações

create policy "Solicitacao update invited" on public.solicitacao_vinculo_profissional_estabelecimento
for update
using (
  lower(email_profissional) = lower((auth.jwt() ->> 'email'))
)
with check (
  lower(email_profissional) = lower((auth.jwt() ->> 'email'))
);

