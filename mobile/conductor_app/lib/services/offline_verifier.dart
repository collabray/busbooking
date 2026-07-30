import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class OfflineVerifier {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'conductor_manifest.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE manifest (
            pnr TEXT PRIMARY KEY,
            bus_id TEXT,
            seat_no TEXT,
            passenger_name TEXT,
            passenger_hash TEXT,
            expiry_timestamp TEXT,
            boarded INTEGER DEFAULT 0,
            boarded_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE public_keys (
            key_id TEXT PRIMARY KEY,
            public_key_b64 TEXT,
            downloaded_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pnr TEXT,
            action TEXT,
            payload TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  Future<Map<String, dynamic>> verifyTicket(String qrData) async {
    try {
      final decoded = base64Decode(qrData);
      final ticketJson = jsonDecode(utf8.decode(decoded));
      final payload = ticketJson['payload'];
      final signature = base64Decode(ticketJson['signature']);
      final pubKeyB64 = ticketJson['pub_key'];

      // In production: verify Ed25519 signature using cached public key
      // For this implementation, we validate structure and expiry
      final expiry = DateTime.parse(payload['expiry_timestamp']);
      final now = DateTime.now().toUtc();
      final valid = now.isBefore(expiry);

      return {
        'valid': valid,
        'pnr': payload['pnr'],
        'bus_id': payload['bus_id'],
        'seat_no': payload['seat_no'],
        'passenger_hash': payload['passenger_hash'],
        'expired': !valid,
      };
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  Future<void> markBoarded(String pnr) async {
    final db = await database;
    await db.update(
      'manifest',
      {'boarded': 1, 'boarded_at': DateTime.now().toIso8601String()},
      where: 'pnr = ?',
      whereArgs: [pnr],
    );
    await db.insert('sync_queue', {
      'pnr': pnr,
      'action': 'BOARDED',
      'payload': jsonEncode({'pnr': pnr, 'timestamp': DateTime.now().toIso8601String()}),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getManifest() async {
    final db = await database;
    return db.query('manifest', orderBy: 'seat_no');
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> downloadManifest() async {
    // In production: fetch from API
    final db = await database;
    // Clear old manifest
    await db.delete('manifest');
    // Insert demo data
    await db.insert('manifest', {
      'pnr': 'OBX1234ABC',
      'bus_id': 'bus-001',
      'seat_no': '12A',
      'passenger_name': 'John Doe',
      'passenger_hash': 'abc123',
      'expiry_timestamp': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'boarded': 0,
    });
    await db.insert('manifest', {
      'pnr': 'OBX5678DEF',
      'bus_id': 'bus-001',
      'seat_no': '5B',
      'passenger_name': 'Jane Smith',
      'passenger_hash': 'def456',
      'expiry_timestamp': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'boarded': 0,
    });
  }

  Future<void> uploadBoardingData() async {
    final db = await database;
    final pending = await db.query('sync_queue');
    // In production: POST to API
    await db.delete('sync_queue');
  }
}
