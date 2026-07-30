'use client'

export default function FleetMap() {
  return (
    <div className="h-96 bg-gray-100 rounded-lg flex items-center justify-center relative overflow-hidden">
      {/* Simulated map background */}
      <div className="absolute inset-0 opacity-20" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%239C92AC' fill-opacity='0.15'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
      }} />

      {/* Simulated bus markers */}
      {[
        { x: '20%', y: '30%', status: 'green', label: 'KBC 123X' },
        { x: '45%', y: '50%', status: 'green', label: 'KYZ 456P' },
        { x: '70%', y: '25%', status: 'yellow', label: 'T123 ABC' },
        { x: '35%', y: '70%', status: 'green', label: 'U789 DEF' },
        { x: '60%', y: '60%', status: 'red', label: 'KLM 321Q' },
        { x: '80%', y: '45%', status: 'green', label: 'T456 GHI' },
      ].map((bus, i) => (
        <div key={i} className="absolute group cursor-pointer" style={{ left: bus.x, top: bus.y }}>
          <div className={`w-4 h-4 rounded-full border-2 border-white shadow-lg ${
            bus.status === 'green' ? 'bg-green-500' :
            bus.status === 'yellow' ? 'bg-yellow-500' : 'bg-red-500'
          }`} />
          <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 hidden group-hover:block">
            <div className="bg-gray-900 text-white text-xs px-2 py-1 rounded whitespace-nowrap">
              {bus.label}
            </div>
          </div>
        </div>
      ))}

      <div className="absolute bottom-4 left-4 bg-white rounded-lg shadow px-4 py-2 text-sm text-gray-600">
        Mapbox / OpenStreetMap Integration
      </div>
    </div>
  )
}
