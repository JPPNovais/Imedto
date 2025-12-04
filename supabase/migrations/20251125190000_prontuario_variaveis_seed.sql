-- Ajustes e seeds para prontuario_variaveis_pool

-- Garante que a tabela exista (caso esta migration rode antes da de criação dedicada)
create table if not exists public.prontuario_variaveis_pool (
  id uuid primary key default extensions.gen_random_uuid(),
  estabelecimento_id uuid references public.estabelecimentos (id) on delete cascade,
  tipo text not null,
  nome text not null,
  created_at timestamptz not null default now()
);

-- Garante unicidade por estabelecimento/tipo/nome (sem falhar se já existir)
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'prontuario_variaveis_pool_unq'
  ) then
    alter table public.prontuario_variaveis_pool
      add constraint prontuario_variaveis_pool_unq
      unique (estabelecimento_id, tipo, nome);
  end if;
end;
$$;

-- Migra dados antigos de alergias, se a tabela anterior existir
do $$
begin
  if to_regclass('public.prontuario_alergias_pool') is not null then
    insert into public.prontuario_variaveis_pool (
      estabelecimento_id,
      tipo,
      nome,
      created_at
    )
    select
      estabelecimento_id,
      'alergia'::text as tipo,
      nome,
      created_at
    from public.prontuario_alergias_pool
    on conflict (estabelecimento_id, tipo, nome) do nothing;
  end if;
end;
$$;

-- Seeds de variáveis padrão do sistema (visíveis para todos os estabelecimentos)

-- Alergias
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'alergia', 'Dipirona'),
  (null, 'alergia', 'AAS (Ácido acetilsalicílico)'),
  (null, 'alergia', 'Ibuprofeno'),
  (null, 'alergia', 'Diclofenaco'),
  (null, 'alergia', 'Penicilina'),
  (null, 'alergia', 'Amoxicilina'),
  (null, 'alergia', 'Cefalosporinas'),
  (null, 'alergia', 'Quinolonas'),
  (null, 'alergia', 'Contraste iodado'),
  (null, 'alergia', 'Látex'),
  (null, 'alergia', 'Anestésicos locais')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Cirurgias
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'cirurgia', 'Apendicectomia'),
  (null, 'cirurgia', 'Colecistectomia'),
  (null, 'cirurgia', 'Cesárea'),
  (null, 'cirurgia', 'Histerectomia'),
  (null, 'cirurgia', 'Cirurgia bariátrica'),
  (null, 'cirurgia', 'Herniorrafia inguinal'),
  (null, 'cirurgia', 'Artroplastia de quadril/joelho')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Doenças hereditárias
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'doenca_hereditaria', 'Doença cardiovascular precoce em familiares'),
  (null, 'doenca_hereditaria', 'Diabetes mellitus em familiares de primeiro grau'),
  (null, 'doenca_hereditaria', 'Câncer de mama em familiares'),
  (null, 'doenca_hereditaria', 'Câncer de cólon em familiares'),
  (null, 'doenca_hereditaria', 'Doenças reumáticas familiares')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Doenças crônicas / comorbidades
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'doenca_cronica', 'Hipertensão arterial sistêmica'),
  (null, 'doenca_cronica', 'Diabetes mellitus tipo 2'),
  (null, 'doenca_cronica', 'Doença coronariana'),
  (null, 'doenca_cronica', 'Insuficiência cardíaca'),
  (null, 'doenca_cronica', 'Asma'),
  (null, 'doenca_cronica', 'DPOC'),
  (null, 'doenca_cronica', 'Doença renal crônica'),
  (null, 'doenca_cronica', 'Obesidade')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Drogas / substâncias ilícitas
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'droga', 'Álcool'),
  (null, 'droga', 'Tabaco'),
  (null, 'droga', 'Maconha'),
  (null, 'droga', 'Cocaína'),
  (null, 'droga', 'Crack'),
  (null, 'droga', 'Ecstasy'),
  (null, 'droga', 'Anfetaminas'),
  (null, 'droga', 'Benzodiazepínicos'),
  (null, 'droga', 'Opiáceos')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Relações familiares
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'relacao_familiar', 'Pai'),
  (null, 'relacao_familiar', 'Mãe'),
  (null, 'relacao_familiar', 'Irmão'),
  (null, 'relacao_familiar', 'Irmã'),
  (null, 'relacao_familiar', 'Avô'),
  (null, 'relacao_familiar', 'Avó'),
  (null, 'relacao_familiar', 'Tio'),
  (null, 'relacao_familiar', 'Tia')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Expectativas do paciente
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'expectativa', 'Melhora estética'),
  (null, 'expectativa', 'Redução da dor'),
  (null, 'expectativa', 'Melhora funcional'),
  (null, 'expectativa', 'Retorno ao trabalho/atividades'),
  (null, 'expectativa', 'Melhora da autoestima'),
  (null, 'expectativa', 'Melhora da qualidade de vida')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Medicações em uso
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'medicacao', 'Losartana'),
  (null, 'medicacao', 'Hidroclorotiazida'),
  (null, 'medicacao', 'Metformina'),
  (null, 'medicacao', 'Sinvastatina'),
  (null, 'medicacao', 'Omeprazol'),
  (null, 'medicacao', 'AAS'),
  (null, 'medicacao', 'Insulina NPH'),
  (null, 'medicacao', 'Insulina Regular')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Atividades físicas
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'atividade_fisica', 'Sedentário'),
  (null, 'atividade_fisica', 'Caminhada leve'),
  (null, 'atividade_fisica', 'Corrida'),
  (null, 'atividade_fisica', 'Musculação'),
  (null, 'atividade_fisica', 'Natação'),
  (null, 'atividade_fisica', 'Esportes coletivos')
on conflict (estabelecimento_id, tipo, nome) do nothing;

-- Cirurgias pregressas
insert into public.prontuario_variaveis_pool (estabelecimento_id, tipo, nome)
values
  (null, 'cirurgia_pregressa', 'Cesárea'),
  (null, 'cirurgia_pregressa', 'Colecistectomia'),
  (null, 'cirurgia_pregressa', 'Apendicectomia'),
  (null, 'cirurgia_pregressa', 'Histerectomia'),
  (null, 'cirurgia_pregressa', 'Cirurgia bariátrica')
on conflict (estabelecimento_id, tipo, nome) do nothing;
