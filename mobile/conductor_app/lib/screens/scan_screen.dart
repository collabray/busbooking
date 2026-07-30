import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/offline_verifier.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final OfflineVerifier _verifier = OfflineVerifier();
  String? _lastResult;
  bool _valid = false;
  bool _processing = false;
  Map<String, dynamic>? _ticketData;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _processing = true);
    try {
      final result = await _verifier.verifyTicket(barcode.rawValue!);
      setState(() {
        _lastResult = barcode.rawValue;
        _valid = result['valid'] == true;
        _ticketData = result;
        _processing = false;
      });

      if (_valid && result['pnr'] != null) {
        await _verifier.markBoarded(result['pnr'] as String);
      }
    } catch (e) {
      setState(() {
        _valid = false;
        _processing = false;
        _ticketData = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Ticket'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: _onDetect,
                  fit: BoxFit.cover,
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: _lastResult == null
                  ? _buildIdleState()
                  : _valid
                      ? _buildValidTicket()
                      : _buildInvalidTicket(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Scan passenger QR code', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildValidTicket() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VALID TICKET', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('PNR: ${_ticketData?['pnr'] ?? ''}'),
                    Text('Seat: ${_ticketData?['seat_no'] ?? ''}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('Passenger boarded successfully', textAlign: TextAlign.center, style: TextStyle(color: Colors.green)),
      ],
    );
  }

  Widget _buildInvalidTicket() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel, color: Colors.red, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVALID TICKET', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Text('Ticket verification failed or expired'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
