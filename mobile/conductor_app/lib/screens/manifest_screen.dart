import 'package:flutter/material.dart';
import '../services/offline_verifier.dart';

class ManifestScreen extends StatefulWidget {
  const ManifestScreen({super.key});

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  final OfflineVerifier _verifier = OfflineVerifier();
  List<Map<String, dynamic>> _manifest = [];

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    final manifest = await _verifier.getManifest();
    setState(() => _manifest = manifest);
  }

  @override
  Widget build(BuildContext context) {
    final boarded = _manifest.where((m) => m['boarded'] == true).length;
    final total = _manifest.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Manifest'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                label: Text('$boarded / $total Boarded'),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _manifest.isEmpty
          ? const Center(child: Text('No manifest data. Sync while online.'))
          : ListView.builder(
              itemCount: _manifest.length,
              itemBuilder: (context, index) {
                final passenger = _manifest[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: passenger['boarded'] == true ? Colors.green : Colors.grey,
                    child: Icon(
                      passenger['boarded'] == true ? Icons.check : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(passenger['passenger_name'] ?? 'Unknown'),
                  subtitle: Text('Seat: ${passenger['seat_no']} • PNR: ${passenger['pnr']}'),
                  trailing: passenger['boarded'] == true
                      ? const Chip(label: Text('BOARDED'), backgroundColor: Colors.green, labelStyle: TextStyle(color: Colors.white, fontSize: 10))
                      : const Chip(label: Text('PENDING'), backgroundColor: Colors.orange, labelStyle: TextStyle(color: Colors.white, fontSize: 10)),
                );
              },
            ),
    );
  }
}
