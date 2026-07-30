import 'package:flutter/material.dart';
import 'seat_selection_screen.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _originController = TextEditingController(text: 'Nairobi');
  final _destController = TextEditingController(text: 'Kampala');
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  List<dynamic> _results = [];
  String? _error;

  final ApiService _api = ApiService();

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await _api.searchRoutes(
        _originController.text,
        _destController.text,
        _selectedDate,
      );
      setState(() { _results = results; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Bus'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1E3A5F),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSearchField('From', _originController, Icons.location_on),
                const SizedBox(height: 8),
                _buildSearchField('To', _destController, Icons.location_on_outlined),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search),
                    label: Text(_loading ? 'Searching...' : 'Search Buses'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final route = _results[index];
                      return _RouteCard(
                        route: route,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SeatSelectionScreen(schedule: route),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Search for buses', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final dynamic route;
  final VoidCallback onTap;

  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final departure = DateTime.parse(route['departure_time']);
    final arrival = DateTime.parse(route['estimated_arrival_time']);
    final duration = arrival.difference(departure);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(route['bus_type'] ?? 'Standard'),
                    backgroundColor: Colors.blue[50],
                    side: BorderSide.none,
                  ),
                  if (route['is_cross_border'] == true)
                    Chip(
                      label: const Text('CROSS BORDER'),
                      backgroundColor: Colors.orange[50],
                      side: BorderSide.none,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(route['origin_city'], style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('${duration.inHours}h ${duration.inMinutes % 60}m', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const Divider(thickness: 2),
                        Text(route['registration_number'] ?? 'Bus', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(route['destination_city'], style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (route['amenities']?['wifi'] == true) const Icon(Icons.wifi, size: 18, color: Colors.grey),
                      if (route['amenities']?['ac'] == true) const Icon(Icons.ac_unit, size: 18, color: Colors.grey),
                      if (route['amenities']?['charger'] == true) const Icon(Icons.electrical_services, size: 18, color: Colors.grey),
                    ],
                  ),
                  Text(
                    '${route['base_price_usd']} USD',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
