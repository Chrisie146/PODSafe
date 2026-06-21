import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../models/delivery_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

/// Live tracking screen showing all active deliveries and driver locations
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<QuerySnapshot>? _deliveriesSubscription;
  StreamSubscription<QuerySnapshot>? _driversSubscription;
  
  // Track delivery and driver data
  final Map<String, Delivery> _activeDeliveries = {};
  final Map<String, Map<String, dynamic>> _driverLocations = {};
  final Map<String, Map<String, double>> _geocodedLocations = {}; // Cache for geocoded addresses
  
  // Map state
  bool _isLoading = true;
  String? _selectedDeliveryId;
  
  // Date range filter
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  
  // Initial camera position (South Africa - Johannesburg)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-26.2041, 28.0473),
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _setupRealTimeTracking();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _setupRealTimeTracking();
      });
    }
  }

  @override
  void dispose() {
    _deliveriesSubscription?.cancel();
    _driversSubscription?.cancel();
    if (_mapController != null) {
      try {
        _mapController!.dispose();
        _mapController = null;
      } catch (e) {
        debugPrint('Error disposing map controller: $e');
        _mapController = null;
      }
    }
    super.dispose();
  }

  void _setupRealTimeTracking() {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    // Listen to all deliveries (pending, in_transit, and delivered)
    // Note: We filter by date in the app after fetching to avoid complex indexes
    _deliveriesSubscription = FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: user.companyId)
        .where('status', whereIn: ['pending', 'in_transit', 'delivered'])
        .snapshots()
        .listen(_onDeliveriesUpdate);

    // Listen to driver locations
    _driversSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: user.companyId)
        .where('role', isEqualTo: 'driver')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen(_onDriversUpdate);
  }

  void _onDeliveriesUpdate(QuerySnapshot snapshot) async {
    
    setState(() {
      _activeDeliveries.clear();
    });
    
    for (var doc in snapshot.docs) {
      try {
        final delivery = Delivery.fromFirestore(doc);
        
        // Filter by date range - compare just the date part
        final createdDate = DateTime(
          delivery.createdAt.year,
          delivery.createdAt.month,
          delivery.createdAt.day,
        );
        final startDateOnly = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
        );
        final endDateOnly = DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
        );
        
        // Check if delivery is within date range
        if (createdDate.isBefore(startDateOnly) || createdDate.isAfter(endDateOnly)) {
          continue; // Skip deliveries outside date range
        }
        
        _activeDeliveries[delivery.id] = delivery;
        
        
        // If delivery has a POD, fetch its actual completion location
        if (delivery.podId != null && delivery.podId!.isNotEmpty) {
          _fetchPODLocation(delivery.id, delivery.podId!);
        } 
        // For pending/in-transit deliveries, geocode the customer address
        else if (delivery.customerAddress.isNotEmpty) {
          _geocodeAddress(delivery.id, delivery.customerAddress);
        }
      } catch (e) {
        
      }
    }
    
    setState(() {
      _updateMapMarkers();
      _isLoading = false;
    });
  }
  
  // Store POD locations separately
  final Map<String, Map<String, double>> _podLocations = {};
  
  Future<void> _fetchPODLocation(String deliveryId, String podId) async {
    try {
      
      
      final podDoc = await FirebaseFirestore.instance
          .collection('pods')
          .doc(podId)
          .get();
      
      if (podDoc.exists) {
        final data = podDoc.data() as Map<String, dynamic>;
        final location = data['location'] as Map<String, dynamic>?;
        
        
        if (location != null && 
            location['latitude'] != null && 
            location['longitude'] != null) {
          setState(() {
            _podLocations[deliveryId] = {
              'latitude': location['latitude'],
              'longitude': location['longitude'],
            };
            
            _updateMapMarkers();
          });
        } else {
          
        }
      } else {
        
      }
    } catch (e) {
      
    }
  }

  /// Geocode customer address for pending deliveries
  /// Uses city-based approximation since Google Geocoding API requires billing
  Future<void> _geocodeAddress(String deliveryId, String address) async {
    // Check cache first
    if (_geocodedLocations.containsKey(address)) {
      setState(() {
        _podLocations[deliveryId] = _geocodedLocations[address]!;
        _updateMapMarkers();
      });
      return;
    }

    
    // City center coordinates for major South African cities
    final cityCoordinates = {
      'johannesburg': {'latitude': -26.2041, 'longitude': 28.0473},
      'joburg': {'latitude': -26.2041, 'longitude': 28.0473},
      'sandton': {'latitude': -26.1076, 'longitude': 28.0567},
      'pretoria': {'latitude': -25.7479, 'longitude': 28.2293},
      'cape town': {'latitude': -33.9249, 'longitude': 18.4241},
      'durban': {'latitude': -29.8587, 'longitude': 31.0218},
      'port elizabeth': {'latitude': -33.9608, 'longitude': 25.6022},
      'bloemfontein': {'latitude': -29.0852, 'longitude': 26.1596},
      'east london': {'latitude': -33.0153, 'longitude': 27.9116},
      'pietermaritzburg': {'latitude': -29.6011, 'longitude': 30.3794},
      'nelspruit': {'latitude': -25.4748, 'longitude': 30.9699},
      'kimberley': {'latitude': -28.7282, 'longitude': 24.7499},
      'polokwane': {'latitude': -23.9045, 'longitude': 29.4689},
    };
    
    // Find matching city in address
    final addressLower = address.toLowerCase();
    Map<String, double>? coords;
    
    for (var entry in cityCoordinates.entries) {
      if (addressLower.contains(entry.key)) {
        coords = entry.value;
        
        break;
      }
    }
    
    // Fallback to Johannesburg if no city match
    coords ??= {'latitude': -26.2041, 'longitude': 28.0473};
    
    setState(() {
      _geocodedLocations[address] = coords!;
      _podLocations[deliveryId] = coords;
      
      _updateMapMarkers();
    });
  }

  double _getDeliveryColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BitmapDescriptor.hueOrange;
      case 'in_transit':
        return BitmapDescriptor.hueBlue;
      case 'delivered':
        return BitmapDescriptor.hueGreen;
      case 'failed':
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueYellow;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  void _onDriversUpdate(QuerySnapshot snapshot) {
    setState(() {
      _driverLocations.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['currentLocation'] != null) {
          _driverLocations[doc.id] = {
            'id': doc.id,
            'fullName': data['fullName'] ?? 'Unknown Driver',
            'location': data['currentLocation'],
            'lastUpdate': data['locationUpdatedAt'],
            'profileImageUrl': data['profileImageUrl'],
          };
        }
      }
      _updateMapMarkers();
    });
  }

  void _updateMapMarkers() {
    
    
    _markers.clear();
    _polylines.clear();

    

    // Add delivery markers (from POD locations only - completed deliveries)
    for (var delivery in _activeDeliveries.values) {
      final podLocation = _podLocations[delivery.id];
      final statusString = delivery.status.toString().split('.').last;
      
      
      if (podLocation != null) {
        
        
        final isSelected = _selectedDeliveryId == delivery.id;
        
        _markers.add(
          Marker(
            markerId: MarkerId('delivery_${delivery.id}'),
            position: LatLng(
              podLocation['latitude']!,
              podLocation['longitude']!,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _getDeliveryColor(statusString),
            ),
            infoWindow: InfoWindow(
              title: '📦 ${delivery.customerName}',
              snippet: '${_getStatusText(statusString)} - ${delivery.customerAddress}',
              onTap: () => _onMarkerTapped(delivery.id),
            ),
            alpha: isSelected ? 1.0 : 0.7,
          ),
        );
        
        
        // Draw route from driver to delivery location
        if (delivery.driverId.isNotEmpty && 
            _driverLocations.containsKey(delivery.driverId)) {
          final driverData = _driverLocations[delivery.driverId];
          final driverLoc = driverData!['location'] as GeoPoint;
          
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_${delivery.id}'),
              points: [
                LatLng(driverLoc.latitude, driverLoc.longitude),
                LatLng(podLocation['latitude']!, podLocation['longitude']!),
              ],
              color: isSelected 
                  ? const Color(0xFF2E7D8C) 
                  : const Color(0xFF2E7D8C).withAlpha(128),
              width: isSelected ? 4 : 2,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        }
      }
    }
    
    

    // Add driver markers
    for (var driverData in _driverLocations.values) {
      final location = driverData['location'] as GeoPoint;
      
      _markers.add(
        Marker(
          markerId: MarkerId('driver_${driverData['id']}'),
          position: LatLng(location.latitude, location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: '🚗 ${driverData['fullName']}',
            snippet: 'Active driver',
          ),
        ),
      );
    }
  }

  void _onMarkerTapped(String deliveryId) {
    setState(() {
      _selectedDeliveryId = deliveryId;
      _updateMapMarkers();
    });
  }

  void _zoomToDelivery(String deliveryId) {
    // TODO: Implement once delivery locations are added
    // For now, zoom to first driver if available
    if (_driverLocations.isNotEmpty) {
      final firstDriver = _driverLocations.values.first;
      final location = firstDriver['location'] as GeoPoint;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          15,
        ),
      );
    }
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty) return;

    final bounds = _calculateBounds(_markers.map((m) => m.position).toList());
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> positions) {
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 Live Tracking'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Date range filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: GestureDetector(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 51),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_startDate.month.toString().padLeft(2, '0')}/${_startDate.day.toString().padLeft(2, '0')} - ${_endDate.month.toString().padLeft(2, '0')}/${_endDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _fitAllMarkers,
            tooltip: 'Fit all markers',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _setupRealTimeTracking();
              });
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Sidebar with delivery list
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Stats header
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[50],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Deliveries',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildStatChip(
                                  '${_activeDeliveries.length}',
                                  'Total',
                                  Colors.blue,
                                  Icons.inventory_2,
                                ),
                                const SizedBox(width: 8),
                                _buildStatChip(
                                  '${_driverLocations.length}',
                                  'Drivers',
                                  Colors.green,
                                  Icons.local_shipping,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Delivery list
                      Expanded(
                        child: _activeDeliveries.isEmpty
                            ? const Center(
                                child: Text('No deliveries'),
                              )
                            : ListView.builder(
                                itemCount: _activeDeliveries.length,
                                itemBuilder: (context, index) {
                                  final delivery = _activeDeliveries.values
                                      .elementAt(index);
                                  final isSelected =
                                      _selectedDeliveryId == delivery.id;
                                  
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    color: isSelected
                                        ? AppTheme.primaryColor.withValues(alpha: 26)
                                        : null,
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.local_shipping,
                                        color: _getStatusColor(delivery.status.toString().split('.').last),
                                      ),
                                      title: Text(
                                        delivery.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            delivery.customerAddress,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                _getStatusText(delivery.status.toString().split('.').last),
                                                style: TextStyle(
                                                  color: _getStatusColor(
                                                      delivery.status.toString().split('.').last),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (_podLocations[delivery.id] == null)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 4),
                                                  child: SizedBox(
                                                    width: 10,
                                                    height: 10,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right,
                                      ),
                                      onTap: () {
                                        _onMarkerTapped(delivery.id);
                                        _zoomToDelivery(delivery.id);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                // Map
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: _initialPosition,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      Future.delayed(
                        const Duration(milliseconds: 500),
                        _fitAllMarkers,
                      );
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.withValues(alpha: 0.8);
      case 'in_transit':
        return Colors.blue.withValues(alpha: 0.8);
      case 'delivered':
        return Colors.green.withValues(alpha: 0.8);
      case 'failed':
        return Colors.red.withValues(alpha: 0.8);
      default:
        return Colors.grey.withValues(alpha: 0.8);
    }
  }
}
