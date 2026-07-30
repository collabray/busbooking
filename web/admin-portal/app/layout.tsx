export const metadata = {
  title: 'OmniBus EA - Super Admin Portal',
  description: 'Enterprise Operations & Control Suite',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-100">{children}</body>
    </html>
  )
}
