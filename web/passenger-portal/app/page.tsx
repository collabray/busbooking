import SearchWidget from '@/components/SearchWidget'
import RouteCard from '@/components/RouteCard'
import Navbar from '@/components/Navbar'
import Footer from '@/components/Footer'

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-1">
        {/* Hero Section */}
        <section className="bg-omnibus-900 text-white">
          <div className="max-w-7xl mx-auto px-4 py-16 sm:py-24">
            <div className="max-w-3xl">
              <h1 className="text-4xl sm:text-5xl font-bold mb-6">
                Travel Across East Africa
              </h1>
              <p className="text-lg text-blue-100 mb-8">
                Book safe, comfortable bus tickets between Kenya, Uganda, and Tanzania. 
                Real-time seat selection, secure payments, and instant tickets.
              </p>
            </div>
            <SearchWidget />
          </div>
        </section>

        {/* Popular Routes */}
        <section className="max-w-7xl mx-auto px-4 py-16">
          <div className="flex items-center justify-between mb-8">
            <h2 className="text-2xl font-bold text-gray-900">Popular Routes</h2>
            <a href="/routes" className="text-omnibus-800 font-medium hover:underline">
              View all routes →
            </a>
          </div>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <RouteCard origin="Nairobi" destination="Kampala" price="3,500" currency="KES" duration="12h" busType="VIP Coach" />
            <RouteCard origin="Dar es Salaam" destination="Mombasa" price="45,000" currency="TZS" duration="8h" busType="Executive" />
            <RouteCard origin="Kampala" destination="Nairobi" price="85,000" currency="UGX" duration="12h" busType="Standard" />
            <RouteCard origin="Nairobi" destination="Mombasa" price="1,500" currency="KES" duration="6h" busType="Express" />
            <RouteCard origin="Kampala" destination="Kigali" price="120,000" currency="UGX" duration="10h" busType="VIP Coach" />
            <RouteCard origin="Dar es Salaam" destination="Arusha" price="25,000" currency="TZS" duration="8h" busType="Standard" />
          </div>
        </section>

        {/* Features */}
        <section className="bg-white py-16">
          <div className="max-w-7xl mx-auto px-4">
            <h2 className="text-2xl font-bold text-center mb-12">Why Choose OmniBus EA?</h2>
            <div className="grid md:grid-cols-4 gap-8 text-center">
              <div>
                <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg className="w-8 h-8 text-omnibus-900" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                </div>
                <h3 className="font-bold mb-2">Real-time Booking</h3>
                <p className="text-gray-600 text-sm">Live seat availability with instant confirmation</p>
              </div>
              <div>
                <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg className="w-8 h-8 text-green-700" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>
                </div>
                <h3 className="font-bold mb-2">Secure Payments</h3>
                <p className="text-gray-600 text-sm">M-Pesa, Airtel Money, Tigo Pesa & more</p>
              </div>
              <div>
                <div className="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg className="w-8 h-8 text-purple-700" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" /></svg>
                </div>
                <h3 className="font-bold mb-2">Mobile Tickets</h3>
                <p className="text-gray-600 text-sm">QR code tickets — no printing needed</p>
              </div>
              <div>
                <div className="w-16 h-16 bg-orange-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg className="w-8 h-8 text-orange-700" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064" /></svg>
                </div>
                <h3 className="font-bold mb-2">Cross Border</h3>
                <p className="text-gray-600 text-sm">Seamless travel across Kenya, Uganda & Tanzania</p>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  )
}
