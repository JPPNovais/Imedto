<template>
  <transition name="fade">
    <div
      v-if="feedback.visible"
      class="fixed top-4 inset-x-0 z-50 flex justify-center px-4 pointer-events-none"
    >
      <div
        class="pointer-events-auto max-w-md w-full rounded-lg shadow-md px-4 py-3 text-sm flex items-start gap-2"
        :class="variantClass"
      >
        <span class="mt-0.5">
          <span v-if="feedback.type === 'success'">✅</span>
          <span v-else-if="feedback.type === 'error'">⚠️</span>
          <span v-else>ℹ️</span>
        </span>
        <p class="flex-1">
          {{ feedback.message }}
        </p>
        <button
          type="button"
          class="ml-2 text-xs opacity-70 hover:opacity-100"
          @click="feedback.clear"
        >
          x
        </button>
      </div>
    </div>
  </transition>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useFeedbackStore } from '@/stores/feedback'

const feedback = useFeedbackStore()

const variantClass = computed(() => {
  if (feedback.type === 'success') {
    return 'bg-green-50 text-green-800 border border-green-200'
  }
  if (feedback.type === 'error') {
    return 'bg-red-50 text-red-800 border border-red-200'
  }
  return 'bg-primary-50 text-primary-800 border border-primary-100'
})
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}
</style>

