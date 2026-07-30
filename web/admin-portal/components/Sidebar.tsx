'use client'
import { useState } from 'react'

const menuItems = [
  { icon: '📊', label: 'Overview', active: true, href: '/' },
  { icon: '🚌', label: 'Fleet Management', href: '/fleet' },
  { icon: '🗺️', label: 'Routes & Schedules', href: '/routes' },
  { icon: '💰', label: 'Financials', href: '/financials' },
  { icon: '📦', label: 'Cargo', href: '/cargo' },
  { icon: '👥', label: 'Operators', href: '/operators' },
  { icon: '🔒', label: 'Security Vault', href: '/security' },
  { icon: '⚙️', label: 'Settings', href: '/settings' },
]

export default function Sidebar() {
  const [collapsed, setCollapsed] = useState(false)

  return (
    <aside className={`${collapsed ? 'w-20' : 'w-64'} bg-admin-900 text-white flex flex-col transition-all duration-300`}>
      <div className="p-6 border-b border-admin-700 flex items-center justify-between">
        {!collapsed && (
          <div>
            <h1 className="text-xl font-bold">OmniBus EA</h1>
            <p className="text-blue-300 text-xs">Super Admin</p>
          </div>
        )}
        <button onClick={() => setCollapsed(!collapsed)} className="p-1 hover:bg-admin-700 rounded">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" /></svg>
        </button>
      </div>
      <nav className="flex-1 p-4">
        {menuItems.map((item, i) => (
          <a key={i} href={item.href}
            className={`flex items-center gap-3 px-4 py-3 rounded-lg mb-1 transition ${item.active ? 'bg-admin-700 text-white' : 'text-blue-200 hover:bg-admin-700 hover:text-white'}`}>
            <span className="text-xl">{item.icon}</span>
            {!collapsed && <span className="font-medium text-sm">{item.label}</span>}
          </a>
        ))}
      </nav>
      <div className="p-4 border-t border-admin-700">
        <button className="flex items-center gap-3 text-blue-300 hover:text-white w-full">
          <span>🚪</span>
          {!collapsed && <span>Logout</span>}
        </button>
      </div>
    </aside>
  )
}
