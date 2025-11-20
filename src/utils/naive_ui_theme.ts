import type { GlobalThemeOverrides } from 'naive-ui'

// Theme baseado na paleta que você enviou
// Primários: #241554, #452B97, #ABABE2
// Complementar (sucesso): #7BA14B / #5D9911
// Erro: #E32D2D
// Warning: #EBB300

const themeOverrides: GlobalThemeOverrides = {
  common: {
    fontFamily:
      'Nunito, -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
    primaryColor: '#452B97',
    primaryColorHover: '#241554',
    primaryColorPressed: '#241554',
    primaryColorSuppl: '#ABABE2',
    successColor: '#5D9911',
    warningColor: '#EBB300',
    errorColor: '#E32D2D',
  },
  Button: {
    borderRadiusSmall: '8px',
    borderRadiusMedium: '10px',
    borderRadiusLarge: '12px',
    paddingMedium: '0 18px',
  },
  Card: {
    borderRadius: '16px',
  },
}

export default themeOverrides

