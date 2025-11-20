import { reactive, ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabaseClient'
import { Session, User } from '@supabase/supabase-js'
import { useStorage } from '@vueuse/core'
import router from '@/router'

export const useAuthStore = defineStore('auth-store', () => {
  // STATES
  const isAuthenticated = ref(false)
  const userData = reactive({
    email: '',
    password: '',
  })
  const currentUser = useStorage(
    'currentUser',
    {} as Partial<User | Session>,
    sessionStorage,
  )

  // ACTIONS
  async function initialize() {
    isAuthenticated.value = false

    if (Object.keys(currentUser.value).length) {
      return (isAuthenticated.value = true)
    }
  }

  async function authenticate() {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: userData.email,
      password: userData.password,
    })

    // TODO: add toast
    if (error) {
      console.log(error)
      return
    }

    isAuthenticated.value = true
    currentUser.value = {
      id: data.user.id,
      email: data.user.email,
      access_token: data.session.access_token,
      expires_at: data.session.expires_at,
    }
    userData.email = ''
    userData.password = ''
    router.push('/')
  }

  async function logout() {
    const { error } = await supabase.auth.signOut()

    // TODO: add toast
    if (error) {
      console.log(error)
      return
    }

    currentUser.value = null
    isAuthenticated.value = false
    router.push('/login')
  }

  return {
    userData,
    isAuthenticated,
    currentUser,
    initialize,
    authenticate,
    logout,
  }
})
