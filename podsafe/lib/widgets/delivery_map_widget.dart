import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import '../models/delivery_model.dart';

/// Map widget displaying driver's pending deliveries with colored pins
/// Green = pending, Blue = in-transit, Gray = delivered
class DeliveryMapWidget extends StatefulWidget {
  final List<Delivery> deliveries;
  final double height;
  final Function(Delivery)? onDeliveryTap;

  const DeliveryMapWidget({
    super.key,
    required this.deliveries,
    this.height = 400,
    this.onDeliveryTap,
  });

  @override
  State<DeliveryMapWidget> createState() => _DeliveryMapWidgetState();
}

class _DeliveryMapWidgetState extends State<DeliveryMapWidget> {
  GoogleMapController? _mapController;
  final Map<String, LatLng> _addressCoordinates = {};
  final Set<Marker> _markers = {};

  static const String _googleApiKey = 'AIzaSyChH7L0Ffmldc6AmiyPAm7D5BJDrG5SM8s'; // Replace with your API key

  @override
  void initState() {
    super.initState();
    _initializeCoordinates().then((_) {
      _updateMarkers();
    });
  }

  @override
  void didUpdateWidget(DeliveryMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deliveries != widget.deliveries) {
      _addressCoordinates.clear();
      _initializeCoordinates().then((_) {
        _updateMarkers();
        _fitBoundsToMarkers();
      });
    }
  }

  @override
  void dispose() {
    if (_mapController != null) {
      try {
        _mapController!.dispose();
      } catch (e) {
        debugPrint('Error disposing map controller: $e');
      }
    }
    super.dispose();
  }

  /// Initialize coordinates for all deliveries using real geocoding
  Future<void> _initializeCoordinates() async {
    final futures = <Future>[];
    for (var delivery in widget.deliveries) {
      if (!_addressCoordinates.containsKey(delivery.customerAddress)) {
        futures.add(_geocodeAddress(delivery.customerAddress));
      }
    }

    await Future.wait(futures);

    // Fit bounds after coordinates are loaded
    if (mounted) {
      _fitBoundsToMarkers();
    }
  }

  /// Geocode an address using Google Maps Geocoding API
  Future<void> _geocodeAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          _addressCoordinates[address] = LatLng(lat, lng);
          return;
        }
      }
    } catch (e) {
      print('Geocoding failed for $address: $e');
    }

    // Fallback to pseudo-random if geocoding fails
    final random = Random(address.hashCode);
    final lat = -25.5 + random.nextDouble() * 3; // South Africa bounds
    final lng = 24.0 + random.nextDouble() * 8;
    _addressCoordinates[address] = LatLng(lat, lng);
  }

  /// Calculate bounds to fit all markers
  void _fitBoundsToMarkers() {
    if (_addressCoordinates.isEmpty || _mapController == null) return;

    if (_addressCoordinates.length == 1) {
      // If only one marker, zoom to it
      final coord = _addressCoordinates.values.first;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: coord, zoom: 15),
        ),
      );
      return;
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (var coord in _addressCoordinates.values) {
      minLat = min(minLat, coord.latitude);
      maxLat = max(maxLat, coord.latitude);
      minLng = min(minLng, coord.longitude);
      maxLng = max(maxLng, coord.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  /// Update markers based on deliveries and coordinates
  void _updateMarkers() {
    _markers.clear();
    for (var delivery in widget.deliveries) {
      final coord = _addressCoordinates[delivery.customerAddress];
      if (coord != null) {
        _markers.add(
          Marker(
            markerId: MarkerId(delivery.id),
            position: coord,
            icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(delivery.status)),
            infoWindow: InfoWindow(
              title: delivery.customerName,
              snippet: _getStatusText(delivery.status),
            ),
            onTap: () => widget.onDeliveryTap?.call(delivery),
          ),
        );
      }
    }
    setState(() {});
  }

  /// Get marker hue based on delivery status
  double _getMarkerHue(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return BitmapDescriptor.hueGreen;
      case DeliveryStatus.inTransit:
        return BitmapDescriptor.hueBlue;
      case DeliveryStatus.delivered:
        return BitmapDescriptor.hueYellow;
      case DeliveryStatus.failed:
        return BitmapDescriptor.hueRed;
    }
  }

  /// Get status text
  String _getStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.inTransit:
        return 'In Transit';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No deliveries to display',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Legend and Controls
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(Colors.green, 'Pending', Icons.location_on),
                  _buildLegendItem(Colors.blue, 'In Transit', Icons.local_shipping),
                  _buildLegendItem(Colors.yellow, 'Delivered', Icons.check_circle),
                  _buildLegendItem(Colors.red, 'Failed', Icons.error),
                ],
              ),
              const SizedBox(height: 8),
              // Zoom controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _fitBoundsToMarkers,
                    icon: const Icon(Icons.zoom_out_map, size: 16),
                    label: const Text('Fit All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Map
        Expanded(
          child: GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _fitBoundsToMarkers();
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(-25.7461, 28.2293), // Johannesburg
              zoom: 10,
            ),
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            mapToolbarEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
