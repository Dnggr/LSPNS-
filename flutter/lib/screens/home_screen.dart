import 'package:flutter/material.dart';
import '../models/report.dart';
import '../services/supabase_service.dart';
import '../screens/login_screen.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Report> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndSync();
  }

  Future<void> _loadAndSync() async {
    // Try to sync any offline drafts first
    try {
      await SupabaseService.syncOfflineReports();
    } catch (_) {}
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await SupabaseService.fetchMyReports();
      setState(() {
        _reports = reports;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offlineCount = SupabaseService.offlineQueueCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: Column(
        children: [
          // Offline queue banner
          if (offlineCount > 0)
            Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                      '$offlineCount report(s) queued offline. Will sync automatically.'),
                ],
              ),
            ),

          // Reports list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _reports.isEmpty
                        ? const Center(
                            child: Text('No reports yet.\nTap + to submit one.',
                                textAlign: TextAlign.center))
                        : RefreshIndicator(
                            onRefresh: _loadReports,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _reports.length,
                              itemBuilder: (_, i) => _ReportCard(
                                report: _reports[i],
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ReportDetailScreen(
                                              report: _reports[i])));
                                  _loadReports();
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Report'),
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NewReportScreen()));
          _loadReports();
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(_typeIcon(report.type), color: Colors.teal),
        title: Text(report.typeLabel,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.description != null)
              Text(report.description!,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              _formatDate(report.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: report.statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: report.statusColor),
          ),
          child: Text(
            report.statusLabel,
            style: TextStyle(
                color: report.statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
        isThreeLine: report.description != null,
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'street_light':
        return Icons.lightbulb_outline;
      case 'road_damage':
        return Icons.construction;
      case 'hazard':
        return Icons.warning_amber_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
