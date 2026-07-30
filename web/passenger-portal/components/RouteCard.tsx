interface Props {
  origin: string
  destination: string
  price: string
  currency: string
  duration: string
  busType: string
}

export default function RouteCard({ origin, destination, price, currency, duration, busType }: Props) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 p-6 hover:shadow-lg transition-shadow cursor-pointer">
      <div className="flex justify-between items-start mb-4">
        <div>
          <span className="inline-block px-3 py-1 bg-blue-50 text-blue-800 text-xs font-semibold rounded-full mb-2">
            {busType}
          </span>
          <h3 className="font-bold text-lg text-gray-900">{origin} → {destination}</h3>
          <p className="text-gray-500 text-sm">{duration} journey</p>
        </div>
        <span className="inline-block px-3 py-1 bg-green-50 text-green-800 text-xs font-bold rounded-full">
          POPULAR
        </span>
      </div>
      <div className="flex items-center justify-between pt-4 border-t">
        <div className="flex items-baseline gap-1">
          <span className="text-2xl font-bold text-omnibus-900">{price}</span>
          <span className="text-gray-500 text-sm">{currency}</span>
        </div>
        <button className="px-5 py-2.5 bg-omnibus-900 hover:bg-omnibus-800 text-white text-sm font-medium rounded-xl transition">
          Book Now
        </button>
      </div>
    </div>
  )
}
