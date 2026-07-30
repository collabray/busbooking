import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        omnibus: {
          900: '#1E3A5F',
          800: '#2D5A7B',
          700: '#3D7A9B',
        },
      },
    },
  },
  plugins: [],
}
export default config
