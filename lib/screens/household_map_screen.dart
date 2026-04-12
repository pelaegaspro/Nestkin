import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/family_location_model.dart';
import '../services/firestore_service.dart';
import '../services/location_repository.dart';
import '../services/location_service.dart';
import '../widgets/member_marker.dart';

class HouseholdMapScreen extends StatefulWidget {
  final String householdId;
  final double? initialFocusLat;
  final double? initialFocusLng;
  final String? highlightedMemberName;

  const HouseholdMapScreen({
    super.key,
    required this.householdId,
    this.initialFocusLat,
    this.initialFocusLng,
    this.highlightedMemberName,
  });

  @override
  State<HouseholdMapScreen> createState() => _HouseholdMapScreenState();
}

class _HouseholdMapScreenState extends State<HouseholdMapScreen> {
  final _locationService = LocationService();
  final _repository = LocationRepository();
  final _fs = FirestoreService();
  Timer? _timer;
  bool _sharing = true;
  bool _hasLocationPermission = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _startLocationUpdates() async {
    try {
      await _locationService.ensurePermission();
      if (mounted) {
        setState(() => _hasLocationPermission = true);
      }
      await _pushCurrentLocation();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_sharing) {
          _pushCurrentLocation();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _hasLocationPermission = false;
          _sharing = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pushCurrentLocation() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final members = await _fs.getHouseholdMembers(widget.householdId);
    final member = _firstWhereOrNull(members, (item) => item.userId == uid);
    if (member == null) {
      return;
    }

    final position = await _locationService.getCurrentPosition();
    await _repository.updateLocation(
      householdId: widget.householdId,
      userId: uid,
      latitude: position.latitude,
      longitude: position.longitude,
      memberName:
          (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member')
              .toString(),
      memberColor: member.color ?? '#0B5C68',
      isVisible: _sharing,
    );
  }

  Future<void> _toggleSharing(bool value) async {
    try {
      if (value) {
        await _locationService.ensurePermission();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _sharing = value;
        _hasLocationPermission = value;
        _error = null;
      });
      await _repository.setVisibility(
        householdId: widget.householdId,
        userId: FirebaseAuth.instance.currentUser!.uid,
        isVisible: value,
      );
      if (value) {
        await _pushCurrentLocation();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _sharing = false;
          _hasLocationPermission = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  String _subtitleForMember(
      FamilyLocationModel member, GeoPoint? homeLocation) {
    final lastSeen = MemberMarker.lastSeenLabel(member.lastUpdated);
    if (homeLocation == null) {
      return lastSeen;
    }

    final distance = _locationService.distanceInMeters(
      startLatitude: member.geopoint.latitude,
      startLongitude: member.geopoint.longitude,
      endLatitude: homeLocation.latitude,
      endLongitude: homeLocation.longitude,
    );
    if (distance <= 500) {
      return '$lastSeen - Arriving soon';
    }
    return lastSeen;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location'),
        actions: [
          Row(
            children: [
              const Text('Share'),
              Switch(
                value: _sharing,
                onChanged: _toggleSharing,
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<GeoPoint?>(
        future: _repository.getHomeLocation(widget.householdId),
        builder: (context, homeSnapshot) {
          return StreamBuilder<List<FamilyLocationModel>>(
            stream: _repository.locationStream(widget.householdId),
            builder: (context, snapshot) {
              if (homeSnapshot.hasError) {
                return const Center(
                  child: Text('Could not load home location right now.'),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Could not load family locations right now.'),
                );
              }

              final locations = snapshot.data ?? const <FamilyLocationModel>[];
              final markers = locations
                  .map(
                    (member) => MemberMarker.build(
                      member: member,
                      subtitle: _subtitleForMember(member, homeSnapshot.data),
                    ),
                  )
                  .toSet();
              if (widget.initialFocusLat != null &&
                  widget.initialFocusLng != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('sos_focus'),
                    position: LatLng(
                        widget.initialFocusLat!, widget.initialFocusLng!),
                    infoWindow: InfoWindow(
                      title: widget.highlightedMemberName ?? 'SOS location',
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      color: Colors.redAccent,
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.initialFocusLat != null &&
                                widget.initialFocusLng != null
                            ? LatLng(widget.initialFocusLat!,
                                widget.initialFocusLng!)
                            : locations.isEmpty
                                ? const LatLng(11.0168, 76.9558)
                                : LatLng(
                                    locations.first.geopoint.latitude,
                                    locations.first.geopoint.longitude,
                                  ),
                        zoom: 12,
                      ),
                      myLocationEnabled: _sharing && _hasLocationPermission,
                      myLocationButtonEnabled:
                          _sharing && _hasLocationPermission,
                      markers: markers,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
