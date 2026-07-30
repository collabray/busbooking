'use client'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts'

const data = [
  { name: 'Mon', KES: 420000, UGX: 180000, TZS: 320000 },
  { name: 'Tue', KES: 380000, UGX: 210000, TZS: 290000 },
  { name: 'Wed', KES: 510000, UGX: 195000, TZS: 350000 },
  { name: 'Thu', KES: 460000, UGX: 240000, TZS: 310000 },
  { name: 'Fri', KES: 620000, UGX: 280000, TZS: 420000 },
  { name: 'Sat', KES: 580000, UGX: 260000, TZS: 390000 },
  { name: 'Sun', KES: 490000, UGX: 220000, TZS: 340000 },
]

export default function RevenueChart() {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="name" stroke="#888" fontSize={12} />
        <YAxis stroke="#888" fontSize={12} />
        <Tooltip contentStyle={{ borderRadius: 8, border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }} />
        <Legend />
        <Line type="monotone" dataKey="KES" stroke="#1E3A5F" strokeWidth={2} dot={{ r: 4 }} />
        <Line type="monotone" dataKey="UGX" stroke="#7C3AED" strokeWidth={2} dot={{ r: 4 }} />
        <Line type="monotone" dataKey="TZS" stroke="#059669" strokeWidth={2} dot={{ r: 4 }} />
      </LineChart>
    </ResponsiveContainer>
  )
}
