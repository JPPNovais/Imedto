-- Permite que o profissional convidado veja suas próprias solicitações
-- com base no e-mail informado em email_profissional.

create policy "Solicitacao select invited" on public.solicitacao_vinculo_profissional_estabelecimento
for select
using (
  lower(email_profissional) = lower((auth.jwt() ->> 'email'))
);

