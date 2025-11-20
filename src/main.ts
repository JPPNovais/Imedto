import './assets/css/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { useAuthStore } from './stores/auth'

import App from './App.vue'
import router from './router'

// NAIVE-UI
import naive from 'naive-ui'

const app = createApp(App)
app.use(createPinia())

// USER CONTEXT
const auth = useAuthStore()
await auth.initialize()

app.use(naive)
app.use(router)
app.mount('#app')
