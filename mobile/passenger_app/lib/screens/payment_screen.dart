import 'package:flutter/material.dart';
import 'ticket_screen.dart';
import '../services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final String pnr;
  final dynamic schedule;
  final String seat;

  const PaymentScreen({
    super.key,
    required this.pnr,
    required this.schedule,
    required this.seat,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'MPESA';
  bool _processing = false;
  final ApiService _api = ApiService();

  final List<Map<String, dynamic>> _methods = [
    {'id': 'MPESA', 'name': 'M-Pesa', 'icon': Icons.phone_android, 'color': Colors.green},
    {'id': 'AIRTEL', 'name': 'Airtel Money', 'icon': Icons.phone_android, 'color': Colors.red},
    {'id': 'TIGO', 'name': 'Tigo Pesa', 'icon': Icons.phone_android, 'color': Colors.blue},
  ];

  Future<void> _processPayment() async {
    setState(() => _processing = true);
    try {
      await _api.initiatePayment(widget.pnr, _selectedMethod);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Payment Initiated'),
            content: const Text('Please complete the payment on your phone. You will receive a confirmation shortly.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => TicketScreen(pnr: widget.pnr)),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e')),
      );
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E3A5F),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trip Summary', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${widget.schedule['origin_city']} → ${widget.schedule['destination_city']}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Seat: ${widget.seat}  •  PNR: ${widget.pnr}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Select Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ..._methods.map((method) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedMethod == method['id'] ? method['color'] as Color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(method['icon'] as IconData, color: method['color'] as Color),
                    title: Text(method['name'] as String),
                    trailing: _selectedMethod == method['id']
                        ? Icon(Icons.check_circle, color: method['color'] as Color)
                        : const Icon(Icons.radio_button_off),
                    onTap: () => setState(() => _selectedMethod = method['id'] as String),
                  ),
                )),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 16)),
                      Text(
                        '${widget.schedule['base_price_usd']} USD',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _processing ? null : _processPayment,
                child: _processing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Pay Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
