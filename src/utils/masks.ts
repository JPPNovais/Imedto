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

export function isValidCpf(cpf: string): boolean {
  const digits = onlyDigits(cpf)
  if (digits.length !== 11) return false
  if (/^(\d)\1{10}$/.test(digits)) return false

  const calcCheck = (base: string, factor: number) => {
    let total = 0
    for (let i = 0; i < base.length; i += 1) {
      total += parseInt(base[i], 10) * (factor - i)
    }
    const rest = (total * 10) % 11
    return rest === 10 ? 0 : rest
  }

  const d1 = calcCheck(digits.slice(0, 9), 10)
  const d2 = calcCheck(digits.slice(0, 10), 11)

  return d1 === parseInt(digits[9], 10) && d2 === parseInt(digits[10], 10)
}

export function isValidCnpj(cnpj: string): boolean {
  const digits = onlyDigits(cnpj)
  if (digits.length !== 14) return false
  if (/^(\d)\1{13}$/.test(digits)) return false

  const calcCheck = (base: string, factors: number[]) => {
    let total = 0
    for (let i = 0; i < base.length; i += 1) {
      total += parseInt(base[i], 10) * factors[i]
    }
    const rest = total % 11
    return rest < 2 ? 0 : 11 - rest
  }

  const base12 = digits.slice(0, 12)
  const base13 = digits.slice(0, 13)

  const d1 = calcCheck(base12, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
  const d2 = calcCheck(base13, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])

  return d1 === parseInt(digits[12], 10) && d2 === parseInt(digits[13], 10)
}

export function isValidCpfCnpj(value: string): boolean {
  const digits = onlyDigits(value)
  if (digits.length === 11) return isValidCpf(digits)
  if (digits.length === 14) return isValidCnpj(digits)
  return false
}
