import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./app/**/*.{js,ts,jsx,tsx}', './components/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        admin: { 900: '#0F172A', 800: '#1E293B', 700: '#334155' },
      },
    },
  },
  plugins: [],
}
export default config
