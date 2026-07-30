export const metadata = {
  title: 'OmniBus EA - Book Intercity Buses',
  description: 'East Africa's premier bus booking platform. Travel between Kenya, Uganda, and Tanzania safely and comfortably.',
  keywords: 'bus booking, East Africa, Kenya, Uganda, Tanzania, intercity travel',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-gray-50 font-sans antialiased">{children}</body>
    </html>
  )
}
