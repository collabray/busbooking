import 'package:flutter/material.dart';
import '../services/offline_verifier.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final OfflineVerifier _verifier = OfflineVerifier();
  bool _syncing = false;
  String _status = 'Ready to sync';
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final count = await _verifier.getPendingSyncCount();
    setState(() => _pendingCount = count);
  }

  Future<void> _sync() async {
    setState(() { _syncing = true; _status = 'Downloading manifest & keys...'; });
    try {
      await _verifier.downloadManifest();
      setState(() => _status = 'Manifest downloaded successfully');
      await _loadPendingCount();
    } catch (e) {
      setState(() => _status = 'Sync failed: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _uploadSync() async {
    setState(() { _syncing = true; _status = 'Uploading boarding data...'; });
    try {
      await _verifier.uploadBoardingData();
      setState(() => _status = 'Boarding data uploaded');
      await _loadPendingCount();
    } catch (e) {
      setState(() => _status = 'Upload failed: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Data')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_sync, size: 64, color: Colors.blue[800]),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_pendingCount pending items to sync',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncing ? null : _sync,
              icon: _syncing ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download),
              label: const Text('Download Manifest & Keys'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _syncing || _pendingCount == 0 ? null : _uploadSync,
              icon: const Icon(Icons.upload),
              label: const Text('Upload Boarding Data'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text(
              'Offline Mode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The conductor app works offline. Download the trip manifest and public keys while connected, then verify tickets without internet.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
