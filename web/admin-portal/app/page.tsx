import Sidebar from '@/components/Sidebar'
import StatCard from '@/components/StatCard'
import RevenueChart from '@/components/RevenueChart'
import RecentActivity from '@/components/RecentActivity'
import FleetMap from '@/components/FleetMap'

export default function Dashboard() {
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <main className="flex-1 p-8 overflow-auto">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Operations Dashboard</h1>
            <p className="text-gray-500 mt-1">Real-time overview of fleet, bookings, and revenue</p>
          </div>
          <div className="flex gap-3">
            <button className="px-4 py-2 bg-white border rounded-lg text-sm font-medium hover:bg-gray-50">
              Export Report
            </button>
            <button className="px-4 py-2 bg-admin-900 text-white rounded-lg text-sm font-medium hover:bg-admin-800">
              + New Schedule
            </button>
          </div>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard title="Active Buses" value="142" trend="+5%" trendUp={true} color="blue" />
          <StatCard title="Today's Bookings" value="3,847" trend="+12%" trendUp={true} color="green" />
          <StatCard title="Revenue (KES)" value="1.2M" trend="+8%" trendUp={true} color="purple" />
          <StatCard title="Occupancy Rate" value="87%" trend="-2%" trendUp={false} color="orange" />
        </div>

        <div className="grid lg:grid-cols-3 gap-6 mb-8">
          <div className="lg:col-span-2 bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-bold mb-4">Revenue Trends</h2>
            <RevenueChart />
          </div>
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-bold mb-4">Recent Activity</h2>
            <RecentActivity />
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6 mb-8">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-bold">Live Fleet Radar</h2>
            <div className="flex gap-2">
              <span className="flex items-center gap-1 text-sm text-gray-600">
                <span className="w-2 h-2 bg-green-500 rounded-full"></span> On Route
              </span>
              <span className="flex items-center gap-1 text-sm text-gray-600">
                <span className="w-2 h-2 bg-yellow-500 rounded-full"></span> Delayed
              </span>
              <span className="flex items-center gap-1 text-sm text-gray-600">
                <span className="w-2 h-2 bg-red-500 rounded-full"></span> Alert
              </span>
            </div>
          </div>
          <FleetMap />
        </div>

        <div className="grid lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-bold mb-4">Top Routes by Revenue</h2>
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-gray-500 border-b">
                  <th className="pb-3">Route</th>
                  <th className="pb-3">Bookings</th>
                  <th className="pb-3">Revenue</th>
                  <th className="pb-3">Occupancy</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-b"><td className="py-3 font-medium">Nairobi → Kampala</td><td>1,245</td><td>KES 4.3M</td><td>94%</td></tr>
                <tr className="border-b"><td className="py-3 font-medium">Dar → Mombasa</td><td>892</td><td>TZS 40M</td><td>88%</td></tr>
                <tr className="border-b"><td className="py-3 font-medium">Kampala → Nairobi</td><td>756</td><td>UGX 64M</td><td>91%</td></tr>
                <tr><td className="py-3 font-medium">Nairobi → Mombasa</td><td>2,104</td><td>KES 3.1M</td><td>96%</td></tr>
              </tbody>
            </table>
          </div>
          <div className="bg-white rounded-xl shadow-sm p-6">
            <h2 className="text-lg font-bold mb-4">Operator Performance</h2>
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-gray-500 border-b">
                  <th className="pb-3">Operator</th>
                  <th className="pb-3">Buses</th>
                  <th className="pb-3">Trips</th>
                  <th className="pb-3">Rating</th>
                </tr>
              </thead>
              <tbody>
                <tr className="border-b"><td className="py-3 font-medium">Modern Coast</td><td>45</td><td>128</td><td>4.8</td></tr>
                <tr className="border-b"><td className="py-3 font-medium">Guardian Angel</td><td>32</td><td>96</td><td>4.6</td></tr>
                <tr className="border-b"><td className="py-3 font-medium">Tahmeed Coach</td><td>28</td><td>84</td><td>4.7</td></tr>
                <tr><td className="py-3 font-medium">Simba Coach</td><td>22</td><td>64</td><td>4.5</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </main>
    </div>
  )
}
