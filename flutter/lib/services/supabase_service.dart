import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../models/report.dart';

class SupabaseService {
  static final _uuid = const Uuid();

  // ── AUTH ─────────────────────────────────────────────────

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': 'resident'},
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  static User? get currentUser => supabase.auth.currentUser;

  // ── REPORTS ──────────────────────────────────────────────

  static Future<List<Report>> fetchMyReports() async {
    final data = await supabase
        .from('reports')
        .select()
        .eq('user_id', currentUser!.id)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Report.fromJson(e)).toList();
  }

  static Future<List<Report>> fetchAllReports({String? statusFilter}) async {
    // 1. Start the query
    var query = supabase.from('reports').select();

    // 2. Apply filters FIRST
    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    // 3. Apply modifiers (ordering, limits) LAST
    final data = await query.order('created_at', ascending: false);

    return (data as List).map((e) => Report.fromJson(e)).toList();
  }

  static Future<void> submitReport({
    required String type,
    required double lat,
    required double lng,
    String? description,
    File? photo,
  }) async {
    String? photoUrl;

    if (photo != null) {
      final fileName = '${_uuid.v4()}.jpg';
      await supabase.storage.from('report-photos').upload(fileName, photo);
      photoUrl = supabase.storage.from('report-photos').getPublicUrl(fileName);
    }

    await supabase.from('reports').insert({
      'user_id': currentUser!.id,
      'type': type,
      'description': description,
      'lat': lat,
      'lng': lng,
      'photo_url': photoUrl,
      'status': 'pending',
    });
  }

  static Future<void> updateReportStatus({
    required String reportId,
    required String newStatus,
    String? note,
  }) async {
    await supabase
        .from('reports')
        .update({'status': newStatus}).eq('id', reportId);
  }

  // ── STATUS LOGS ──────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchStatusLogs(
      String reportId) async {
    final data = await supabase
        .from('status_logs')
        .select('*, changed_by_user:users(full_name)')
        .eq('report_id', reportId)
        .order('changed_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // ── OFFLINE QUEUE ────────────────────────────────────────

  static Box get _offlineBox => Hive.box('offline_reports');

  static void cacheOfflineReport(OfflineReport report) {
    _offlineBox.put(report.localId, report.toMap());
  }

  static List<OfflineReport> getOfflineReports() {
    return _offlineBox.values
        .map((v) => OfflineReport.fromMap(v as Map))
        .toList();
  }

  static Future<void> syncOfflineReports() async {
    final drafts = getOfflineReports();
    for (final draft in drafts) {
      try {
        File? photo;
        if (draft.localPhotoPath != null) {
          photo = File(draft.localPhotoPath!);
        }
        await submitReport(
          type: draft.type,
          lat: draft.lat,
          lng: draft.lng,
          description: draft.description,
          photo: photo,
        );
        await _offlineBox.delete(draft.localId);
      } catch (_) {
        // Will retry next sync
      }
    }
  }

  static int get offlineQueueCount => _offlineBox.length;
}
