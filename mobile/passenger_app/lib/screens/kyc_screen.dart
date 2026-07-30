import 'package:flutter/material.dart';

class KYCScreen extends StatefulWidget {
  const KYCScreen({super.key});

  @override
  State<KYCScreen> createState() => _KYCScreenState();
}

class _KYCScreenState extends State<KYCScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _gender = 'MALE';
  String _nationality = 'KEN';
  final _passportController = TextEditingController();
  bool _submitting = false;

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _submitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC submitted successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cross-border travel requires identity verification. Please provide your details below.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Legal Name', prefixIcon: Icon(Icons.person)),
                validator: (v) => v == null || v.length < 2 ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.people)),
                items: ['MALE', 'FEMALE', 'OTHER'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _nationality,
                decoration: const InputDecoration(labelText: 'Nationality', prefixIcon: Icon(Icons.flag)),
                items: ['KEN', 'UGA', 'TZA', 'RWA', 'BDI', 'SSD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _nationality = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passportController,
                decoration: const InputDecoration(labelText: 'Passport / National ID', prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('Upload ID Document Photo'),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () {}, child: const Text('Select File')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submitKYC,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit KYC'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
