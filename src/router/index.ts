import {
  createRouter,
  createWebHistory,
  NavigationGuardNext,
  RouteLocationNormalized,
} from 'vue-router'
import { useAuthStore } from '@/stores/auth'

// STRUCTURE
import PageBody from '@/modules/shared/structure/PageBody.vue'

// VIEWS
import Login from '@/modules/login/views/Login.vue'
import Home from '@/modules/home/views/Home.vue'
import Onboarding from '@/modules/onboarding/views/Onboarding.vue'
import Schedule from '@/modules/schedule/views/Schedule.vue'
import ProfessionalProfile from '@/modules/professional/views/ProfessionalProfile.vue'
import EstablishmentSettings from '@/modules/establishment/views/EstablishmentSettings.vue'

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

const ifAuthenticated = (
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
          path: 'profissional',
          name: 'professional-profile',
          component: ProfessionalProfile,
        },
        {
          path: 'estabelecimento',
          name: 'establishment-settings',
          component: EstablishmentSettings,
        },
      ],
    },
  ],
})

export default router
