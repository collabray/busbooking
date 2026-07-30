'use client'
import { useState } from 'react'
import Link from 'next/link'

export default function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <nav className="bg-white border-b">
      <div className="max-w-7xl mx-auto px-4">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link href="/" className="flex items-center gap-2">
              <div className="w-8 h-8 bg-omnibus-900 rounded-lg flex items-center justify-center">
                <svg className="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" /></svg>
              </div>
              <span className="text-xl font-bold text-omnibus-900">OmniBus EA</span>
            </Link>
          </div>
          <div className="hidden md:flex items-center gap-8">
            <Link href="/routes" className="text-gray-600 hover:text-omnibus-900">Routes</Link>
            <Link href="/cargo" className="text-gray-600 hover:text-omnibus-900">Cargo</Link>
            <Link href="/help" className="text-gray-600 hover:text-omnibus-900">Help</Link>
            <Link href="/login" className="px-4 py-2 bg-omnibus-900 text-white rounded-lg hover:bg-omnibus-800 transition">
              Sign In
            </Link>
          </div>
          <button className="md:hidden p-2" onClick={() => setMobileOpen(!mobileOpen)}>
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" /></svg>
          </button>
        </div>
      </div>
      {mobileOpen && (
        <div className="md:hidden border-t px-4 py-4 space-y-3">
          <Link href="/routes" className="block text-gray-600">Routes</Link>
          <Link href="/cargo" className="block text-gray-600">Cargo</Link>
          <Link href="/help" className="block text-gray-600">Help</Link>
          <Link href="/login" className="block text-omnibus-900 font-medium">Sign In</Link>
        </div>
      )}
    </nav>
  )
}
