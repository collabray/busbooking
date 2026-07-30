'use client'
import { useState } from 'react'

export default function SearchWidget() {
  const [origin, setOrigin] = useState('')
  const [destination, setDestination] = useState('')
  const [date, setDate] = useState('')

  return (
    <div className="bg-white rounded-2xl shadow-xl p-6">
      <div className="grid md:grid-cols-4 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">From</label>
          <input
            type="text"
            value={origin}
            onChange={e => setOrigin(e.target.value)}
            placeholder="Nairobi"
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-omnibus-800 focus:border-transparent outline-none"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">To</label>
          <input
            type="text"
            value={destination}
            onChange={e => setDestination(e.target.value)}
            placeholder="Kampala"
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-omnibus-800 focus:border-transparent outline-none"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Date</label>
          <input
            type="date"
            value={date}
            onChange={e => setDate(e.target.value)}
            className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-omnibus-800 focus:border-transparent outline-none"
          />
        </div>
        <div className="flex items-end">
          <button className="w-full bg-omnibus-900 hover:bg-omnibus-800 text-white font-semibold py-3 px-6 rounded-xl transition flex items-center justify-center gap-2">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            Search Buses
          </button>
        </div>
      </div>
    </div>
  )
}
