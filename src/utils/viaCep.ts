import { formatCep, onlyDigits } from './masks'

export type ViaCepAddress = {
  cep: string
  logradouro: string
  complemento: string
  bairro: string
  localidade: string
  uf: string
}

export async function fetchAddressByCep(rawCep: string): Promise<ViaCepAddress | null> {
  const digits = onlyDigits(rawCep)
  if (digits.length !== 8) return null

  const cep = formatCep(digits)

  const response = await fetch(`https://viacep.com.br/ws/${digits}/json/`)
  if (!response.ok) return null

  const data = await response.json()
  if (data.erro) return null

  return {
    cep,
    logradouro: data.logradouro ?? '',
    complemento: data.complemento ?? '',
    bairro: data.bairro ?? '',
    localidade: data.localidade ?? '',
    uf: data.uf ?? '',
  }
}

