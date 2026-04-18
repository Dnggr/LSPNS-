import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/report.dart';
import '../services/supabase_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await SupabaseService.fetchStatusLogs(widget.report.id);
      setState(() {
        _logs = logs;
      });
    } catch (_) {
    } finally {
      if (mounted)
        setState(() {
          _loadingLogs = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.typeLabel),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                const Text('Status: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: r.statusColor),
                  ),
                  child: Text(
                    r.statusLabel,
                    style: TextStyle(
                        color: r.statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Photo
            if (r.photoUrl != null) ...[
              const Text('Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: r.photoUrl!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description
            if (r.description != null) ...[
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(r.description!),
              const SizedBox(height: 12),
            ],

            // Location
            const Text('Location',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                'Lat: ${r.lat.toStringAsFixed(6)},  Lng: ${r.lng.toStringAsFixed(6)}',
                style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text('Submitted: ${_formatDate(r.createdAt)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),

            // Status history
            const Text('Status History',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            if (_loadingLogs)
              const CircularProgressIndicator()
            else if (_logs.isEmpty)
              const Text('No status updates yet.',
                  style: TextStyle(color: Colors.grey))
            else
              ..._logs.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${log['old_status'] ?? 'created'} → ${log['new_status']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              if (log['note'] != null)
                                Text(log['note'],
                                    style: const TextStyle(color: Colors.grey)),
                              Text(
                                _formatDate(DateTime.parse(log['changed_at'])),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
