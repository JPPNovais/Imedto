import { defineStore } from 'pinia'
import { ref } from 'vue'

type FeedbackType = 'info' | 'success' | 'error'

export const useFeedbackStore = defineStore('feedback-store', () => {
  const visible = ref(false)
  const message = ref('')
  const type = ref<FeedbackType>('info')
  const timeoutId = ref<number | null>(null)

  function show(
    msg: string,
    kind: FeedbackType = 'info',
    duration = 4000,
  ): void {
    message.value = msg
    type.value = kind
    visible.value = true

    if (timeoutId.value) {
      window.clearTimeout(timeoutId.value)
    }

    timeoutId.value = window.setTimeout(() => {
      visible.value = false
    }, duration)
  }

  function info(msg: string, duration?: number) {
    show(msg, 'info', duration)
  }

  function success(msg: string, duration?: number) {
    show(msg, 'success', duration)
  }

  function error(msg: string, duration?: number) {
    show(msg, 'error', duration)
  }

  function clear() {
    visible.value = false
    message.value = ''
  }

  return {
    visible,
    message,
    type,
    show,
    info,
    success,
    error,
    clear,
  }
})

