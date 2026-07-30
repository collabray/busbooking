import 'package:flutter/material.dart';
import 'payment_screen.dart';
import '../services/api_service.dart';

class SeatSelectionScreen extends StatefulWidget {
  final dynamic schedule;
  const SeatSelectionScreen({super.key, required this.schedule});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  String? _selectedSeat;
  bool _loading = false;
  Map<String, dynamic>? _seatLayout;
  List<String> _bookedSeats = [];
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSeatLayout();
  }

  Future<void> _loadSeatLayout() async {
    try {
      final layout = await _api.getSeatLayout(widget.schedule['bus_id']);
      setState(() {
        _seatLayout = layout;
        _bookedSeats = List<String>.from(layout['booked'] ?? []);
      });
    } catch (e) {
      debugPrint('Failed to load seat layout: $e');
    }
  }

  Future<void> _lockSeat() async {
    if (_selectedSeat == null) return;
    setState(() => _loading = true);
    try {
      final result = await _api.lockSeat(
        widget.schedule['schedule_id'],
        _selectedSeat!,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              pnr: result['pnr'],
              schedule: widget.schedule,
              seat: _selectedSeat!,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to lock seat: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seats = _seatLayout?['seats'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Select Seat')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                _LegendItem(color: Colors.green, label: 'Available'),
                const SizedBox(width: 16),
                _LegendItem(color: Colors.grey, label: 'Booked'),
                const SizedBox(width: 16),
                _LegendItem(color: const Color(0xFF1E3A5F), label: 'Selected'),
              ],
            ),
          ),
          Expanded(
            child: _seatLayout == null
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: seats.length,
                    itemBuilder: (context, index) {
                      final seat = seats[index];
                      final seatNo = seat['number'] as String;
                      final isBooked = _bookedSeats.contains(seatNo);
                      final isSelected = _selectedSeat == seatNo;

                      return GestureDetector(
                        onTap: isBooked ? null : () => setState(() => _selectedSeat = seatNo),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isBooked
                                ? Colors.grey[300]
                                : isSelected
                                    ? const Color(0xFF1E3A5F)
                                    : Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF1E3A5F) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_seat,
                                  color: isBooked ? Colors.grey : isSelected ? Colors.white : Colors.green[800],
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  seatNo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isBooked ? Colors.grey[600] : isSelected ? Colors.white : Colors.green[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedSeat != null)
                    Text(
                      'Selected: Seat $_selectedSeat',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _selectedSeat == null || _loading ? null : _lockSeat,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Proceed to Payment'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
