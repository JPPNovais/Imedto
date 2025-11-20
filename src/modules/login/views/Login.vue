<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
const auth = useAuthStore()
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

        <form class="flex flex-col gap-8 border-b border-gray-300 pb-10 mb-6">
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

          <div class="flex justify-between text-primary text-sm font-semibold">
            <a href="#" class="hover:underline underline-offset-2 transition">
              Lembrar conta
            </a>
            <a href="#" class="hover:underline underline-offset-2 transition">
              Esqueci minha senha
            </a>
          </div>

          <button
            type="submit"
            class="btn-primary"
            @click.prevent="auth.authenticate"
          >
            Entrar
          </button>
        </form>

        <p class="text-gray-800 text-center mb-4">Ou entre com:</p>
        <button type="button" class="btn-google">
          <img src="../../../assets/images/google-logo.png" alt="" />
          Google
        </button>
        <p class="text-center text-gray-800">
          Não tem uma conta?
          <a
            href="#"
            class="text-primary hover:underline underline-offset-2 transition"
          >
            Cadastre-se
          </a>
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
