-- Tipos de sala de atendimento padrão

insert into public.tipo_sala_atendimento (id, nome, descricao)
values
  (extensions.gen_random_uuid(), 'Consulta', 'Sala de atendimento clínico geral e consultas.'),
  (extensions.gen_random_uuid(), 'Cirurgia', 'Sala preparada para procedimentos cirúrgicos.'),
  (extensions.gen_random_uuid(), 'Procedimentos', 'Sala para pequenos procedimentos e curativos.'),
  (extensions.gen_random_uuid(), 'Exames', 'Sala para realização de exames (imagem, laboratoriais, etc.).'),
  (extensions.gen_random_uuid(), 'Triagem', 'Sala de triagem e avaliação inicial do paciente.'),
  (extensions.gen_random_uuid(), 'Teleatendimento', 'Sala dedicada a atendimentos remotos / telemedicina.')
on conflict (nome) do nothing;

