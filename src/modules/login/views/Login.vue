<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { computed, ref } from 'vue'

const auth = useAuthStore()

const isRegisterMode = ref(false)

const isSubmitting = computed(() =>
  isRegisterMode.value ? auth.isRegistering : auth.isAuthenticating,
)

function handleForgotPassword() {
  if (!auth.userData.email) {
    // Deixa a validação para o store, que já mostra feedback
  }
  auth.sendPasswordResetEmail()
}

async function handleSubmit() {
  if (isRegisterMode.value) {
    const success = await auth.register()
    if (success) {
      isRegisterMode.value = false
    }
  } else {
    await auth.authenticate()
  }
}

function openRegisterMode() {
  isRegisterMode.value = true
}
</script>

<template>
  <main class="grid grid-cols-2 h-screen">
    <section class="bg-neutral-100 px-40 py-28 overflow-auto">
      <div class="max-w-xl mx-auto">
        <img
          src="../../../assets/images/imedto-logo.png"
          alt=""
          aria-hidden="true"
          class="mb-10"
        />
        <h4 class="mb-4">Acessar minha conta</h4>
        <p class="text-gray-800 mb-8">
          Preencha os campos abaixo para acessar sua conta:
        </p>

        <form
          class="flex flex-col gap-8 border-b border-gray-300 pb-10 mb-6"
          @submit.prevent="handleSubmit"
        >
          <div>
            <label for="email" class="sr-only">E-mail</label>
            <input
              id="email"
              v-model="auth.userData.email"
              type="email"
              placeholder="E-mail"
              class="form-input"
            />
          </div>

          <div>
            <label for="password" class="sr-only">Senha</label>
            <input
              id="password"
              type="password"
              v-model="auth.userData.password"
              placeholder="Senha"
              class="form-input"
            />
            <span class="text-xs text-gray-600">Help text</span>
          </div>

          <div v-if="isRegisterMode">
            <label for="passwordConfirm" class="sr-only">Confirmar senha</label>
            <input
              id="passwordConfirm"
              type="password"
              v-model="auth.userData.passwordConfirm"
              placeholder="Confirmar senha"
              class="form-input"
            />
          </div>

          <div
            class="flex justify-between items-center text-primary text-sm font-semibold"
          >
            <label class="inline-flex items-center gap-2 cursor-pointer">
              <input
                v-model="auth.rememberAccount"
                type="checkbox"
                class="rounded border-gray-300 text-primary focus:ring-primary"
              />
              <span>Lembrar conta</span>
            </label>
            <button
              type="button"
              class="hover:underline underline-offset-2 transition"
              @click.prevent="handleForgotPassword"
            >
              Esqueci minha senha
            </button>
          </div>

          <button
            type="submit"
            class="btn-primary disabled:opacity-60 disabled:cursor-not-allowed"
            :disabled="isSubmitting"
          >
            <span v-if="isSubmitting">
              {{ isRegisterMode ? 'Criando conta...' : 'Entrando...' }}
            </span>
            <span v-else>
              {{ isRegisterMode ? 'Criar conta' : 'Entrar' }}
            </span>
          </button>
        </form>

        <template v-if="!isRegisterMode">
          <p class="text-gray-800 text-center mb-4">
            Ou entre com:
          </p>
          <button type="button" class="btn-google">
            <img src="../../../assets/images/google-logo.png" alt="" />
            Google
          </button>
        </template>
        <p class="text-center text-gray-800">
          <template v-if="!isRegisterMode">
            Não tem uma conta?
            <button
              type="button"
              class="text-primary hover:underline underline-offset-2 transition"
              @click.prevent="openRegisterMode"
            >
              Cadastre-se
            </button>
          </template>
          <template v-else>
            Já tem uma conta?
            <button
              type="button"
              class="text-primary hover:underline underline-offset-2 transition"
              @click.prevent="isRegisterMode = false"
            >
              Acesse
            </button>
          </template>
        </p>
      </div>
    </section>
    <section class="hero -scale-x-100"></section>
  </main>
</template>

<style scoped>
.hero {
  background:
    linear-gradient(
      0deg,
      rgba(255, 255, 255, 0.4) 0%,
      rgba(255, 255, 255, 0.4) 100%
    ),
    url('../../../assets/images/hero-1.png') lightgray top center / cover
      no-repeat;
}
</style>
