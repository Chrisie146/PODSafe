import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Enhanced analytics map with heatmap visualization, clustering, 
/// summary statistics overlay, and filtering options
class AnalyticsMapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> locations; // List of {latitude, longitude, type, id}
  final double height;
  final Function(Map<String, dynamic>)? onLocationTap;

  const AnalyticsMapWidget({
    super.key,
    required this.locations,
    this.height = 350,
    this.onLocationTap,
  });

  @override
  State<AnalyticsMapWidget> createState() => _AnalyticsMapWidgetState();
}

class _AnalyticsMapWidgetState extends State<AnalyticsMapWidget> {
  late MapController _mapController;
  
  // Filtering and view options
  String _selectedFilter = 'all'; // all, pod, claim
  bool _showHeatmap = true;
  bool _showClusters = true;
  bool _showStats = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Delay to allow map to initialize before fitting bounds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _fitBoundsToMarkers();
        }
      });
    });
  }
  
  /// Get filtered locations based on current filter
  List<Map<String, dynamic>> _getFilteredLocations() {
    if (_selectedFilter == 'all') return widget.locations;
    return widget.locations.where((loc) => 
      loc['type'].toString().toLowerCase() == _selectedFilter.toLowerCase()
    ).toList();
  }
  
  /// Calculate location density for heatmap (clusters per grid cell)
  Map<String, int> _calculateDensity() {
    final filtered = _getFilteredLocations();
    if (filtered.isEmpty) return {};
    
    // Create a grid-based density map (10km x 10km cells)
    Map<String, int> density = {};
    
    for (var loc in filtered) {
      final lat = (loc['latitude'] as double).toStringAsFixed(1);
      final lng = (loc['longitude'] as double).toStringAsFixed(1);
      final key = '$lat,$lng';
      density[key] = (density[key] ?? 0) + 1;
    }
    
    return density;
  }
  
  /// Get color intensity based on density (heatmap effect)
  Color _getDensityColor(int count) {
    if (count < 2) return Colors.yellow.withValues(alpha: 77);
    if (count < 5) return Colors.orange.withValues(alpha: 102);
    if (count < 10) return Colors.deepOrange.withValues(alpha: 128);
    return Colors.red.withValues(alpha: 153);
  }
  
  /// Calculate summary statistics
  Map<String, dynamic> _calculateStats() {
    final filtered = _getFilteredLocations();
    
    int podCount = 0;
    int claimCount = 0;
    double totalClaimAmount = 0.0;
    Set<String> customers = {};
    
    for (var loc in filtered) {
      final type = loc['type'].toString().toLowerCase();
      if (type == 'pod') {
        podCount++;
      } else if (type == 'claim') {
        claimCount++;
        totalClaimAmount += (loc['claimAmount'] as num?)?.toDouble() ?? 0.0;
      }
      
      final customerId = loc['customerId'] as String?;
      if (customerId != null && customerId.isNotEmpty) {
        customers.add(customerId);
      }
    }
    
    return {
      'total': filtered.length,
      'pods': podCount,
      'claims': claimCount,
      'totalClaimAmount': totalClaimAmount,
      'uniqueCustomers': customers.length,
      'coverageArea': _calculateCoverageArea(filtered),
    };
  }
  
  /// Calculate coverage area (bounding box area in km²)
  double _calculateCoverageArea(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) return 0.0;
    
    double minLat = filtered.first['latitude'];
    double maxLat = filtered.first['latitude'];
    double minLng = filtered.first['longitude'];
    double maxLng = filtered.first['longitude'];
    
    for (var loc in filtered) {
      minLat = min(minLat, loc['latitude']);
      maxLat = max(maxLat, loc['latitude']);
      minLng = min(minLng, loc['longitude']);
      maxLng = max(maxLng, loc['longitude']);
    }
    
    // Simple approximation: 111 km per degree latitude
    final latDiff = (maxLat - minLat) * 111;
    final lngDiff = (maxLng - minLng) * 111 * (cos(minLat * 3.14159 / 180));
    
    return latDiff * lngDiff;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Calculate bounds to fit all markers
  void _fitBoundsToMarkers() {
    final filtered = _getFilteredLocations();
    if (filtered.isEmpty) return;

    double minLat = filtered.first['latitude'];
    double maxLat = filtered.first['latitude'];
    double minLng = filtered.first['longitude'];
    double maxLng = filtered.first['longitude'];

    for (var location in filtered) {
      minLat = min(minLat, location['latitude']);
      maxLat = max(maxLat, location['latitude']);
      minLng = min(minLng, location['longitude']);
      maxLng = max(maxLng, location['longitude']);
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: EdgeInsets.all(100)),
    );
  }

  /// Get color based on location type (POD or Claim)
  Color _getMarkerColor(String type) {
    switch (type.toLowerCase()) {
      case 'pod':
        return Colors.green;
      case 'claim':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  /// Get icon based on location type
  IconData _getMarkerIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pod':
        return Icons.local_shipping;
      case 'claim':
        return Icons.error;
      default:
        return Icons.location_on;
    }
  }

  /// Show location details in bottom sheet
  Widget _buildPodDetails(Map<String, dynamic> location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 18, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'POD Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Customer:', location['customerName'] ?? 'Unknown'),
              _buildDetailRow('Invoice:', location['invoiceNumber'] ?? 'N/A'),
              _buildDetailRow('Order No:', location['deliveryId'] ?? 'N/A'),
              _buildDetailRow('Status:', location['status'] ?? 'pending'),
              if (location['vehicleInfo'] != null && location['vehicleInfo'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildDetailRow('Vehicle Reg:', location['vehicleInfo']),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildClaimDetails(Map<String, dynamic> location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location['title'] ?? 'Claim',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Customer No:', location['customerId'] ?? 'N/A'),
              _buildDetailRow('Customer:', location['customerName'] ?? 'Unknown'),
              _buildDetailRow('Account No:', location['customerAccountNumber'] ?? 'N/A'),
              _buildDetailRow('Invoice:', location['invoiceNumber'] ?? 'N/A'),
              _buildDetailRow('Driver:', location['driverName'] ?? 'Unknown'),
              if (location['vehicleInfo'] != null && location['vehicleInfo'].toString().isNotEmpty)
                _buildDetailRow('Vehicle Reg:', location['vehicleInfo']),
              _buildDetailRow('Amount:', 'R${(location['claimAmount'] ?? 0.0).toStringAsFixed(2)}'),
              if (location['podInfo'] != null && location['podInfo'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Related POD: ${location['podInfo']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getMarkerColor(location['type']).withValues(alpha: 51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getMarkerIcon(location['type']),
                        size: 16,
                        color: _getMarkerColor(location['type']),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        location['type'].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getMarkerColor(location['type']),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            
            // Location ID
            Text(
              'ID: ${location['id'] ?? 'Unknown'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // POD Details (if available)
            if (location['type'].toString().toLowerCase() == 'pod') ...[
              _buildPodDetails(location),
            ],
            
            // Claim Details (if available)
            if (location['type'].toString().toLowerCase() == 'claim') ...[
              _buildClaimDetails(location),
            ],
            
            // Coordinates
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Latitude: ${location['latitude']?.toStringAsFixed(6) ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Longitude: ${location['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onLocationTap?.call(location);
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build control bar with filters and toggles
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'Map Controls',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          
          // Filter buttons
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterButton('All', 'all'),
                      const SizedBox(width: 6),
                      _buildFilterButton('PODs', 'pod'),
                      const SizedBox(width: 6),
                      _buildFilterButton('Claims', 'claim'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Toggle buttons
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildToggleButton(
                      'Heatmap',
                      _showHeatmap,
                      () => setState(() => _showHeatmap = !_showHeatmap),
                    ),
                    _buildToggleButton(
                      'Clusters',
                      _showClusters,
                      () => setState(() => _showClusters = !_showClusters),
                    ),
                    _buildToggleButton(
                      'Stats',
                      _showStats,
                      () => setState(() => _showStats = !_showStats),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Build filter button
  Widget _buildFilterButton(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = value);
        Future.delayed(const Duration(milliseconds: 200), _fitBoundsToMarkers);
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue.withValues(alpha: 51),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
    );
  }
  
  /// Build toggle button
  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isActive,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.green.withValues(alpha: 51),
      side: BorderSide(
        color: isActive ? Colors.green : Colors.grey[300]!,
        width: isActive ? 2 : 1,
      ),
    );
  }
  
  /// Build summary statistics panel
  Widget _buildStatsPanel() {
    final stats = _calculateStats();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coverage Analytics',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.0,
            children: [
              _buildStatItem(
                'Total',
                stats['total'].toString(),
                Icons.location_on,
                Colors.blue,
              ),
              _buildStatItem(
                'PODs',
                stats['pods'].toString(),
                Icons.local_shipping,
                Colors.green,
              ),
              _buildStatItem(
                'Claims',
                stats['claims'].toString(),
                Icons.assignment,
                Colors.orange,
              ),
              _buildStatItem(
                'Customers',
                stats['uniqueCustomers'].toString(),
                Icons.person,
                Colors.purple,
              ),
              _buildStatItem(
                'Claim Amount',
                'R${(stats['totalClaimAmount'] as double).toStringAsFixed(0)}',
                Icons.money,
                Colors.red,
              ),
              _buildStatItem(
                'Coverage',
                '${(stats['coverageArea'] as double).toStringAsFixed(0)} km²',
                Icons.map,
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Build individual stat item
  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredLocations();
    
    if (filtered.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No location data available'),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate density for heatmap
    final density = _calculateDensity();
    
    // Build markers for each location
    List<Marker> markers = [];
    for (int i = 0; i < filtered.length; i++) {
      final location = filtered[i];
      final lat = location['latitude'] as double;
      final lng = location['longitude'] as double;
      final type = location['type'] as String? ?? 'delivery';

      final color = _getMarkerColor(type);
      final icon = _getMarkerIcon(type);

      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: LatLng(lat, lng),
          child: GestureDetector(
            onTap: () => _showLocationDetails(location),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 128),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }
    
    // Build heatmap circles for density visualization
    List<CircleMarker> heatmapLayers = [];
    if (_showHeatmap) {
      for (var entry in density.entries) {
        final parts = entry.key.split(',');
        final lat = double.parse(parts[0]);
        final lng = double.parse(parts[1]);
        final count = entry.value;
        
        heatmapLayers.add(
          CircleMarker(
            point: LatLng(lat, lng),
            radius: 15 + (count * 2.0),
            color: _getDensityColor(count),
            borderStrokeWidth: 2,
            borderColor: _getDensityColor(count).withValues(alpha: 204),
          ),
        );
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Control bar with filters
          _buildControlBar(),
          const SizedBox(height: 8),
          
          // Map
          SizedBox(
            height: widget.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(-25.7482, 28.2293), // Johannesburg, South Africa
                  initialZoom: 6,
                  minZoom: 2,
                  maxZoom: 18,
                ),
                children: [
                  // OpenStreetMap Tiles
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.podsafe',
                    maxNativeZoom: 19,
                    tileProvider: NetworkTileProvider(),
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('Tile loading error: $error');
                    },
                  ),
                  
                  // Heatmap layer (density circles)
                  if (_showHeatmap)
                    CircleLayer(circles: heatmapLayers),
                  
                  // Markers Layer
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Statistics panel
          if (_showStats)
            _buildStatsPanel(),
        ],
      ),
    );
  }
}

/// Import these math functions for bounds calculation and analytics
double min(double a, double b) => a < b ? a : b;
double max(double a, double b) => a > b ? a : b;
double cos(double radians) => _cos(radians);

double _cos(double x) {
  // Taylor series approximation for cosine
  double result = 1.0;
  double term = 1.0;
  for (int i = 1; i < 10; i++) {
    term *= -x * x / (2 * i * (2 * i - 1));
    result += term;
  }
  return result;
}
