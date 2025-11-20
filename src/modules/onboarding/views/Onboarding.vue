<template>
  <main class="min-h-screen bg-[#FBFBFF] flex items-start justify-center px-4">
    <section
      class="w-full max-w-2xl bg-white rounded-2xl shadow-md border border-primary-light px-10 py-10 mt-16 mb-16 min-h-0"
    >
      <div class="flex items-center justify-between mb-6">
        <img
          src="../../../assets/images/imedto-logo.png"
          alt="imedto"
          class="h-8"
        />
        <button
          type="button"
          class="text-xs text-gray-500 underline"
          @click="auth.logout"
        >
          Sair
        </button>
      </div>

      <div class="text-center mb-6">
        <h4 class="mb-2">Boas vindas!</h4>
        <p class="text-sm text-gray-600">
          Para continuar o seu acesso complete algumas informações para concluir
          o seu cadastro.
        </p>
      </div>

      <form class="space-y-6" @submit.prevent="handleSubmit">
        <div>
          <p class="text-sm font-semibold text-primary-dark mb-3">
            Informe o tipo de cadastro
          </p>
          <div class="grid grid-cols-2 gap-3">
            <button
              type="button"
              :class="[
                'py-3 px-3 rounded-lg border text-sm font-semibold',
                form.tipoCadastro === 'profissional'
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-primary-light hover:border-primary-medium',
              ]"
              @click="form.tipoCadastro = 'profissional'"
            >
              Profissional
            </button>
            <button
              type="button"
              :class="[
                'py-3 px-3 rounded-lg border text-sm font-semibold',
                form.tipoCadastro === 'estabelecimento'
                  ? 'bg-primary text-white border-primary'
                  : 'bg-white text-gray-700 border-primary-light hover:border-primary-medium',
              ]"
              @click="form.tipoCadastro = 'estabelecimento'"
            >
              Estabelecimento
            </button>
          </div>
        </div>

        <div>
          <span class="block text-sm font-semibold text-primary-dark mb-2">
            Tipo de pessoa
          </span>
          <div class="flex gap-6">
            <label
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                v-model="form.tipoPessoa"
                class="text-primary focus:ring-primary"
                name="tipoPessoa"
                type="radio"
                value="PF"
              />
              Pessoa Física
            </label>
            <label
              class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer"
            >
              <input
                v-model="form.tipoPessoa"
                class="text-primary focus:ring-primary"
                name="tipoPessoa"
                type="radio"
                value="PJ"
              />
              Pessoa Jurídica
            </label>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Nome completo
            </label>
            <input
              v-model="form.nomeCompleto"
              class="form-input"
              placeholder="Informe o seu nome"
              type="text"
            />
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              CPF / CNPJ
            </label>
            <input
              v-model="form.cpfCnpj"
              class="form-input"
              placeholder="Digite seu CPF ou CNPJ"
              type="text"
              maxlength="18"
              @input="form.cpfCnpj = formatCpfCnpj(form.cpfCnpj)"
            />
          </div>
        </div>

        <div v-if="form.tipoCadastro === 'estabelecimento'">
          <label class="block text-sm font-semibold text-gray-700 mb-1">
            Nome do estabelecimento
          </label>
          <input
            v-model="form.nomeEstabelecimento"
            class="form-input"
            placeholder="Ex: Clínica Nova Era"
            type="text"
          />
        </div>

        <p v-if="errorMessage" class="text-sm text-red-600">
          {{ errorMessage }}
        </p>

        <button
          class="btn-primary mt-2 disabled:opacity-60 disabled:cursor-not-allowed"
          :disabled="isSubmitting"
          type="submit"
        >
          {{ isSubmitting ? 'Salvando...' : 'Concluir' }}
        </button>
      </form>
    </section>
  </main>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import router from '@/router'
import { formatCpfCnpj } from '@/utils/masks'

const auth = useAuthStore()

const form = reactive({
  tipoCadastro: 'profissional' as 'profissional' | 'estabelecimento',
  tipoPessoa: 'PF' as 'PF' | 'PJ',
  nomeCompleto: '',
  cpfCnpj: '',
  nomeEstabelecimento: '',
})

const isSubmitting = ref(false)
  const errorMessage = ref('')

async function handleSubmit() {
  if (!auth.currentUser?.id) {
    errorMessage.value = 'Sessão expirada. Faça login novamente.'
    router.push('/login')
    return
  }

  if (!form.nomeCompleto || !form.cpfCnpj) {
    errorMessage.value = 'Preencha nome e CPF/CNPJ.'
    return
  }

  isSubmitting.value = true
  errorMessage.value = ''

	  try {
    const userId = auth.currentUser.id as string

    // upsert na tabela usuarios
    const { error: userError } = await supabase.from('usuarios').upsert(
      {
        id: userId,
        nome_completo: form.nomeCompleto,
        cpf_cnpj: form.cpfCnpj,
        tipo_pessoa: form.tipoPessoa,
        onboarding_concluido: true,
      },
      { onConflict: 'id' },
    )

    if (userError) throw userError

    // se for estabelecimento, criar estabelecimento + profissional + vínculo admin
    if (form.tipoCadastro === 'estabelecimento') {
      const { data: estabelecimento, error: estError } = await supabase
        .from('estabelecimentos')
        .insert({
          nome_fantasia: form.nomeEstabelecimento || form.nomeCompleto,
          tipo_pessoa: form.tipoPessoa,
          cpf_cnpj: form.cpfCnpj,
          owner_usuario_id: userId,
        })
        .select('id')
        .single()

      if (estError) throw estError

      const { data: profissional, error: profError } = await supabase
        .from('profissionais')
        .insert({
          usuario_id: userId,
          nome_exibicao: form.nomeCompleto,
        })
        .select('id')
        .single()

      if (profError) throw profError

      const { error: vinculoError } = await supabase
        .from('vinculo_profissional_estabelecimento')
        .insert({
          estabelecimento_id: estabelecimento.id,
          profissional_id: profissional.id,
          is_admin: true,
        })

      if (vinculoError) throw vinculoError
    } else {
      // apenas profissional (sem estabelecimento ainda)
      const { error: profError } = await supabase.from('profissionais').insert({
        usuario_id: userId,
        nome_exibicao: form.nomeCompleto,
      })

	      if (profError) throw profError
	    }

	    // marca onboarding como concluído no estado local do app
	    auth.hasCompletedOnboarding = true
	    router.push('/')
  } catch (err: any) {
    console.error(err)
    errorMessage.value = 'Ocorreu um erro ao salvar seu cadastro.'
  } finally {
    isSubmitting.value = false
  }
}
</script>
