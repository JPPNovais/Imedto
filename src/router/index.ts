import {
  createRouter,
  createWebHistory,
  NavigationGuardNext,
  RouteLocationNormalized,
} from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { usePermissionsStore } from '@/stores/permissions'
import { ROUTE_PERMISSIONS } from '@/constants/permissions'

// STRUCTURE
import PageBody from '@/modules/shared/structure/PageBody.vue'

// VIEWS
import Login from '@/modules/login/views/Login.vue'
import Home from '@/modules/home/views/Home.vue'
import Onboarding from '@/modules/onboarding/views/Onboarding.vue'
import Schedule from '@/modules/schedule/views/Schedule.vue'
import ProfessionalProfile from '@/modules/professional/views/ProfessionalProfile.vue'
import EstablishmentSettings from '@/modules/establishment/views/EstablishmentSettings.vue'
import ProfessionalsManagement from '@/modules/professionals/views/ProfessionalsManagement.vue'
import PermissionsManagement from '@/modules/permissions/views/PermissionsManagement.vue'
import PatientsList from '@/modules/patients/views/PatientsList.vue'
import MedicalRecord from '@/modules/medical-record/views/MedicalRecord.vue'
import MedicalRecordModels from '@/modules/medical-record/views/MedicalRecordModels.vue'
import MedicalWorklist from '@/modules/medical-record/views/MedicalWorklist.vue'
import Inventory from '@/modules/inventory/views/Inventory.vue'

const ifNotAuthenticated = (
  to: RouteLocationNormalized | undefined,
  from: RouteLocationNormalized | undefined,
  next: NavigationGuardNext,
) => {
  const auth = useAuthStore()

  if (!auth.isAuthenticated) {
    next()
    return
  }

  next('/')
}

const ifAuthenticated = async (
  to: RouteLocationNormalized | undefined,
  from: RouteLocationNormalized | undefined,
  next: NavigationGuardNext,
) => {
  const auth = useAuthStore()

  // Se não estiver autenticado, sempre vai para login
  if (!auth.isAuthenticated) {
    next('/login')
    return
  }

  // Se estiver autenticado mas não concluiu onboarding,
  // qualquer rota (exceto a própria de onboarding) redireciona para onboarding
  if (!auth.hasCompletedOnboarding && to?.name !== 'onboarding') {
    next('/onboarding')
    return
  }

  // Se onboarding já foi concluído, não faz sentido voltar para a tela de onboarding
  if (auth.hasCompletedOnboarding && to?.name === 'onboarding') {
    next('/home')
    return
  }

  // Controle de acesso por permissão (apenas após login e onboarding)
  const permissionsStore = usePermissionsStore()
  await permissionsStore.ensureLoaded()

  const routeName = (to?.name as string | undefined) ?? ''
  const requiredPermission = ROUTE_PERMISSIONS[routeName] ?? null

  if (!permissionsStore.hasPermission(requiredPermission)) {
    next('/home')
    return
  }

  next()
}

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      beforeEnter: ifNotAuthenticated,
      component: Login,
    },
    {
      path: '/onboarding',
      name: 'onboarding',
      beforeEnter: ifAuthenticated,
      component: Onboarding,
    },
    {
      path: '/',
      redirect: 'home',
      beforeEnter: ifAuthenticated,
      component: PageBody,
      children: [
        { path: 'home', name: 'home', component: Home },
        {
          path: 'agenda',
          name: 'agenda',
          component: Schedule,
        },
        {
          path: 'perfil-profissional',
          name: 'professional-profile',
          component: ProfessionalProfile,
        },
        {
          path: 'pacientes',
          name: 'patients-list',
          component: PatientsList,
        },
        {
          path: 'prontuario/:pacienteId?',
          name: 'medical-record',
          component: MedicalRecord,
        },
        {
          path: 'estabelecimento',
          name: 'establishment-settings',
          component: EstablishmentSettings,
        },
        {
          path: 'profissionais',
          name: 'professionals-management',
          component: ProfessionalsManagement,
        },
        {
          path: 'permissoes',
          name: 'permissions-management',
          component: PermissionsManagement,
        },
        {
          path: 'estoque',
          name: 'inventory-management',
          component: Inventory,
        },
        {
          path: 'modelos-prontuario',
          name: 'medical-record-models',
          component: MedicalRecordModels,
        },
        {
          path: 'minhas-consultas',
          name: 'medical-worklist',
          component: MedicalWorklist,
        },
      ],
    },
  ],
})

export default router
