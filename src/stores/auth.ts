import { reactive, ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabaseClient'
import { Session, User } from '@supabase/supabase-js'
import { useStorage } from '@vueuse/core'
import router from '@/router'
import { useFeedbackStore } from '@/stores/feedback'

export const useAuthStore = defineStore('auth-store', () => {
  // STATES
  const isAuthenticated = ref(false)
  const userData = reactive({
    email: '',
    password: '',
    passwordConfirm: '',
  })
  const currentUser = useStorage(
    'currentUser',
    {} as Partial<User | Session>,
    sessionStorage,
  )
  const rememberAccount = useStorage('rememberAccount', false, localStorage)
  const rememberedEmail = useStorage('rememberedEmail', '', localStorage)
  const hasCompletedOnboarding = ref(false)
  const isAuthenticating = ref(false)
  const isRegistering = ref(false)
  const isSendingResetEmail = ref(false)

  // ACTIONS
  async function initialize() {
    isAuthenticated.value = false
    hasCompletedOnboarding.value = false

    if (rememberAccount.value && rememberedEmail.value) {
      userData.email = rememberedEmail.value
    }

    if (!Object.keys(currentUser.value).length) return

    isAuthenticated.value = true

    const { data: usuario } = await supabase
      .from('usuarios')
      .select('onboarding_concluido')
      .eq('id', currentUser.value.id)
      .maybeSingle()

    hasCompletedOnboarding.value = !!usuario?.onboarding_concluido
  }

  async function authenticate() {
    const feedback = useFeedbackStore()

    if (!userData.email || !userData.password) {
      feedback.error('Informe e-mail e senha para acessar.')
      return
    }

    isAuthenticating.value = true

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: userData.email,
        password: userData.password,
      })

      if (error || !data.user || !data.session) {
        console.log(error)
        if (error?.message === 'Invalid login credentials') {
          feedback.error(
            'E-mail ou senha inválidos. Confira e tente novamente.',
          )
        } else {
          feedback.error(
            'Não foi possível fazer login agora. Tente novamente em instantes.',
          )
        }
        return
      }

      isAuthenticated.value = true
      currentUser.value = {
        id: data.user.id,
        email: data.user.email,
        access_token: data.session.access_token,
        expires_at: data.session.expires_at,
      }

      if (rememberAccount.value) {
        rememberedEmail.value = data.user.email ?? userData.email
      } else {
        rememberedEmail.value = ''
      }

      hasCompletedOnboarding.value = false
      userData.password = ''
      userData.passwordConfirm = ''
      // Decide para onde enviar: onboarding ou home
      const { data: usuario } = await supabase
        .from('usuarios')
        .select('onboarding_concluido')
        .eq('id', data.user.id)
        .maybeSingle()

      hasCompletedOnboarding.value = !!usuario?.onboarding_concluido

      if (!hasCompletedOnboarding.value) {
        router.push('/onboarding')
      } else {
        router.push('/')
      }
    } finally {
      isAuthenticating.value = false
    }
  }

  async function logout() {
    const feedback = useFeedbackStore()

    const { error } = await supabase.auth.signOut()

    if (error) {
      console.log(error)
      feedback.error('Não foi possível encerrar a sessão. Tente novamente.')
      return
    }

    currentUser.value = null
    isAuthenticated.value = false
    hasCompletedOnboarding.value = false
    router.push('/login')
  }

  async function register(): Promise<boolean> {
    const feedback = useFeedbackStore()

    if (!userData.email || !userData.password) {
      feedback.error('Informe e-mail e uma senha para cadastrar.')
      return false
    }

    if (userData.password !== userData.passwordConfirm) {
      feedback.error('As senhas não conferem. Verifique e tente novamente.')
      return false
    }

    isRegistering.value = true

    try {
      const { error } = await supabase.auth.signUp({
        email: userData.email,
        password: userData.password,
      })

      if (error) {
        console.log(error)
        feedback.error(
          'Não foi possível criar sua conta. Verifique os dados e tente novamente.',
        )
        return false
      }

      feedback.success(
        'Conta criada! Enviamos um e-mail para confirmar seu cadastro. Após confirmar, faça login com seus dados.',
      )

      // Após cadastro, limpa apenas as senhas
      userData.password = ''
      userData.passwordConfirm = ''

      // Mantém ou não o e-mail conforme a escolha
      if (!rememberAccount.value) {
        rememberedEmail.value = ''
      }

      return true
    } finally {
      isRegistering.value = false
    }
  }

  async function sendPasswordResetEmail() {
    const feedback = useFeedbackStore()

    if (!userData.email) {
      feedback.error('Informe o e-mail da conta para recuperar a senha.')
      return
    }

    isSendingResetEmail.value = true

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(
        userData.email,
        {
          redirectTo: `${window.location.origin}/reset-password`,
        },
      )

      if (error) {
        console.log(error)
        feedback.error(
          'Não foi possível enviar o e-mail de recuperação. Tente novamente.',
        )
        return
      }

      feedback.success(
        'Se existir uma conta com esse e-mail, você receberá instruções para redefinir a senha.',
      )
    } finally {
      isSendingResetEmail.value = false
    }
  }

  return {
    userData,
    isAuthenticated,
    currentUser,
    hasCompletedOnboarding,
    rememberAccount,
    isAuthenticating,
    isRegistering,
    isSendingResetEmail,
    initialize,
    authenticate,
    logout,
    register,
    sendPasswordResetEmail,
  }
})
