import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/csv_export_service.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/analytics_map_widget.dart';

class AnalyticsDashboardDesktop extends StatefulWidget {
  const AnalyticsDashboardDesktop({super.key});

  @override
  State<AnalyticsDashboardDesktop> createState() => _AnalyticsDashboardDesktopState();
}

class _AnalyticsDashboardDesktopState extends State<AnalyticsDashboardDesktop> {
  String _selectedPeriod = 'month'; // week, month, quarter, year, custom
  bool _isLoading = true;
  bool _showFilters = true;
  String _selectedChart = 'trend'; // trend, status, drivers, performance
  bool _showChartAsTable = false; // Toggle between chart and table view
  bool _showMetrics = true; // Collapse/expand metrics section
  
  // Date range for custom period
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Analytics data
  int _totalDeliveries = 0;
  int _completedDeliveries = 0;
  int _activeDeliveries = 0;
  int _pendingDeliveries = 0;
  int _failedDeliveries = 0;
  int _totalDrivers = 0;
  int _activeDrivers = 0;
  double _completionRate = 0.0;
  double _avgDeliveryTime = 0.0;
  
  // Invoice date metrics
  double _avgDaysToDeliver = 0.0;
  int _onTimeDeliveries = 0;
  int _lateDeliveries = 0;
  
  Map<String, int> _dailyDeliveries = {};
  Map<String, int> _deliveriesByStatus = {};
  List<Map<String, dynamic>> _topDrivers = [];
  List<Map<String, dynamic>> _performanceMetrics = [];
  List<Map<String, dynamic>> _locationData = [];
  
  // New metrics: Deliveries per truck, Claims data
  Map<String, int> _deliveriesPerTruck = {};
  int _totalClaims = 0;
  List<Map<String, dynamic>> _claimsPerCustomer = []; // Changed to List for customer details
  Set<String> _claimTypes = {};
  Map<String, int> _claimTypeCount = {}; // Top claim types with counts
  List<Map<String, dynamic>> _topCustomerDeliveries = []; // Top customers by delivery count
  List<Map<String, dynamic>> _topClaims = []; // Top claims with customer and reason
  
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }
  
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // 1-4 keys - Switch charts
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        setState(() => _selectedChart = 'trend');
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        setState(() => _selectedChart = 'status');
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
        setState(() => _selectedChart = 'drivers');
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
        setState(() => _selectedChart = 'performance');
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit5) {
        setState(() => _selectedChart = 'deliveries');
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit6) {
        setState(() => _selectedChart = 'claims');
        return KeyEventResult.handled;
      }
      // Ctrl+E - Export
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyE) {
        _showExportDialog();
        return KeyEventResult.handled;
      }
      // Ctrl+F - Toggle filters
      else if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        setState(() => _showFilters = !_showFilters);
        return KeyEventResult.handled;
      }
      // F5 - Refresh
      else if (event.logicalKey == LogicalKeyboardKey.f5) {
        _loadAnalytics();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadDeliveryStats(),
        _loadDriverStats(),
        _loadDailyDeliveries(),
        _loadTopDrivers(),
        _loadPerformanceMetrics(),
        _loadLocationData(),
        _loadDeliveriesPerTruck(),
        _loadClaimsData(),
        _loadTopCustomerDeliveries(),
      ]);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeliveryStats() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    Query query = FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId);

    // Apply date filter
    final dateRange = _getDateRange();
    if (dateRange != null) {
      query = query.where('scheduledDate', 
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
          .where('scheduledDate', 
          isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!));
    }

    final deliveriesSnapshot = await query.get();

    int total = deliveriesSnapshot.docs.length;
    int completed = 0;
    int active = 0;
    int pending = 0;
    int failed = 0;
    double totalTime = 0;
    int timedDeliveries = 0;
    
    // Invoice date metrics
    double totalDaysToDeliver = 0;
    int deliveriesWithInvoiceDate = 0;
    int onTimeDeliveries = 0;
    int lateDeliveries = 0;
    const int slaDays = 3; // Standard SLA: 3 days

    Map<String, int> statusCount = {};

    for (var doc in deliveriesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      
      final status = data['status'] as String?;
      if (status != null) {
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        switch (status) {
          case 'delivered':
            completed++;
            // Calculate delivery time (created to delivered)
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();
            if (createdAt != null && deliveredAt != null) {
              totalTime += deliveredAt.difference(createdAt).inHours.toDouble();
              timedDeliveries++;
            }
            
            // Calculate invoice date to delivery time
            final invoiceDate = (data['invoiceDate'] as Timestamp?)?.toDate();
            if (invoiceDate != null && deliveredAt != null) {
              final daysToDeliver = deliveredAt.difference(invoiceDate).inDays;
              totalDaysToDeliver += daysToDeliver;
              deliveriesWithInvoiceDate++;
              
              // Check SLA compliance
              if (daysToDeliver <= slaDays) {
                onTimeDeliveries++;
              } else {
                lateDeliveries++;
              }
            }
            break;
          case 'inTransit':
            active++;
            break;
          case 'pending':
            pending++;
            break;
          case 'failed':
            failed++;
            break;
        }
      }
    }

    setState(() {
      _totalDeliveries = total;
      _completedDeliveries = completed;
      _activeDeliveries = active;
      _pendingDeliveries = pending;
      _failedDeliveries = failed;
      _completionRate = total > 0 ? (completed / total) * 100 : 0.0;
      _avgDeliveryTime = timedDeliveries > 0 ? totalTime / timedDeliveries : 0.0;
      _deliveriesByStatus = statusCount;
      
      // Update invoice date metrics
      _avgDaysToDeliver = deliveriesWithInvoiceDate > 0 
          ? totalDaysToDeliver / deliveriesWithInvoiceDate 
          : 0.0;
      _onTimeDeliveries = onTimeDeliveries;
      _lateDeliveries = lateDeliveries;
    });
  }

  Future<void> _loadDriverStats() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    final driversSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .where('companyId', isEqualTo: companyId)
        .get();

    int total = driversSnapshot.docs.length;
    int active = 0;

    for (var doc in driversSnapshot.docs) {
      final approvalStatus = doc.data()['approvalStatus'] ?? 'approved';
      if (approvalStatus == 'approved') active++;
    }

    setState(() {
      _totalDrivers = total;
      _activeDrivers = active;
    });
  }

  Future<void> _loadDailyDeliveries() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    final dateRange = _getDateRange();
    if (dateRange == null) return;

    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .where('scheduledDate', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('scheduledDate', 
            isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!))
        .get();

    Map<String, int> dailyCounts = {};

    for (var doc in deliveriesSnapshot.docs) {
      final scheduledDate = (doc.data()['scheduledDate'] as Timestamp?)?.toDate();
      if (scheduledDate != null) {
        final dateKey = DateFormat('MMM d').format(scheduledDate);
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      }
    }

    setState(() {
      _dailyDeliveries = dailyCounts;
    });
  }

  Future<void> _loadTopDrivers() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'delivered')
        .get();

    Map<String, int> driverDeliveries = {};

    for (var doc in deliveriesSnapshot.docs) {
      final driverId = doc.data()['driverId'] as String?;
      if (driverId != null) {
        driverDeliveries[driverId] = (driverDeliveries[driverId] ?? 0) + 1;
      }
    }

    var sortedDrivers = driverDeliveries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<Map<String, dynamic>> topDriversList = [];

    for (var entry in sortedDrivers.take(10)) {
      try {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(entry.key)
            .get();
        
        if (driverDoc.exists) {
          topDriversList.add({
            'id': entry.key,
            'name': driverDoc.data()?['displayName'] ?? driverDoc.data()?['fullName'] ?? 'Unknown',
            'deliveries': entry.value,
          });
        }
      } catch (e) {
        debugPrint('Error loading driver ${entry.key}: $e');
      }
    }

    setState(() {
      _topDrivers = topDriversList;
    });
  }

  Future<void> _loadPerformanceMetrics() async {
    // Calculate various performance metrics
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    final dateRange = _getDateRange();
    if (dateRange == null) return;

    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .where('scheduledDate', 
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .get();

    // Calculate metrics by day of week
    Map<String, int> byDayOfWeek = {
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };

    for (var doc in deliveriesSnapshot.docs) {
      final scheduledDate = (doc.data()['scheduledDate'] as Timestamp?)?.toDate();
      if (scheduledDate != null) {
        final dayName = DateFormat('E').format(scheduledDate);
        byDayOfWeek[dayName] = (byDayOfWeek[dayName] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> metrics = [];
    byDayOfWeek.forEach((day, count) {
      metrics.add({'day': day, 'count': count});
    });

    setState(() {
      _performanceMetrics = metrics;
    });
  }

  Future<void> _loadLocationData() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    List<Map<String, dynamic>> locations = [];

    try {
      // Load POD locations from pods collection (uses 'location' field)
      final podsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .get();

      debugPrint('📍 Loading ${podsSnapshot.docs.length} PODs for map');
      
      int podLocationsLoaded = 0;
      for (var doc in podsSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        
        if (location != null && location['latitude'] != null && location['longitude'] != null) {
          // Get driver vehicle info
          String vehicleInfo = '';
          final driverId = data['driverId'] as String?;
          if (driverId != null && driverId.isNotEmpty) {
            try {
              final driverDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(driverId)
                  .get();
              if (driverDoc.exists) {
                vehicleInfo = driverDoc.data()?['vehicleInfo'] ?? '';
              }
            } catch (e) {
              debugPrint('Could not fetch driver vehicle info: $e');
            }
          }
          
          locations.add({
            'latitude': (location['latitude'] as num).toDouble(),
            'longitude': (location['longitude'] as num).toDouble(),
            'type': 'pod',
            'id': doc.id,
            'customerName': data['customerName'] ?? 'Unknown',
            'invoiceNumber': data['invoiceNumber'] ?? 'N/A',
            'status': data['status'] ?? 'pending',
            'deliveryId': data['deliveryId'] ?? '',
            'vehicleInfo': vehicleInfo,
            'customerId': data['customerId'] ?? '',
          });
          podLocationsLoaded++;
        }
      }
      debugPrint('📍 Loaded $podLocationsLoaded POD locations');

      // Load Claim locations (uses gpsLocation field)
      final claimsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .get();

      debugPrint('📍 Loading ${claimsSnapshot.docs.length} claims for map');
      int claimLocationsLoaded = 0;

      for (var doc in claimsSnapshot.docs) {
        final gpsLocation = doc.data()['gpsLocation'] as Map<String, dynamic>?;
        if (gpsLocation != null && gpsLocation['latitude'] != null && gpsLocation['longitude'] != null) {
          // Try to get POD info if podId exists
          String podInfo = '';
          final podId = doc.data()['podId'] as String?;
          if (podId != null && podId.isNotEmpty) {
            try {
              final podDoc = await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(companyId)
                  .collection('pods')
                  .doc(podId)
                  .get();
              if (podDoc.exists) {
                podInfo = podDoc.data()?['invoiceNumber'] ?? 'POD: $podId';
              }
            } catch (e) {
              debugPrint('Could not fetch POD $podId: $e');
            }
          }

          // Get driver vehicle info
          String vehicleInfo = '';
          final driverId = doc.data()['driverId'] as String?;
          if (driverId != null && driverId.isNotEmpty) {
            try {
              final driverDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(driverId)
                  .get();
              if (driverDoc.exists) {
                vehicleInfo = driverDoc.data()?['vehicleInfo'] ?? '';
              }
            } catch (e) {
              debugPrint('Could not fetch driver vehicle info: $e');
            }
          }
          
          // Get customer name, fetch if unknown
          String customerName = doc.data()['customerName'] ?? 'Unknown';
          final customerId = doc.data()['customerId'] as String?;
          if (customerName == 'Unknown' && customerId != null && customerId.isNotEmpty) {
            try {
              final customerDoc = await FirebaseFirestore.instance
                  .collection('companies')
                  .doc(companyId)
                  .collection('customers')
                  .doc(customerId)
                  .get();
              if (customerDoc.exists) {
                customerName = customerDoc.data()?['name'] ?? customerDoc.data()?['customerName'] ?? 'Unknown';
              }
            } catch (e) {
              debugPrint('Error fetching customer name for location: $e');
            }
          }
          
          locations.add({
            'latitude': (gpsLocation['latitude'] as num).toDouble(),
            'longitude': (gpsLocation['longitude'] as num).toDouble(),
            'type': 'claim',
            'id': doc.id,
            'title': doc.data()['title'] ?? 'Claim',
            'customerName': customerName,
            'customerAccountNumber': doc.data()['customerAccountNumber'] ?? 'N/A',
            'customerId': customerId ?? '',
            'driverName': doc.data()['driverName'] ?? 'Unknown',
            'invoiceNumber': doc.data()['invoiceNumber'] ?? 'N/A',
            'podId': podId,
            'podInfo': podInfo,
            'claimAmount': doc.data()['claimAmount'] ?? 0.0,
            'vehicleInfo': vehicleInfo,
          });
          claimLocationsLoaded++;
        }
      }
      debugPrint('📍 Loaded $claimLocationsLoaded claim locations');

      setState(() {
        _locationData = locations;
      });
      debugPrint('✅ Loaded ${locations.length} locations for map');
      for (var loc in locations) {
        debugPrint('  - ${loc['type']}: ${loc['id']} @ (${loc['latitude']}, ${loc['longitude']})');
      }
    } catch (e) {
      debugPrint('❌ Error loading location data: $e');
    }
  }

  Future<void> _loadDeliveriesPerTruck() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    Query query = FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId);

    // Apply date filter
    final dateRange = _getDateRange();
    if (dateRange != null) {
      query = query.where('scheduledDate', 
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
          .where('scheduledDate', 
          isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!));
    }

    final deliveriesSnapshot = await query.get();

    Map<String, int> truckDeliveries = {};

    for (var doc in deliveriesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      
      // Get vehicle from vehicleUsed field (stores vehicle registration)
      final vehicleUsed = data['vehicleUsed'] as String?;
      final vehicleInfo = vehicleUsed?.isNotEmpty == true ? vehicleUsed! : 'Unassigned';
      
      truckDeliveries[vehicleInfo] = (truckDeliveries[vehicleInfo] ?? 0) + 1;
    }

    debugPrint('✅ Loaded ${deliveriesSnapshot.docs.length} deliveries');
    debugPrint('   Vehicles: ${truckDeliveries.length}');
    for (var entry in truckDeliveries.entries) {
      debugPrint('   ${entry.key}: ${entry.value}');
    }

    setState(() {
      _deliveriesPerTruck = truckDeliveries;
    });
  }

  Future<void> _loadClaimsData() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('claims');

      final claimsSnapshot = await query.get();

      int totalClaims = claimsSnapshot.docs.length;
      debugPrint('📊 CLAIMS DEBUG: Found $totalClaims total claims');
      
      Map<String, Map<String, dynamic>> customerMap = {}; // customerName -> {name, number, count}
      Map<String, int> claimTypeCount = {}; // claimType -> count
      Set<String> claimTypes = {};
      List<Map<String, dynamic>> topClaims = []; // Individual claims with details

      // Single pass: process all claims
      for (var doc in claimsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          debugPrint('📊 CLAIMS DEBUG: Skipping null doc');
          continue;
        }
        
        // Log the actual data for first few claims
        if (customerMap.length < 3) {
          debugPrint('📊 CLAIMS DEBUG: Claim fields: ${data.keys.toList()}');
          debugPrint('   - customerName: ${data['customerName']}');
          debugPrint('   - type: ${data['type']}');
        }
        
        // Parse createdAt for filtering and sorting
        DateTime? createdAtDate;
        final createdAtValue = data['createdAt'];
        
        if (createdAtValue is Timestamp) {
          createdAtDate = createdAtValue.toDate();
        } else if (createdAtValue is String) {
          try {
            createdAtDate = DateTime.parse(createdAtValue);
          } catch (e) {
            debugPrint('Could not parse createdAt: $createdAtValue');
          }
        }
        
        // Get customer info - use what's in the claim
        String? customerNumber = data['customerNumber'] as String?;
        String customerName = data['customerName'] as String? ?? 'Unknown';
        
        debugPrint('📊 CLAIMS DEBUG: Processing claim with customerName="$customerName"');
        
        customerNumber = customerNumber ?? '';
        
        // Use customerNumber as key for grouping (or customerName if no number)
        final groupKey = customerNumber.isNotEmpty ? customerNumber : customerName;
        
        if (customerMap.containsKey(groupKey)) {
          // Increment count
          customerMap[groupKey]!['count'] = (customerMap[groupKey]!['count'] ?? 0) + 1;
          customerMap[groupKey]!['claims'] = (customerMap[groupKey]!['claims'] ?? 0) + 1;
          debugPrint('   Incremented count for "$groupKey" to ${customerMap[groupKey]!['count']}');
        } else {
          // New customer entry - use 'customer' key for display
          customerMap[groupKey] = {
            'customer': customerName,
            'customerNumber': customerNumber,
            'customerName': customerName,
            'count': 1,
            'claims': 1,
          };
          debugPrint('   Created new entry for "$groupKey" with count 1');
        }
        
        // Count different claim types
        final claimType = data['type'] as String? ?? 'Other';
        claimTypes.add(claimType);
        claimTypeCount[claimType] = (claimTypeCount[claimType] ?? 0) + 1;
        
        // Collect individual claim details for top claims
        topClaims.add({
          'id': doc.id,
          'customerName': customerName,
          'customerNumber': customerNumber,
          'type': claimType,
          'description': data['description'] as String? ?? '',
          'createdAt': createdAtDate,
          'status': data['status'] as String? ?? 'Unknown',
          'amount': data['amount'] as double? ?? 0.0,
        });
      }

      // Convert to list and sort by claims count descending
      final claimsList = customerMap.values.toList()
        ..sort((a, b) => (b['claims'] as int).compareTo(a['claims'] as int));

      // Sort top claims by date (most recent first) and take top 10
      topClaims.sort((a, b) {
        final dateA = a['createdAt'] as DateTime?;
        final dateB = b['createdAt'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // Most recent first
      });
      final top10Claims = topClaims.take(10).toList();

      debugPrint('✅ Loaded $totalClaims claims total');
      debugPrint('   Customers: ${customerMap.length}, Types: ${claimTypes.length}');
      for (var entry in customerMap.entries) {
        debugPrint('   FINAL: ${entry.value['customer']}: ${entry.value['claims']}');
      }

      setState(() {
        _totalClaims = totalClaims;
        _claimsPerCustomer = claimsList;
        _claimTypes = claimTypes;
        _claimTypeCount = claimTypeCount;
        _topClaims = top10Claims;
      });
    } catch (e) {
      debugPrint('❌ Error loading claims data: $e');
    }
  }

  Future<void> _loadTopCustomerDeliveries() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId);

      // Apply date filter
      final dateRange = _getDateRange();
      if (dateRange != null) {
        query = query.where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
            .where('scheduledDate',
            isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!.add(const Duration(days: 1))));
      }

      final deliveriesSnapshot = await query.get();

      Map<String, Map<String, dynamic>> customerMap = {};

      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // Get customer info
        final customerName = data['customerName'] as String? ?? 'Unknown';
        final customerNumber = data['customerNumber'] as String? ?? '';
        
        // Use customerNumber as key if available, otherwise use name
        final groupKey = customerNumber.isNotEmpty ? customerNumber : customerName;

        if (customerMap.containsKey(groupKey)) {
          customerMap[groupKey]!['count'] = (customerMap[groupKey]!['count'] ?? 0) + 1;
        } else {
          customerMap[groupKey] = {
            'customerNumber': customerNumber,
            'customerName': customerName,
            'count': 1,
          };
        }
      }

      // Convert to list and sort by count descending
      final customersList = customerMap.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      debugPrint('✅ Loaded ${customersList.length} unique customers (total: ${deliveriesSnapshot.docs.length} deliveries)');

      setState(() {
        _topCustomerDeliveries = customersList;
      });
    } catch (e) {
      debugPrint('❌ Error loading top customer deliveries: $e');
    }
  }

  Map<String, DateTime>? _getDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_selectedPeriod == 'custom' && _startDate != null && _endDate != null) {
      return {'start': _startDate!, 'end': _endDate!};
    }

    switch (_selectedPeriod) {
      case 'week':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        start = now.subtract(const Duration(days: 30));
        break;
      case 'quarter':
        start = now.subtract(const Duration(days: 90));
        break;
      case 'year':
        start = now.subtract(const Duration(days: 365));
        break;
      default:
        start = now.subtract(const Duration(days: 30));
    }

    return {'start': start, 'end': end};
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Analytics & Reports'),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Desktop',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            // Toggle filters
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
              onPressed: () {
                setState(() => _showFilters = !_showFilters);
              },
              tooltip: 'Toggle filters (Ctrl+F)',
            ),
            // Export
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportDialog,
              tooltip: 'Export (Ctrl+E)',
            ),
            // Refresh
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAnalytics,
              tooltip: 'Refresh (F5)',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  // Filter sidebar
                  if (_showFilters) ...[
                    _buildFilterSidebar(),
                    VerticalDivider(width: 1, color: Colors.grey[300]),
                  ],
                  // Main content
                  Expanded(
                    child: Column(
                      children: [
                        // Metrics header with collapse/expand button
                        Container(
                          color: Colors.grey[50],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Metrics',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              IconButton(
                                icon: Icon(
                                  _showMetrics ? Icons.expand_less : Icons.expand_more,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showMetrics = !_showMetrics;
                                  });
                                },
                                tooltip: _showMetrics ? 'Collapse metrics' : 'Expand metrics',
                              ),
                            ],
                          ),
                        ),
                        // Animated metrics section
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _showMetrics
                              ? Column(
                                  children: [
                                    // Statistics cards
                                    _buildStatisticsBar(),
                                    Divider(height: 1, color: Colors.grey[300]),
                                    // Fleet & Claims metrics
                                    _buildFleetAndClaimsBar(),
                                    Divider(height: 1, color: Colors.grey[300]),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        // Charts grid (expands when metrics collapsed)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Multi-chart grid (2x2)
                                _buildChartsGrid(),
                                const SizedBox(height: 24),
                                // Delivery Locations Map
                                _buildLocationsMap(),
                                const SizedBox(height: 24),
                                // Top drivers table
                                _buildTopDriversTable(),
                                const SizedBox(height: 24),
                                // Fleet & Claims detail tables
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDeliveriesPerTruckTable(),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: _buildTopClaimsTable(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Top Claim Types table
                                _buildTopClaimTypesTable(),
                                const SizedBox(height: 24),
                                // Top Customer Deliveries table
                                _buildTopCustomerDeliveriesTable(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chart details side panel
                  if (_selectedChart != 'none') ...[
                    VerticalDivider(width: 1, color: Colors.grey[300]),
                    _buildChartDetailsPanel(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildFilterSidebar() {
    return Container(
      width: 280,
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Time Period
            const Text(
              'Time Period',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildPeriodButton('Week', 'week'),
            _buildPeriodButton('Month', 'month'),
            _buildPeriodButton('Quarter', 'quarter'),
            _buildPeriodButton('Year', 'year'),
            _buildPeriodButton('Custom', 'custom'),
            if (_selectedPeriod == 'custom') ...[
              const SizedBox(height: 16),
              _buildCustomDateRangePicker(),
            ],
            const SizedBox(height: 24),
            // Chart Focus
            const Text(
              'Chart Focus',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildChartFocusButton('Delivery Trend', 'trend', Icons.show_chart, '1'),
            _buildChartFocusButton('Status Breakdown', 'status', Icons.pie_chart, '2'),
            _buildChartFocusButton('Top Drivers', 'drivers', Icons.emoji_events, '3'),
            _buildChartFocusButton('Performance', 'performance', Icons.bar_chart, '4'),
            _buildChartFocusButton('Deliveries', 'deliveries', Icons.local_shipping, '5'),
            _buildChartFocusButton('Claims', 'claims', Icons.report, '6'),
            const SizedBox(height: 24),
            // Quick Stats
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
            if (value != 'custom') {
              _startDate = null;
              _endDate = null;
            }
          });
          _loadAnalytics();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateRangePicker() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: _startDate != null && _endDate != null
                  ? DateTimeRange(start: _startDate!, end: _endDate!)
                  : null,
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
              _loadAnalytics();
            }
          },
          icon: const Icon(Icons.date_range, size: 18),
          label: Text(
            _startDate != null && _endDate != null
                ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, y').format(_endDate!)}'
                : 'Select Date Range',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (_startDate != null && _endDate != null)
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              _loadAnalytics();
            },
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildChartFocusButton(String label, String value, IconData icon, String shortcut) {
    final isSelected = _selectedChart == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedChart = value);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.blue[700] : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.blue[900] : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  shortcut,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue[900] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickStatRow('Success Rate', '${_completionRate.toStringAsFixed(1)}%'),
          _buildQuickStatRow('Avg Delivery Time', '${_avgDeliveryTime.toStringAsFixed(1)}h'),
          _buildQuickStatRow('Active Drivers', '$_activeDrivers/$_totalDrivers'),
          _buildQuickStatRow('Failed Deliveries', '$_failedDeliveries'),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Delivery Performance (Invoice → Completion)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickStatRow('Avg Days to Deliver', '${_avgDaysToDeliver.toStringAsFixed(1)} days'),
          _buildQuickStatRow('On-Time Deliveries', '$_onTimeDeliveries'),
          _buildQuickStatRow('Late Deliveries', '$_lateDeliveries'),
        ],
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Deliveries',
              _totalDeliveries.toString(),
              Icons.local_shipping,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Completed',
              _completedDeliveries.toString(),
              Icons.check_circle,
              AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'In Transit',
              _activeDeliveries.toString(),
              Icons.local_shipping,
              AppTheme.infoColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              _pendingDeliveries.toString(),
              Icons.schedule,
              AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Completion Rate',
              '${_completionRate.toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetAndClaimsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Claims',
              _totalClaims.toString(),
              Icons.warning_rounded,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Claim Types',
              _claimTypes.length.toString(),
              Icons.category,
              Colors.purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Customers w/ Claims',
              _claimsPerCustomer.length.toString(),
              Icons.person_outline,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Trucks in Use',
              _deliveriesPerTruck.length.toString(),
              Icons.local_shipping,
              Colors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Avg Deliveries/Truck',
              _deliveriesPerTruck.isEmpty 
                  ? '0'
                  : (_deliveriesPerTruck.values.reduce((a, b) => a + b) / _deliveriesPerTruck.length).toStringAsFixed(1),
              Icons.trending_up,
              Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // 2x2 grid of charts
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildChartCard(
                    'Delivery Trend',
                    _buildDeliveryTrendChart(),
                    height: 300,
                    selected: _selectedChart == 'trend',
                  ),
                  const SizedBox(height: 16),
                  _buildChartCard(
                    'Status Distribution',
                    _buildStatusPieChart(),
                    height: 300,
                    selected: _selectedChart == 'status',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildChartCard(
                    'Top Drivers Performance',
                    _buildTopDriversChart(),
                    height: 300,
                    selected: _selectedChart == 'drivers',
                  ),
                  const SizedBox(height: 16),
                  _buildChartCard(
                    'Weekly Performance',
                    _buildWeeklyPerformanceChart(),
                    height: 300,
                    selected: _selectedChart == 'performance',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationsMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Locations & Coverage Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Interactive map with heatmap density visualization, clustering, and coverage statistics',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quick stats row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.withValues(alpha: 0.05),
                        Colors.blue.withValues(alpha: 0.02),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'Locations loaded: ${_locationData.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          '${_locationData.where((l) => l['type'] == 'pod').length} PODs',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.green.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          '${_locationData.where((l) => l['type'] == 'claim').length} Claims',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.orange.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Map with enhanced controls
                SizedBox(
                  height: 450,
                  child: AnalyticsMapWidget(
                    locations: _locationData,
                    height: 450,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, {double height = 250, bool selected = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.blue[300]! : Colors.grey[200]!,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: selected ? 0.08 : 0.04),
            blurRadius: selected ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.blue[700] : Colors.black87,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'FOCUSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: height,
            child: chart,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTrendChart() {
    if (_dailyDeliveries.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final spots = <FlSpot>[];
    final dates = _dailyDeliveries.keys.toList();
    
    for (int i = 0; i < dates.length && i < 10; i++) {
      final count = _dailyDeliveries[dates[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < dates.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dates[index],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: 0,
        maxY: spots.isEmpty ? 10 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue[100]!.withValues(alpha: 0.3),
                  Colors.blue[200]!.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart() {
    if (_deliveriesByStatus.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final sections = <PieChartSectionData>[];
    final statusColors = {
      'delivered': AppTheme.successColor,
      'inTransit': AppTheme.infoColor,
      'pending': AppTheme.warningColor,
      'failed': AppTheme.errorColor,
    };

    _deliveriesByStatus.forEach((status, count) {
      final percentage = (_totalDeliveries > 0) 
          ? (count / _totalDeliveries * 100).toStringAsFixed(1) 
          : '0.0';
      
      sections.add(
        PieChartSectionData(
          color: statusColors[status] ?? Colors.grey,
          value: count.toDouble(),
          title: '$percentage%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _deliveriesByStatus.entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColors[entry.key] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_getStatusLabel(entry.key)}: ${entry.value}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTopDriversChart() {
    if (_topDrivers.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final topFive = _topDrivers.take(5).toList();
    final maxValue = topFive.isEmpty ? 10.0 : topFive.first['deliveries'].toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < topFive.length) {
                  final name = topFive[index]['name'] as String;
                  final firstName = name.split(' ').first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      firstName.length > 8 ? '${firstName.substring(0, 8)}...' : firstName,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        barGroups: List.generate(topFive.length, (index) {
          final driver = topFive[index];
          final deliveries = driver['deliveries'] as int;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: deliveries.toDouble(),
                gradient: LinearGradient(
                  colors: index == 0 
                      ? [Colors.amber[400]!, Colors.amber[600]!]
                      : [Colors.blue[400]!, Colors.blue[600]!],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWeeklyPerformanceChart() {
    if (_performanceMetrics.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final maxValue = _performanceMetrics
        .map((m) => m['count'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _performanceMetrics.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _performanceMetrics[index]['day'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!),
        ),
        barGroups: List.generate(_performanceMetrics.length, (index) {
          final metric = _performanceMetrics[index];
          final count = metric['count'] as int;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTopDriversTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Top Performers Leaderboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // Export leaderboard
                  _exportTopDrivers();
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(60),
              1: FlexColumnWidth(3),
              2: FixedColumnWidth(120),
              3: FixedColumnWidth(100),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _buildTableHeaderCell('Rank'),
                  _buildTableHeaderCell('Driver Name'),
                  _buildTableHeaderCell('Deliveries'),
                  _buildTableHeaderCell('Badge'),
                ],
              ),
              ..._topDrivers.take(10).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final driver = entry.value;
                return _buildDriverRow(
                  index + 1,
                  driver['name'],
                  driver['deliveries'],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  String _formatClaimType(String type) {
    switch (type.toLowerCase()) {
      case 'damaged':
      case 'damagedgoods':
        return 'Damaged Goods';
      case 'shortage':
      case 'shortdelivered':
        return 'Short Delivered';
      case 'shortweight':
      case 'short':
        return 'Short Weight';
      case 'missing':
      case 'missingitems':
        return 'Missing Items';
      case 'wrongitems':
      case 'wrongitem':
      case 'wrong':
        return 'Wrong Items';
      case 'returns':
      case 'customerreturns':
        return 'Customer Returns';
      case 'priceerror':
      case 'price':
        return 'Price Error';
      case 'latedelivery':
      case 'late':
        return 'Late Delivery';
      case 'didnotdeliver':
      case 'notdelivered':
        return 'Did Not Deliver';
      case 'qualityissue':
      case 'quality':
        return 'Quality Issue';
      case 'temperatureissue':
      case 'temperature':
        return 'Temperature Issue';
      case 'packagingissue':
      case 'packaging':
        return 'Packaging Issue';
      case 'expiryissue':
      case 'expiry':
        return 'Expiry Issue';
      case 'serviceissue':
      case 'service':
        return 'Service Issue';
      case 'other':
        return 'Other';
      default:
        // Try to format unknown types by adding spaces before capital letters
        if (type.contains(RegExp(r'[A-Z]'))) {
          return type.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').trim();
        }
        return type; // Return as-is if unknown
    }
  }

  TableRow _buildDriverRow(int rank, String name, int deliveries) {
    final isTopThree = rank <= 3;
    final medalColor = rank == 1 
        ? Colors.amber 
        : rank == 2 
            ? Colors.grey[400]!
            : Colors.brown[300]!;

    return TableRow(
      decoration: BoxDecoration(
        color: rank.isEven ? Colors.grey[50] : Colors.white,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isTopThree)
                Icon(Icons.emoji_events, color: medalColor, size: 18)
              else
                Text(
                  '$rank',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            name,
            style: TextStyle(
              fontWeight: isTopThree ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            deliveries.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getBadgeColor(rank),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getBadgeText(rank),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getBadgeColor(int rank) {
    if (rank == 1) return Colors.amber[700]!;
    if (rank <= 3) return Colors.blue[700]!;
    if (rank <= 5) return Colors.green[700]!;
    return Colors.grey[600]!;
  }

  String _getBadgeText(int rank) {
    if (rank == 1) return '🏆 Champion';
    if (rank <= 3) return '⭐ Top 3';
    if (rank <= 5) return '✓ Top 5';
    return '• Active';
  }

  /* Unused keyboard shortcuts bar - commented out to avoid warnings
  Widget _buildKeyboardShortcutsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.keyboard, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          _buildShortcutChip('1-4', 'Switch Charts'),
          _buildShortcutChip('Ctrl+E', 'Export'),
          _buildShortcutChip('Ctrl+F', 'Filters'),
          _buildShortcutChip('F5', 'Refresh'),
        ],
      ),
    );
  }
  */

  /* Also commenting out _buildShortcutChip since it's only used by the commented method
  Widget _buildShortcutChip(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildChartDetailsPanel() {
    return Container(
      width: 320,
      color: Colors.grey[50],
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Icon(
                  _getChartIcon(_selectedChart),
                  size: 20,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getChartTitle(_selectedChart),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Export and close buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_showChartAsTable ? Icons.show_chart : Icons.table_chart, size: 20),
                      onPressed: () {
                        setState(() => _showChartAsTable = !_showChartAsTable);
                      },
                      tooltip: _showChartAsTable ? 'Show chart' : 'Show table',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: _showChartExportDialog,
                      tooltip: 'Export chart',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        setState(() => _selectedChart = 'none');
                      },
                      tooltip: 'Close details',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildChartDetailsContent(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getChartIcon(String chartType) {
    switch (chartType) {
      case 'trend':
        return Icons.show_chart;
      case 'status':
        return Icons.pie_chart;
      case 'drivers':
        return Icons.emoji_events;
      case 'performance':
        return Icons.bar_chart;
      case 'deliveries':
        return Icons.local_shipping;
      case 'claims':
        return Icons.report;
      default:
        return Icons.analytics;
    }
  }

  String _getChartTitle(String chartType) {
    switch (chartType) {
      case 'trend':
        return 'Delivery Trend Details';
      case 'status':
        return 'Status Distribution Details';
      case 'drivers':
        return 'Top Drivers Details';
      case 'performance':
        return 'Performance Details';
      case 'deliveries':
        return 'Deliveries Details';
      case 'claims':
        return 'Claims Details';
      default:
        return 'Chart Details';
    }
  }

  Widget _buildChartDetailsContent() {
    if (_showChartAsTable) {
      return _buildChartDataTable();
    }

    switch (_selectedChart) {
      case 'trend':
        return _buildTrendChartDetails();
      case 'status':
        return _buildStatusChartDetails();
      case 'drivers':
        return _buildDriversChartDetails();
      case 'performance':
        return _buildPerformanceChartDetails();
      case 'deliveries':
        return _buildDeliveriesChartDetails();
      case 'claims':
        return _buildClaimsChartDetails();
      default:
        return const Center(
          child: Text('Select a chart to view details'),
        );
    }
  }

  Widget _buildChartDataTable() {
    switch (_selectedChart) {
      case 'trend':
        return _buildTrendDataTable();
      case 'status':
        return _buildStatusDataTable();
      case 'drivers':
        return _buildDriversDataTable();
      case 'performance':
        return _buildPerformanceDataTable();
      case 'deliveries':
        return _buildDeliveriesDataTable();
      case 'claims':
        return _buildClaimsDataTable();
      default:
        return const Center(
          child: Text('No data available'),
        );
    }
  }

  Widget _buildTrendDataTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Delivery Trend',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Deliveries', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ..._dailyDeliveries.entries.map((entry) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(entry.key),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(entry.value.toString()),
                ),
              ],
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusDataTable() {
    final total = _totalDeliveries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Distribution',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Count', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Pending'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_pendingDeliveries.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${total > 0 ? (_pendingDeliveries / total * 100).toStringAsFixed(1) : '0'}%'),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('In Transit'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_activeDeliveries.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${total > 0 ? (_activeDeliveries / total * 100).toStringAsFixed(1) : '0'}%'),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Delivered'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_completedDeliveries.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${total > 0 ? (_completedDeliveries / total * 100).toStringAsFixed(1) : '0'}%'),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Failed'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_failedDeliveries.toString()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${total > 0 ? (_failedDeliveries / total * 100).toStringAsFixed(1) : '0'}%'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriversDataTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Drivers by Deliveries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Deliveries', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ..._topDrivers.map((driver) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(driver['name'] as String? ?? 'Unknown'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text((driver['deliveries'] as int? ?? 0).toString()),
                ),
              ],
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceDataTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Metrics',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Metric', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Value', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Average Delivery Time'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${_avgDeliveryTime.toStringAsFixed(1)} hours'),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('On-Time Deliveries'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_onTimeDeliveries.toString()),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Late Deliveries'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_lateDeliveries.toString()),
                ),
              ],
            ),
            TableRow(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('On-Time Rate'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${_onTimeDeliveries > 0 ? ((_onTimeDeliveries / (_onTimeDeliveries + _lateDeliveries)) * 100).toStringAsFixed(1) : '0'}%'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveriesDataTable() {
    final trucks = _deliveriesPerTruck.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deliveries Overview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Vehicle', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(8), child: Text('Deliveries', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ...trucks.map((e) => TableRow(children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(e.key)),
              Padding(padding: const EdgeInsets.all(8), child: Text(e.value.toString())),
            ])),
          ],
        ),
      ],
    );
  }

  Widget _buildClaimsDataTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Claims Overview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[100]),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(8), child: Text('Claims', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ..._claimsPerCustomer.map((c) => TableRow(children: [
              Padding(padding: const EdgeInsets.all(8), child: Text(c['customer'] as String? ?? 'Unknown')),
              Padding(padding: const EdgeInsets.all(8), child: Text((c['claims'] as int? ?? 0).toString())),
            ])),
          ],
        ),
      ],
    );
  }

  Future<void> _showExportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Analytics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export to CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.pop(context);
                _exportToCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export to PDF'),
              subtitle: const Text('Professional report'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChartExportDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export ${_getChartTitle(_selectedChart)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Export as PNG'),
              subtitle: const Text('High-quality image'),
              onTap: () {
                Navigator.pop(context);
                _exportChartAsImage('png');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export Chart Data'),
              subtitle: const Text('CSV format'),
              onTap: () {
                Navigator.pop(context);
                _exportChartData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Chart'),
              subtitle: const Text('Copy link to clipboard'),
              onTap: () {
                Navigator.pop(context);
                _shareChart();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing analytics export...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Create summary data
      final summaryData = {
        'totalDeliveries': _totalDeliveries,
        'completedDeliveries': _completedDeliveries,
        'activeDeliveries': _activeDeliveries,
        'pendingDeliveries': _pendingDeliveries,
        'failedDeliveries': _failedDeliveries,
        'totalDrivers': _totalDrivers,
        'activeDrivers': _activeDrivers,
        'completionRate': _completionRate,
        'avgDeliveryTime': _avgDeliveryTime,
        'avgDaysToDeliver': _avgDaysToDeliver,
        'onTimeDeliveries': _onTimeDeliveries,
        'lateDeliveries': _lateDeliveries,
      };

      // Get date range
      final now = DateTime.now();
      DateTime start, end;
      switch (_selectedPeriod) {
        case 'week':
          start = now.subtract(const Duration(days: 7));
          end = now;
          break;
        case 'quarter':
          start = now.subtract(const Duration(days: 90));
          end = now;
          break;
        case 'year':
          start = now.subtract(const Duration(days: 365));
          end = now;
          break;
        case 'custom':
          if (_startDate != null && _endDate != null) {
            start = _startDate!;
            end = _endDate!;
          } else {
            start = now.subtract(const Duration(days: 30));
            end = now;
          }
          break;
        default: // month
          start = now.subtract(const Duration(days: 30));
          end = now;
      }

      // Export using CSV service
      final filePath = await CSVExportService.exportAnalyticsSummary(
        summary: summaryData,
        startDate: start,
        endDate: end,
      );

      if (mounted) {
        final message = filePath != null
            ? 'Analytics exported to:\n$filePath'
            : 'Analytics exported successfully!';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting analytics: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating PDF report...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get company name and logo
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final companyId = authProvider.companyId;
      String companyName = 'PODSafe Analytics Report';
      String? companyLogoUrl;

      try {
        final companyDoc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        if (companyDoc.exists) {
          companyName = companyDoc.data()?['name'] ?? companyName;
          companyLogoUrl = companyDoc.data()?['logoUrl'] as String?;
        }
      } catch (e) {
        debugPrint('Could not fetch company info: $e');
      }

      // Get date range
      final now = DateTime.now();
      DateTime start, end;
      switch (_selectedPeriod) {
        case 'week':
          start = now.subtract(const Duration(days: 7));
          end = now;
          break;
        case 'quarter':
          start = now.subtract(const Duration(days: 90));
          end = now;
          break;
        case 'year':
          start = now.subtract(const Duration(days: 365));
          end = now;
          break;
        case 'custom':
          if (_startDate != null && _endDate != null) {
            start = _startDate!;
            end = _endDate!;
          } else {
            start = now.subtract(const Duration(days: 30));
            end = now;
          }
          break;
        default: // month
          start = now.subtract(const Duration(days: 30));
          end = now;
      }

      // Generate PDF
      await PDFExportService.generateAnalyticsReport(
        companyName: companyName,
        startDate: start,
        endDate: end,
        totalDeliveries: _totalDeliveries,
        completedDeliveries: _completedDeliveries,
        activeDeliveries: _activeDeliveries,
        pendingDeliveries: _pendingDeliveries,
        failedDeliveries: _failedDeliveries,
        totalDrivers: _totalDrivers,
        activeDrivers: _activeDrivers,
        completionRate: _completionRate,
        avgDeliveryTime: _avgDeliveryTime,
        avgDaysToDeliver: _avgDaysToDeliver,
        onTimeDeliveries: _onTimeDeliveries,
        lateDeliveries: _lateDeliveries,
        deliveriesByStatus: _deliveriesByStatus,
        topDrivers: _topDrivers,
        deliveriesPerTruck: _deliveriesPerTruck,
        totalClaims: _totalClaims,
        claimsPerCustomer: _claimsPerCustomer,
        claimTypes: _claimTypes,
        claimTypeCount: _claimTypeCount,
        topCustomerDeliveries: _topCustomerDeliveries,
        companyLogoUrl: companyLogoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportTopDrivers() async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exporting top drivers...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      if (_topDrivers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No driver data to export'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      // Export using CSV service  
      final filePath = await CSVExportService.exportDrivers(
        drivers: _topDrivers,
      );

      if (mounted) {
        final message = filePath != null
            ? 'Top drivers exported to:\n$filePath'
            : 'Top drivers exported successfully!';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting drivers: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _exportChartAsImage(String format) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chart export as $format - Feature coming soon!'),
          backgroundColor: AppTheme.infoColor,
        ),
      );
    }
  }

  Future<void> _exportChartData() async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing chart data export...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Generate data display based on selected chart
      String dataContent = '';
      String title = '';

      switch (_selectedChart) {
        case 'trend':
          title = 'Delivery Trend Data';
          dataContent = 'Date\t\tDeliveries\n';
          dataContent += '------------------------\n';
          _dailyDeliveries.forEach((date, count) {
            dataContent += '$date\t$count\n';
          });
          break;
        case 'status':
          title = 'Status Distribution Data';
          final total = _totalDeliveries;
          dataContent = 'Status\t\tCount\tPercentage\n';
          dataContent += '--------------------------------\n';
          dataContent += 'Pending\t\t$_pendingDeliveries\t${total > 0 ? (_pendingDeliveries / total * 100).toStringAsFixed(1) : '0'}%\n';
          dataContent += 'In Transit\t$_activeDeliveries\t${total > 0 ? (_activeDeliveries / total * 100).toStringAsFixed(1) : '0'}%\n';
          dataContent += 'Delivered\t$_completedDeliveries\t${total > 0 ? (_completedDeliveries / total * 100).toStringAsFixed(1) : '0'}%\n';
          dataContent += 'Failed\t\t$_failedDeliveries\t${total > 0 ? (_failedDeliveries / total * 100).toStringAsFixed(1) : '0'}%\n';
          break;
        case 'drivers':
          title = 'Top Drivers Data';
          dataContent = 'Driver\t\tDeliveries\n';
          dataContent += '------------------------\n';
          for (var driver in _topDrivers) {
            final name = driver['name'] as String? ?? 'Unknown';
            final deliveries = driver['deliveries'] as int? ?? 0;
            dataContent += '$name\t$deliveries\n';
          }
          break;
        case 'performance':
          title = 'Performance Metrics Data';
          dataContent = 'Metric\t\t\t\tValue\n';
          dataContent += '----------------------------------------\n';
          dataContent += 'Average Delivery Time\t${_avgDeliveryTime.toStringAsFixed(1)} hours\n';
          dataContent += 'On-Time Deliveries\t\t$_onTimeDeliveries\n';
          dataContent += 'Late Deliveries\t\t$_lateDeliveries\n';
          dataContent += 'On-Time Rate\t\t\t${_onTimeDeliveries > 0 ? ((_onTimeDeliveries / (_onTimeDeliveries + _lateDeliveries)) * 100).toStringAsFixed(1) : '0'}%\n';
          break;
          case 'deliveries':
            title = 'Deliveries Data';
            dataContent = 'Vehicle\tDeliveries\n';
            dataContent += '------------------------\n';
            _deliveriesPerTruck.forEach((vehicle, cnt) {
              dataContent += '$vehicle\t$cnt\n';
            });
            break;
          case 'claims':
            title = 'Claims Data';
            dataContent = 'Customer\tClaims\n';
            dataContent += '------------------------\n';
            for (var c in _claimsPerCustomer) {
              final name = c['customer'] as String? ?? 'Unknown';
              final claims = c['claims'] as int? ?? 0;
              dataContent += '$name\t$claims\n';
            }
            break;
        default:
          title = 'Chart Data';
          dataContent = 'No data available for selected chart';
      }

      // Show data in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: SelectableText(
                dataContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  // Copy to clipboard
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data copied to clipboard'),
                    ),
                  );
                },
                child: const Text('Copy'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting chart data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _shareChart() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chart sharing - Feature coming soon!'),
          backgroundColor: AppTheme.infoColor,
        ),
      );
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Delivered';
      case 'inTransit':
        return 'In Transit';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  Widget _buildDeliveriesPerTruckTable() {
    // Sort trucks by deliveries (descending)
    final sortedTrucks = _deliveriesPerTruck.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deliveries Per Truck',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedTrucks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No truck data available',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FixedColumnWidth(100),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                  ),
                  children: [
                    _buildTableHeaderCell('Vehicle'),
                    _buildTableHeaderCell('Deliveries'),
                  ],
                ),
                ...sortedTrucks.take(8).toList().map((entry) {
                  final vehicleName = entry.key.isEmpty ? 'Unassigned' : entry.key;
                  final deliveryCount = entry.value;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          vehicleName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deliveryCount.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopClaimsTable() {
    final claims = _topClaims;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Customer Claims',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (claims.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No claims data',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Claims: ${claims.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Total Claims: $_totalClaims',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5), // Customer - increased width
                    1: FlexColumnWidth(2),   // Reason
                    2: FixedColumnWidth(100), // Date
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                      ),
                      children: [
                        _buildTableHeaderCell('Customer'),
                        _buildTableHeaderCell('Claim Reason'),
                        _buildTableHeaderCell('Date'),
                      ],
                    ),
                    ...claims.map((claim) {
                      final customerName = claim['customerName'] as String? ?? 'Unknown';
                      final customerNumber = claim['customerNumber'] as String? ?? '';
                      final displayName = customerNumber.isNotEmpty 
                        ? '$customerName ($customerNumber)' 
                        : customerName;
                      final reason = claim['type'] as String? ?? 'Other';
                      final createdAt = claim['createdAt'] as DateTime?;
                      final dateStr = createdAt != null 
                        ? '${createdAt.month}/${createdAt.day}/${createdAt.year}' 
                        : 'Unknown';
                      
                      return TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _formatClaimType(reason),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopClaimTypesTable() {
    // Convert claim types to list and sort by count
    final sortedTypes = _claimTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Claim Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No claim type data',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FixedColumnWidth(80),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                  ),
                  children: [
                    _buildTableHeaderCell('Claim Type'),
                    _buildTableHeaderCell('Count'),
                  ],
                ),
                ...sortedTypes.take(8).toList().map((entry) {
                  final claimType = entry.key;
                  final count = entry.value;
                  
                  return TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _formatClaimType(claimType),
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopCustomerDeliveriesTable() {
    // _topCustomerDeliveries is already sorted by count
    final customers = _topCustomerDeliveries;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Customers by Deliveries',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (customers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No delivery data',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(2.5),
                2: FixedColumnWidth(100),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                  ),
                  children: [
                    _buildTableHeaderCell('Cust #'),
                    _buildTableHeaderCell('Customer Name'),
                    _buildTableHeaderCell('Deliveries'),
                  ],
                ),
                ...customers.take(8).toList().map((customer) {
                  final customerNumber = (customer['customerNumber'] as String?) ?? '';
                  final customerName = (customer['customerName'] as String?) ?? 'Unknown';
                  final deliveryCount = (customer['count'] as int?) ?? 0;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          customerNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deliveryCount.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTrendChartDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Trend Analysis',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Total Deliveries', _totalDeliveries.toString()),
        _buildDetailRow('Completed', _completedDeliveries.toString()),
        _buildDetailRow('In Transit', _activeDeliveries.toString()),
        _buildDetailRow('Pending', _pendingDeliveries.toString()),
        _buildDetailRow('Failed', _failedDeliveries.toString()),
        const SizedBox(height: 16),
        _buildDetailRow('Success Rate', '${_completionRate.toStringAsFixed(1)}%'),
        const SizedBox(height: 16),
        const Text(
          'Chart Controls',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '• Use time period filters to change the date range',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• Data updates automatically when filters change',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatusChartDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Distribution Breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildStatusDetailRow('Pending', _pendingDeliveries, Colors.orange),
        _buildStatusDetailRow('In Transit', _activeDeliveries, Colors.blue),
        _buildStatusDetailRow('Delivered', _completedDeliveries, Colors.green),
        _buildStatusDetailRow('Failed', _failedDeliveries, Colors.red),
        const SizedBox(height: 16),
        _buildDetailRow('Total Deliveries', _totalDeliveries.toString()),
        const SizedBox(height: 16),
        const Text(
          'Status Explanations',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '• Pending: Deliveries scheduled but not started',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• In Transit: Deliveries currently being transported',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• Delivered: Successfully completed deliveries',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• Failed: Deliveries that could not be completed',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDriversChartDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Drivers Performance',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Total Drivers', _totalDrivers.toString()),
        _buildDetailRow('Active Drivers', _activeDrivers.toString()),
        const SizedBox(height: 16),
        const Text(
          'Top Performers',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._topDrivers.take(5).map((driver) {
          final name = driver['name'] as String? ?? 'Unknown';
          final deliveries = driver['deliveries'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '$deliveries deliveries',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        const Text(
          'Performance Metrics',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '• Rankings based on completed deliveries',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• Data reflects current time period selection',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPerformanceChartDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Performance Metrics',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Avg Delivery Time', '${_avgDeliveryTime.toStringAsFixed(1)} hours'),
        _buildDetailRow('On-Time Deliveries', _onTimeDeliveries.toString()),
        _buildDetailRow('Late Deliveries', _lateDeliveries.toString()),
        const SizedBox(height: 16),
        _buildDetailRow('On-Time Rate', '${_onTimeDeliveries > 0 ? ((_onTimeDeliveries / (_onTimeDeliveries + _lateDeliveries)) * 100).toStringAsFixed(1) : '0.0'}%'),
        const SizedBox(height: 16),
        const Text(
          'Performance Insights',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '• Average delivery time from creation to completion',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• On-time deliveries completed within expected timeframe',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const Text(
          '• Late deliveries exceeded expected delivery time',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDeliveriesChartDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deliveries Overview',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Total Deliveries', _totalDeliveries.toString()),
        _buildDetailRow('Deliveries per Vehicle (top 5)', ''),
        const SizedBox(height: 8),
        ..._deliveriesPerTruck.entries.toList()
            .take(5)
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 12)),
                      Text(e.value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
        const SizedBox(height: 12),
        const Text(
          'Notes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('• Deliveries per vehicle are aggregated for the selected period.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildClaimsChartDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Claims Summary',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Total Claims', _totalClaims.toString()),
        _buildDetailRow('Top Claim Types', ''),
        const SizedBox(height: 8),
        ..._claimTypeCount.entries.toList().take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontSize: 12)),
                  Text(e.value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            )),
        const SizedBox(height: 12),
        const Text('Recent Claims', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._topClaims.take(5).map((c) {
          final cust = c['customer'] as String? ?? 'Unknown';
          final reason = c['reason'] as String? ?? ''; 
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('$cust — $reason', style: const TextStyle(fontSize: 12)),
          );
        }),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetailRow(String label, int count, Color color) {
    final percentage = _totalDeliveries > 0 ? (count / _totalDeliveries * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

