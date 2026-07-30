const activities = [
  { action: 'New booking', detail: 'Nairobi → Kampala, Seat 12A', time: '2 min ago', type: 'booking' },
  { action: 'Payment received', detail: 'M-Pesa STK Push: KES 3,500', time: '5 min ago', type: 'payment' },
  { action: 'Bus departed', detail: 'KBC 123X from Nairobi', time: '12 min ago', type: 'fleet' },
  { action: 'KYC approved', detail: 'User ID: usr-8291', time: '18 min ago', type: 'kyc' },
  { action: 'Cargo loaded', detail: 'Tracking: CG123ABC, 15kg', time: '25 min ago', type: 'cargo' },
  { action: 'Alert triggered', detail: 'Bus KYZ 456P speed > 80km/h', time: '32 min ago', type: 'alert' },
]

export default function RecentActivity() {
  return (
    <div className="space-y-4">
      {activities.map((a, i) => (
        <div key={i} className="flex items-start gap-3 pb-3 border-b last:border-0">
          <div className={`w-2 h-2 rounded-full mt-2 flex-shrink-0 ${
            a.type === 'booking' ? 'bg-blue-500' :
            a.type === 'payment' ? 'bg-green-500' :
            a.type === 'fleet' ? 'bg-purple-500' :
            a.type === 'kyc' ? 'bg-yellow-500' :
            a.type === 'cargo' ? 'bg-orange-500' : 'bg-red-500'
          }`} />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-gray-900">{a.action}</p>
            <p className="text-xs text-gray-500 truncate">{a.detail}</p>
          </div>
          <span className="text-xs text-gray-400 flex-shrink-0">{a.time}</span>
        </div>
      ))}
    </div>
  )
}
