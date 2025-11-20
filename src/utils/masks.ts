export function onlyDigits(value: string): string {
  return value.replace(/\D/g, '')
}

export function formatCpfCnpj(value: string): string {
  let digits = onlyDigits(value).slice(0, 14)

  if (digits.length <= 11) {
    // CPF: 000.000.000-00
    digits = digits.slice(0, 11)
    const parts = []
    if (digits.length > 3) {
      parts.push(digits.slice(0, 3))
      if (digits.length > 6) {
        parts.push(digits.slice(3, 6))
        if (digits.length > 9) {
          parts.push(digits.slice(6, 9))
          const suffix = digits.slice(9)
          return `${parts.join('.')}-${
            suffix.length ? suffix : ''
          }`.replace(/[-.]$/, '')
        }
        return `${parts.join('.')}.${
          digits.slice(6)
        }`.replace(/[.]$/, '')
      }
      return `${digits.slice(0, 3)}.${digits.slice(3)}`.replace(/[.]$/, '')
    }
    return digits
  }

  // CNPJ: 00.000.000/0000-00
  const cnpj = digits.slice(0, 14)
  const part1 = cnpj.slice(0, 2)
  const part2 = cnpj.slice(2, 5)
  const part3 = cnpj.slice(5, 8)
  const part4 = cnpj.slice(8, 12)
  const part5 = cnpj.slice(12)

  let result = part1
  if (part2) result += `.${part2}`
  if (part3) result += `.${part3}`
  if (part4) result += `/${part4}`
  if (part5) result += `-${part5}`
  return result
}

export function formatCep(value: string): string {
  const digits = onlyDigits(value).slice(0, 8)
  if (digits.length <= 5) return digits
  return `${digits.slice(0, 5)}-${digits.slice(5)}`
}

export function formatPhone(value: string): string {
  const digits = onlyDigits(value).slice(0, 11)

  if (digits.length <= 2) return digits

  const ddd = digits.slice(0, 2)
  const rest = digits.slice(2)

  if (rest.length <= 4) {
    return `(${ddd}) ${rest}`
  }

  if (rest.length <= 8) {
    return `(${ddd}) ${rest.slice(0, 4)}-${rest.slice(4)}`
  }

  // 9 dígitos no número
  return `(${ddd}) ${rest.slice(0, 5)}-${rest.slice(5)}`
}

