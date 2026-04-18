import 'package:flutter/material.dart';

class Report {
  final String id;
  final String? userId;
  final String type;
  final String? description;
  final double lat;
  final double lng;
  final String? photoUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Report({
    required this.id,
    this.userId,
    required this.type,
    this.description,
    required this.lat,
    required this.lng,
    this.photoUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      description: json['description'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      photoUrl: json['photo_url'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'street_light':
        return 'Street Light';
      case 'road_damage':
        return 'Road Damage';
      case 'hazard':
        return 'Hazard';
      case 'announcement':
        return 'Announcement';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'resolved':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// Offline draft model (stored in Hive)
class OfflineReport {
  final String localId;
  final String type;
  final String? description;
  final double lat;
  final double lng;
  final String? localPhotoPath;
  final DateTime createdAt;

  OfflineReport({
    required this.localId,
    required this.type,
    this.description,
    required this.lat,
    required this.lng,
    this.localPhotoPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'localId': localId,
        'type': type,
        'description': description,
        'lat': lat,
        'lng': lng,
        'localPhotoPath': localPhotoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineReport.fromMap(Map<dynamic, dynamic> map) => OfflineReport(
        localId: map['localId'],
        type: map['type'],
        description: map['description'],
        lat: map['lat'],
        lng: map['lng'],
        localPhotoPath: map['localPhotoPath'],
        createdAt: DateTime.parse(map['createdAt']),
      );
}
