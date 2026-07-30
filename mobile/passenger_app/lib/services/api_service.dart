import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

class ApiService {
  static const String _baseUrl = 'https://api.omnibus.ea';
  final Box _session = Hive.box('userSession');

  Map<String, String> get _headers {
    final token = _session.get('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> requestOTP(String phone) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/otp/request'),
      headers: _headers,
      body: jsonEncode({'phone_number': phone}),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error']);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyOTP(String phone, String otp) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/otp/verify'),
      headers: _headers,
      body: jsonEncode({'phone_number': phone, 'otp': otp}),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error']);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> searchRoutes(String origin, String dest, DateTime date) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/v1/routes/search?origin=$origin&destination=$dest&date=${date.toIso8601String().split('T')[0]}'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Search failed');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> getSeatLayout(String busId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/v1/buses/$busId/seats'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load seats');
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> lockSeat(String scheduleId, String seatNumber) async {
    final userId = _session.get('user_id');
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/bookings/lock'),
      headers: _headers,
      body: jsonEncode({'schedule_id': scheduleId, 'seat_number': seatNumber, 'user_id': userId}),
    );
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['error']);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> initiatePayment(String pnr, String method) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/v1/payments/initiate'),
      headers: _headers,
      body: jsonEncode({'pnr': pnr, 'provider': method, 'amount': 0, 'currency': 'KES'}),
    );
    if (res.statusCode != 200) throw Exception('Payment initiation failed');
    return jsonDecode(res.body);
  }
}
