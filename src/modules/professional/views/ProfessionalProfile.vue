<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { useFeedbackStore } from '@/stores/feedback'

type Profissao = {
  id: string
  nome: string
}

const auth = useAuthStore()
const feedback = useFeedbackStore()
const router = useRouter()

const isLoading = ref(false)
const isSaving = ref(false)
const profissoes = ref<Profissao[]>([])
const profissionalId = ref<string | null>(null)

const form = reactive({
  nomeExibicao: '',
  profissaoId: '',
  registroProfissional: '',
  conselho: '',
  ufConselho: '',
})

const isMedico = computed(() => {
  const prof = profissoes.value.find((p) => p.id === form.profissaoId)
  return prof ? /^m[ée]dico/i.test(prof.nome) : false
})

async function loadData() {
  if (!auth.currentUser?.id) {
    router.push('/login')
    return
  }

  isLoading.value = true
  try {
    const [profissoesResp, profissionalResp] = await Promise.all([
      supabase.from('profissoes').select('id, nome').order('nome', {
        ascending: true,
      }),
      supabase
        .from('profissionais')
        .select(
          'id, nome_exibicao, profissao_id, registro_profissional, conselho, uf_conselho',
        )
        .eq('usuario_id', auth.currentUser.id)
        .order('created_at', { ascending: true })
        .limit(1)
        .maybeSingle(),
    ])

    if (profissoesResp.error) {
      console.error(profissoesResp.error)
    } else if (profissoesResp.data) {
      profissoes.value = profissoesResp.data as Profissao[]
    }

    if (profissionalResp.data) {
      const p = profissionalResp.data
      profissionalId.value = p.id
      form.nomeExibicao = p.nome_exibicao ?? ''
      form.profissaoId = p.profissao_id ?? ''
      form.registroProfissional = p.registro_profissional ?? ''
      form.conselho = p.conselho ?? ''
      form.ufConselho = p.uf_conselho ?? ''
    }
  } finally {
    isLoading.value = false
  }
}

async function handleSave() {
  if (!auth.currentUser?.id) {
    feedback.error('Sessão expirada. Faça login novamente.')
    router.push('/login')
    return
  }

  if (!form.nomeExibicao || !form.profissaoId) {
    feedback.error('Informe o nome e a profissão para concluir o cadastro.')
    return
  }

  if (isMedico.value) {
    if (!form.registroProfissional || !form.conselho || !form.ufConselho) {
      feedback.error(
        'Para médicos, é obrigatório informar CRM/registro, conselho e UF.',
      )
      return
    }
  }

  isSaving.value = true

  try {
    const payload = {
      usuario_id: auth.currentUser.id as string,
      nome_exibicao: form.nomeExibicao,
      profissao_id: form.profissaoId || null,
      registro_profissional: form.registroProfissional || null,
      conselho: form.conselho || null,
      uf_conselho: form.ufConselho || null,
    }

    let error = null

    if (profissionalId.value) {
      const { error: updateError } = await supabase
        .from('profissionais')
        .update(payload)
        .eq('id', profissionalId.value)
      error = updateError
    } else {
      const { data, error: insertError } = await supabase
        .from('profissionais')
        .insert(payload)
        .select('id')
        .single()
      error = insertError
      if (data?.id) {
        profissionalId.value = data.id
      }
    }

    if (error) {
      console.error(error)
      feedback.error('Não foi possível salvar os dados do profissional.')
      return
    }

    feedback.success('Dados do profissional salvos com sucesso.')
  } finally {
    isSaving.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <section class="p-6">
    <header class="mb-6 flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-primary-700">
          Cadastro do profissional
        </h1>
        <p class="text-sm text-gray-500">
          Preencha os dados profissionais para concluir o seu cadastro.
        </p>
      </div>
    </header>

    <div class="max-w-3xl bg-white rounded-xl shadow-sm border border-gray-100 p-6">
      <form class="space-y-5" @submit.prevent="handleSave">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Nome de exibição
            </label>
            <input
              v-model="form.nomeExibicao"
              type="text"
              placeholder="Como seu nome deve aparecer para os pacientes"
              class="form-input"
            />
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Profissão
            </label>
            <select v-model="form.profissaoId" class="form-input">
              <option disabled value="">
                Selecione uma profissão
              </option>
              <option
                v-for="profissao in profissoes"
                :key="profissao.id"
                :value="profissao.id"
              >
                {{ profissao.nome }}
              </option>
            </select>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              {{ isMedico ? 'CRM' : 'Registro profissional' }}
            </label>
            <input
              v-model="form.registroProfissional"
              type="text"
              :placeholder="isMedico ? 'Informe seu CRM' : 'Informe seu registro'"
              class="form-input"
            />
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              Conselho
            </label>
            <input
              v-model="form.conselho"
              type="text"
              :placeholder="isMedico ? 'CRM' : 'Ex.: CRP'"
              class="form-input"
            />
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1">
              UF do conselho
            </label>
            <input
              v-model="form.ufConselho"
              type="text"
              maxlength="2"
              placeholder="UF"
              class="form-input uppercase"
            />
          </div>
        </div>

        <div class="flex justify-end mt-4">
          <button
            type="submit"
            class="btn-primary max-w-xs disabled:opacity-60 disabled:cursor-not-allowed"
            :disabled="isSaving || isLoading"
          >
            {{ isSaving ? 'Salvando...' : 'Salvar dados' }}
          </button>
        </div>
      </form>

      <p v-if="isLoading" class="mt-3 text-xs text-gray-400">
        Carregando dados do profissional...
      </p>
    </div>
  </section>
</template>
