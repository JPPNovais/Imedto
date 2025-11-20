-- Optional seed data for local development

-- Profissões mais comuns em clínicas e consultórios
insert into public.profissoes (id, nome)
values
  (extensions.gen_random_uuid(), 'Médico'),
  (extensions.gen_random_uuid(), 'Enfermeiro'),
  (extensions.gen_random_uuid(), 'Técnico de Enfermagem'),
  (extensions.gen_random_uuid(), 'Dentista'),
  (extensions.gen_random_uuid(), 'Fisioterapeuta'),
  (extensions.gen_random_uuid(), 'Psicólogo'),
  (extensions.gen_random_uuid(), 'Nutricionista'),
  (extensions.gen_random_uuid(), 'Fonoaudiólogo'),
  (extensions.gen_random_uuid(), 'Terapeuta Ocupacional'),
  (extensions.gen_random_uuid(), 'Biomédico')
on conflict do nothing;

-- Especialidades médicas/assistenciais comuns em clínicas e consultórios
insert into public.especialidades (id, nome)
values
  (extensions.gen_random_uuid(), 'Clínico Geral'),
  (extensions.gen_random_uuid(), 'Cardiologia'),
  (extensions.gen_random_uuid(), 'Pediatria'),
  (extensions.gen_random_uuid(), 'Ginecologia e Obstetrícia'),
  (extensions.gen_random_uuid(), 'Ortopedia e Traumatologia'),
  (extensions.gen_random_uuid(), 'Dermatologia'),
  (extensions.gen_random_uuid(), 'Endocrinologia'),
  (extensions.gen_random_uuid(), 'Psiquiatria'),
  (extensions.gen_random_uuid(), 'Gastroenterologia'),
  (extensions.gen_random_uuid(), 'Oftalmologia'),
  (extensions.gen_random_uuid(), 'Geriatria'),
  (extensions.gen_random_uuid(), 'Neurologia'),
  (extensions.gen_random_uuid(), 'Odontologia Geral'),
  (extensions.gen_random_uuid(), 'Odontopediatria'),
  (extensions.gen_random_uuid(), 'Fisioterapia Geral'),
  (extensions.gen_random_uuid(), 'Psicologia Clínica'),
  (extensions.gen_random_uuid(), 'Nutrição Clínica')
on conflict do nothing;

