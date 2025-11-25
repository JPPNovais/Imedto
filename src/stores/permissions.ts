import { ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabaseClient'
import { useAuthStore } from '@/stores/auth'
import { PERMISSIONS, PermissionId } from '@/constants/permissions'

export const usePermissionsStore = defineStore('permissions-store', () => {
  const permissions = ref<PermissionId[]>([])
  const isOwnerEstabelecimento = ref(false)
  const isLoaded = ref(false)
  const isLoading = ref(false)

  async function loadPermissions() {
    const auth = useAuthStore()
    permissions.value = []
    isOwnerEstabelecimento.value = false

    if (!auth.currentUser?.id) {
      isLoaded.value = true
      return
    }

    isLoading.value = true

    try {
      const { data: estabOwner, error: ownerError } = await supabase
        .from('estabelecimentos')
        .select('id')
        .eq('owner_usuario_id', auth.currentUser.id)
        .limit(1)
        .maybeSingle()

      if (ownerError) {
        console.error(ownerError)
      }

      if (estabOwner?.id) {
        isOwnerEstabelecimento.value = true
        permissions.value = PERMISSIONS.map((p) => p.id)
        isLoaded.value = true
        return
      }

      const { data: profissional, error: profError } = await supabase
        .from('profissionais')
        .select('id')
        .eq('usuario_id', auth.currentUser.id)
        .limit(1)
        .maybeSingle()

      if (profError) {
        console.error(profError)
        isLoaded.value = true
        return
      }

      if (!profissional?.id) {
        isLoaded.value = true
        return
      }

      const { data: vinculo, error: vincError } = await supabase
        .from('vinculo_profissional_estabelecimento')
        .select(
          `
          id,
          modelo:modelo_permissao_estabelecimento ( permissoes )
        `,
        )
        .eq('profissional_id', profissional.id)
        .eq('ativo', true)
        .limit(1)
        .maybeSingle()

      if (vincError) {
        console.error(vincError)
        isLoaded.value = true
        return
      }

      const rawPermissions = (vinculo?.modelo?.permissoes ?? []) as string[]
      permissions.value = rawPermissions.filter((p): p is PermissionId =>
        PERMISSIONS.some((def) => def.id === p),
      )
      isLoaded.value = true
    } finally {
      isLoading.value = false
    }
  }

  async function ensureLoaded() {
    if (isLoaded.value || isLoading.value) return
    await loadPermissions()
  }

  function hasPermission(id: PermissionId | null | undefined): boolean {
    if (!id) return true
    if (isOwnerEstabelecimento.value) return true
    return permissions.value.includes(id)
  }

  function reset() {
    permissions.value = []
    isOwnerEstabelecimento.value = false
    isLoaded.value = false
  }

  return {
    permissions,
    isOwnerEstabelecimento,
    isLoaded,
    isLoading,
    ensureLoaded,
    hasPermission,
    reset,
  }
})

