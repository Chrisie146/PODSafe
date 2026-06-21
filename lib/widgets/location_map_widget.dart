import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A reusable widget to display a location on a map using Flutter Map
/// Shows a single marker at the given coordinates with optional address
class LocationMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final double? accuracy;
  final double height;
  final bool showAccuracyCircle;

  const LocationMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.accuracy,
    this.height = 250,
    this.showAccuracyCircle = true,
  });

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = LatLng(widget.latitude, widget.longitude);
    
    // Validate coordinates
    if (widget.latitude < -90 || widget.latitude > 90 || 
        widget.longitude < -180 || widget.longitude > 180) {
      debugPrint('⚠️ Invalid GPS coordinates: lat=${widget.latitude}, lng=${widget.longitude}');
      debugPrint('   Expected: -90 to 90 for latitude, -180 to 180 for longitude');
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Invalid GPS coordinates:\n'
                'Lat: ${widget.latitude}, Lng: ${widget.longitude}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }
    
    debugPrint('✅ Valid GPS coordinates: lat=${widget.latitude}, lng=${widget.longitude}');

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Flutter Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: location,
                initialZoom: 16,
                minZoom: 5,
                maxZoom: 18,
              ),
              children: [
                // Map tiles from OpenStreetMap
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.podsafe',
                  // Add attribution
                  additionalOptions: const {
                    'Attribution': 'OpenStreetMap contributors',
                  },
                  errorTileCallback: (tile, error, stackTrace) {
                    // Handle tile loading errors silently to prevent exceptions
                    debugPrint('Tile loading error: $error');
                  },
                ),
                // Accuracy circle (if available)
                if (widget.showAccuracyCircle && widget.accuracy != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: location,
                        radius: widget.accuracy! / 100, // Convert meters to map units (rough)
                        useRadiusInMeter: true,
                        color: Colors.blue.withAlpha(50),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                // Marker
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(76),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: const Color(0xFF0A7E8C), // PODSafe primary color
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Info card overlay (top-left)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordinates
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: const Color(0xFF0A7E8C),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Accuracy (if available)
                    if (widget.accuracy != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.precision_manufacturing,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Accuracy: ${widget.accuracy!.toStringAsFixed(1)}m',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Address (if available)
                    if (widget.address != null && widget.address!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.address!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Zoom controls (bottom-right)
            Positioned(
              bottom: 8,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 4),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    onPressed: () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    },
                    child: const Icon(Icons.remove),
                  ),
                  const SizedBox(height: 4),
                  FloatingActionButton.small(
                    heroTag: 'center_map',
                    onPressed: () {
                      _mapController.move(
                        LatLng(widget.latitude, widget.longitude),
                        16,
                      );
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
