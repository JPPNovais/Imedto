-- Garante que cada usuário tenha no máximo um estabelecimento (como owner)
-- e no máximo um registro de profissional vinculado.

-- Primeiro, remove registros duplicados, mantendo apenas o mais recente
-- por usuário (para não quebrar a criação do índice único).

delete from public.estabelecimentos e
using public.estabelecimentos e2
where e.owner_usuario_id = e2.owner_usuario_id
  and e.id < e2.id;

delete from public.profissionais p
using public.profissionais p2
where p.usuario_id = p2.usuario_id
  and p.id < p2.id;

-- Agora adiciona as restrições de unicidade

alter table public.estabelecimentos
  add constraint estabelecimentos_owner_usuario_unique
  unique (owner_usuario_id);

alter table public.profissionais
  add constraint profissionais_usuario_unique
  unique (usuario_id);

