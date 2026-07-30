import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'home_screen.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  final ApiService _api = ApiService();

  Future<void> _requestOTP() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _api.requestOTP(_phoneController.text.trim());
      setState(() { _otpSent = true; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _verifyOTP() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _api.verifyOTP(
        _phoneController.text.trim(),
        _otpController.text.trim(),
      );
      final box = Hive.box('userSession');
      await box.put('access_token', response['access_token']);
      await box.put('refresh_token', response['refresh_token']);
      await box.put('user_id', response['user']['user_id']);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              const Icon(Icons.phone_android, size: 64, color: Color(0xFF1E3A5F)),
              const SizedBox(height: 24),
              Text(
                _otpSent ? 'Enter OTP' : 'Get Started',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _otpSent
                    ? 'Enter the 6-digit code sent to ${_phoneController.text}'
                    : 'Enter your phone number to book bus tickets across East Africa',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (!_otpSent) ...[
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+254 712 345 678',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  decoration: InputDecoration(
                    labelText: 'OTP Code',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOTP : _requestOTP),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading ? null : _requestOTP,
                  child: const Text('Resend OTP'),
                ),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
