import 'package:flutter/material.dart';
import 'ticket_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _TicketCard(
            route: 'Nairobi → Kampala',
            seat: '12A',
            pnr: 'OBX1234ABC',
            date: '29 Jul 2026',
            status: 'UPCOMING',
            statusColor: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScreen(pnr: 'OBX1234ABC'))),
          ),
          _TicketCard(
            route: 'Dar es Salaam → Mombasa',
            seat: '5B',
            pnr: 'OBX5678DEF',
            date: '15 Aug 2026',
            status: 'UPCOMING',
            statusColor: Colors.green,
            onTap: () {},
          ),
          _TicketCard(
            route: 'Kampala → Nairobi',
            seat: '3C',
            pnr: 'OBX9012GHI',
            date: '10 Jul 2026',
            status: 'COMPLETED',
            statusColor: Colors.grey,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final String route, seat, pnr, date, status;
  final Color statusColor;
  final VoidCallback onTap;

  const _TicketCard({
    required this.route,
    required this.seat,
    required this.pnr,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.confirmation_number, color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Seat $seat • $date', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('PNR: $pnr', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Chip(
                label: Text(status, style: const TextStyle(fontSize: 10)),
                backgroundColor: statusColor.withOpacity(0.1),
                side: BorderSide.none,
                labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
