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

  if (auth.isAuthenticated) {
    next()
    return
  }

  next('/login')
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
      path: '/',
      redirect: 'home',
      beforeEnter: ifAuthenticated,
      component: PageBody,
      children: [{ path: 'home', name: 'home', component: Home }],
    },
  ],
})

export default router
