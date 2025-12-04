export type AnexoItem = {
  nome: string
  tipo: 'imagem' | 'pdf' | 'outro'
  tamanho: number
  previewUrl?: string
}

