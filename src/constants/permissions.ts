export type PermissionId =
  | 'home'
  | 'agenda'
  | 'minhas_consultas'
  | 'pacientes'
  | 'prontuario'
  | 'modelos_prontuario'
  | 'perfil_profissional'
  | 'profissionais'
  | 'permissoes'
  | 'config_estabelecimento'

export type PermissionDef = {
  id: PermissionId
  label: string
}

export const PERMISSIONS: PermissionDef[] = [
  { id: 'home', label: 'Painel inicial' },
  { id: 'agenda', label: 'Gestão de atendimento (agenda)' },
  { id: 'minhas_consultas', label: 'Minhas consultas' },
  { id: 'pacientes', label: 'Pacientes' },
  { id: 'prontuario', label: 'Prontuário do paciente' },
  { id: 'modelos_prontuario', label: 'Modelos de prontuário' },
  { id: 'perfil_profissional', label: 'Meu cadastro profissional' },
  { id: 'profissionais', label: 'Gestão de profissionais' },
  { id: 'permissoes', label: 'Gestão de permissões' },
  { id: 'config_estabelecimento', label: 'Configurações do estabelecimento' },
]

export const ROUTE_PERMISSIONS: Record<string, PermissionId | null> = {
  home: null,
  agenda: 'agenda',
  'medical-worklist': 'minhas_consultas',
  'patients-list': 'pacientes',
  'medical-record': 'prontuario',
  'medical-record-models': 'modelos_prontuario',
  'professional-profile': null,
  'professionals-management': 'profissionais',
  'permissions-management': 'permissoes',
  'establishment-settings': 'config_estabelecimento',
}

export function permissionLabel(id: string): string {
  return PERMISSIONS.find((p) => p.id === id)?.label ?? id
}

