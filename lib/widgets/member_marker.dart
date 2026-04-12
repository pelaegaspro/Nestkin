import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/family_location_model.dart';

class MemberMarker {
  static Marker build({
    required FamilyLocationModel member,
    required String subtitle,
  }) {
    return Marker(
      markerId: MarkerId(member.userId),
      position: LatLng(member.geopoint.latitude, member.geopoint.longitude),
      infoWindow: InfoWindow(
        title: member.memberName,
        snippet: subtitle,
      ),
    );
  }

  static String lastSeenLabel(Timestamp timestamp) {
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inMinutes < 1) {
      return 'Seen just now';
    }
    if (difference.inHours < 1) {
      return 'Seen ${difference.inMinutes}m ago';
    }
    return 'Seen ${difference.inHours}h ago';
  }
}
