interface Props {
  title: string
  value: string
  trend: string
  trendUp: boolean
  color: string
}

export default function StatCard({ title, value, trend, trendUp, color }: Props) {
  const colorMap: Record<string, string> = {
    blue: 'bg-blue-50 text-blue-900',
    green: 'bg-green-50 text-green-900',
    purple: 'bg-purple-50 text-purple-900',
    orange: 'bg-orange-50 text-orange-900',
  }

  return (
    <div className={`${colorMap[color]} rounded-xl p-6`}>
      <p className="text-sm font-medium opacity-70 mb-1">{title}</p>
      <div className="flex justify-between items-end">
        <span className="text-3xl font-bold">{value}</span>
        <span className={`text-sm font-bold px-2 py-1 rounded ${trendUp ? 'bg-white bg-opacity-60 text-green-700' : 'bg-white bg-opacity-60 text-red-700'}`}>
          {trend}
        </span>
      </div>
    </div>
  )
}
