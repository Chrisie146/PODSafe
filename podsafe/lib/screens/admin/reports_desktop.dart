import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';

/// Reports Desktop Screen - Refactored to use Providers instead of direct Firestore queries
/// This eliminates composite index requirements and reuses data from existing providers
class ReportsDesktop extends StatefulWidget {
  const ReportsDesktop({super.key});

  @override
  State<ReportsDesktop> createState() => _ReportsDesktopState();
}

enum ReportType { delivery, driver, claims, customers, pod }

class _ReportsDesktopState extends State<ReportsDesktop> {
  ReportType _selectedReport = ReportType.delivery;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  // Report data
  List<Map<String, dynamic>> _reportData = [];
  Map<String, dynamic> _summaryStats = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.companyId;

      if (companyId == null || companyId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      switch (_selectedReport) {
        case ReportType.delivery:
          await _loadDeliveryReport(companyId);
          break;
        case ReportType.driver:
          await _loadDriverReport(companyId);
          break;
        case ReportType.claims:
          await _loadClaimsReport(companyId);
          break;
        case ReportType.customers:
          await _loadCustomersReport(companyId);
          break;
        case ReportType.pod:
          await _loadPODReport(companyId);
          break;
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeliveryReport(String companyId) async {
    // Query ALL deliveries for company (no date range or orderBy with composite)
    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .get();

    List<Map<String, dynamic>> data = [];
    int total = 0;
    int completed = 0;
    int pending = 0;
    int inTransit = 0;
    double totalAmount = 0;

    for (var doc in deliveriesSnapshot.docs) {
      final delivery = doc.data();
      
      // Client-side date filtering
      final scheduledDate = delivery['scheduledDate'] as Timestamp?;
      if (scheduledDate == null) continue;
      
      final deliveryDate = scheduledDate.toDate();
      if (deliveryDate.isBefore(_startDate) || deliveryDate.isAfter(_endDate)) {
        continue; // Skip if outside date range
      }

      total++;

      final status = delivery['status'] as String? ?? 'unknown';
      if (status == 'delivered') completed++;
      if (status == 'pending') pending++;
      if (status == 'inTransit') inTransit++;

      // Extract items data
      final items = delivery['items'] as List<dynamic>? ?? [];
      final itemCount = items.length;
      final totalItemValue = items.fold<double>(0.0, (sum, item) {
        final itemData = item as Map<String, dynamic>;
        return sum + ((itemData['price'] as num?)?.toDouble() ?? 0.0) * ((itemData['quantity'] as num?)?.toDouble() ?? 1.0);
      });

      data.add({
        'id': doc.id,
        'trackingNumber': delivery['trackingNumber'] ?? 'N/A',
        'customerName': delivery['customerName'] ?? 'N/A',
        'customerPhone': delivery['customerPhone'] ?? 'N/A',
        'address': delivery['customerAddress'] ?? delivery['address'] ?? 'N/A',
        'status': status,
        'scheduledDate': delivery['scheduledDate'] as Timestamp?,
        'createdAt': delivery['createdAt'] as Timestamp?,
        'completedAt': delivery['completedAt'] as Timestamp?,
        'deliveredAt': delivery['deliveredAt'] as Timestamp?,
        'driverName': delivery['driverName'] ?? 'Unassigned',
        'amount': (delivery['invoiceTotal'] as num?)?.toDouble() ?? 0.0,
        'orderNumber': delivery['orderNumber'] ?? 'N/A',
        'invoiceNumber': delivery['invoiceNumber'] ?? 'N/A',
        'invoiceDate': delivery['invoiceDate'] as Timestamp?,
        'notes': delivery['notes'] ?? '',
        'itemCount': itemCount,
        'totalItemValue': totalItemValue,
        'vehicleUsed': delivery['vehicleUsed'] ?? 'N/A',
        'customerId': delivery['customerId'],
        'customerNumber': delivery['customerNumber'],
      });

      totalAmount += (delivery['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Sort by scheduled date descending (client-side)
    data.sort((a, b) {
      final aDate = (a['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final bDate = (b['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    // Calculate additional metrics
    int totalItems = 0;
    double totalItemValue = 0.0;
    int onTimeDeliveries = 0;
    int lateDeliveries = 0;

    for (var delivery in data) {
      totalItems += (delivery['itemCount'] as int? ?? 0);
      totalItemValue += (delivery['totalItemValue'] as double? ?? 0.0);

      // Calculate on-time delivery rate
      final scheduledDate = delivery['scheduledDate'] as Timestamp?;
      final deliveredAt = delivery['deliveredAt'] as Timestamp?;
      if (scheduledDate != null && deliveredAt != null && delivery['status'] == 'delivered') {
        final scheduled = scheduledDate.toDate();
        final delivered = deliveredAt.toDate();
        if (delivered.isBefore(scheduled.add(const Duration(hours: 1)))) {
          onTimeDeliveries++;
        } else {
          lateDeliveries++;
        }
      }
    }

    setState(() {
      _reportData = data;
      _summaryStats = {
        'total': total,
        'completed': completed,
        'pending': pending,
        'inTransit': inTransit,
        'completionRate': total > 0 ? ((completed / total) * 100).toStringAsFixed(1) : '0.0',
        'totalAmount': totalAmount,
        'totalItems': totalItems,
        'totalItemValue': totalItemValue,
        'onTimeDeliveries': onTimeDeliveries,
        'lateDeliveries': lateDeliveries,
        'onTimeRate': completed > 0 ? ((onTimeDeliveries / completed) * 100).toStringAsFixed(1) : '0.0',
      };
    });
  }

  Future<void> _loadDriverReport(String companyId) async {
    final driversSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'driver')
        .get();

    // Get ALL deliveries for company (no date range in query)
    final allDeliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .get();

    List<Map<String, dynamic>> data = [];
    int totalDrivers = 0;
    int activeDrivers = 0;
    int approvedDrivers = 0;

    for (var driverDoc in driversSnapshot.docs) {
      final driver = driverDoc.data();
      totalDrivers++;

      if (driver['isActive'] as bool? ?? false) activeDrivers++;
      if (driver['approvalStatus'] == 'approved') approvedDrivers++;

      // Filter deliveries for this driver by date range (client-side)
      final driverDeliveries = allDeliveriesSnapshot.docs
          .where((doc) {
            final deliveryData = doc.data();
            if (deliveryData['driverId'] != driverDoc.id) return false;
            
            final scheduledDate = deliveryData['scheduledDate'] as Timestamp?;
            if (scheduledDate == null) return false;
            
            final deliveryDate = scheduledDate.toDate();
            return !deliveryDate.isBefore(_startDate) && !deliveryDate.isAfter(_endDate);
          })
          .toList();

      int completedCount = 0;
      int onTimeCount = 0;
      double totalDeliveryTime = 0.0;
      int deliveriesWithTime = 0;
      double totalRevenue = 0.0;

      for (var delivery in driverDeliveries) {
        final deliveryData = delivery.data();
        if (deliveryData['status'] == 'delivered') {
          completedCount++;

          // Calculate on-time deliveries
          final scheduledDate = deliveryData['scheduledDate'] as Timestamp?;
          final deliveredAt = deliveryData['deliveredAt'] as Timestamp?;
          if (scheduledDate != null && deliveredAt != null) {
            final scheduled = scheduledDate.toDate();
            final delivered = deliveredAt.toDate();
            if (delivered.isBefore(scheduled.add(const Duration(hours: 1)))) {
              onTimeCount++;
            }

            // Calculate delivery time
            final deliveryTime = delivered.difference(scheduled).inMinutes;
            if (deliveryTime > 0) { // Only count positive delivery times
              totalDeliveryTime += deliveryTime;
              deliveriesWithTime++;
            }
          }

          // Sum revenue
          totalRevenue += (deliveryData['invoiceTotal'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final averageDeliveryTime = deliveriesWithTime > 0 ? totalDeliveryTime / deliveriesWithTime : 0.0;
      final onTimeRate = completedCount > 0 ? (onTimeCount / completedCount) * 100 : 0.0;

      data.add({
        'id': driverDoc.id,
        'fullName': driver['fullName'] ?? 'N/A',
        'email': driver['email'] ?? 'N/A',
        'phone': driver['phone'] ?? 'N/A',
        'approvalStatus': driver['approvalStatus'] ?? 'pending',
        'isActive': driver['isActive'] ?? false,
        'deliveriesCount': driverDeliveries.length,
        'completedCount': completedCount,
        'onTimeCount': onTimeCount,
        'onTimeRate': onTimeRate.toStringAsFixed(1),
        'averageDeliveryTime': '${(averageDeliveryTime / 60).toStringAsFixed(1)}h', // Convert minutes to hours
        'totalRevenue': totalRevenue,
        'joinDate': driver['createdAt'] as Timestamp?,
        'rating': driver['rating'] as num? ?? 0.0,
      });
    }

    // Calculate additional summary metrics
    int totalDeliveries = 0;
    int totalCompleted = 0;
    double totalRevenue = 0.0;
    double averageOnTimeRate = 0.0;
    int driversWithDeliveries = 0;

    for (var driver in data) {
      totalDeliveries += driver['deliveriesCount'] as int;
      totalCompleted += driver['completedCount'] as int;
      totalRevenue += driver['totalRevenue'] as double;
      if (driver['deliveriesCount'] > 0) {
        averageOnTimeRate += double.parse(driver['onTimeRate']);
        driversWithDeliveries++;
      }
    }

    averageOnTimeRate = driversWithDeliveries > 0 ? averageOnTimeRate / driversWithDeliveries : 0.0;

    setState(() {
      _reportData = data;
      _summaryStats = {
        'totalDrivers': totalDrivers,
        'activeDrivers': activeDrivers,
        'approvedDrivers': approvedDrivers,
        'pendingApprovals': totalDrivers - approvedDrivers,
        'totalDeliveries': totalDeliveries,
        'totalCompleted': totalCompleted,
        'completionRate': totalDeliveries > 0 ? ((totalCompleted / totalDeliveries) * 100).toStringAsFixed(1) : '0.0',
        'totalRevenue': totalRevenue,
        'averageOnTimeRate': averageOnTimeRate.toStringAsFixed(1),
      };
    });
  }

  Future<void> _loadClaimsReport(String companyId) async {
    final claimsSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('claims')
        .get();

    List<Map<String, dynamic>> data = [];
    int total = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    double totalAmount = 0;
    double approvedAmount = 0;

    for (var doc in claimsSnapshot.docs) {
      final claim = doc.data();
      
      // Client-side date filtering
      final createdAt = claim['createdAt'] as Timestamp?;
      if (createdAt == null) continue;
      
      final claimDate = createdAt.toDate();
      if (claimDate.isBefore(_startDate) || claimDate.isAfter(_endDate)) {
        continue;
      }

      total++;

      final status = claim['status'] as String? ?? 'pending';
      final amount = (claim['claimAmount'] as num?)?.toDouble() ?? 0.0;

      if (status == 'pending') pending++;
      if (status == 'approved') {
        approved++;
        approvedAmount += amount;
      }
      if (status == 'rejected') rejected++;

      totalAmount += amount;

      data.add({
        'id': doc.id,
        'claimNumber': claim['id'] ?? 'N/A',
        'customerName': claim['customerName'] ?? 'N/A',
        'customerPhone': claim['customerNumber'] ?? 'N/A',
        'driverName': claim['driverName'] ?? 'N/A',
        'status': status,
        'amount': amount,
        'type': claim['type'] ?? 'N/A',
        'priority': claim['priority'] ?? 'normal',
        'createdAt': claim['createdAt'] as Timestamp?,
        'updatedAt': claim['updatedAt'] as Timestamp?,
        'resolvedAt': claim['resolvedAt'] as Timestamp?,
        'dueDate': claim['dueDate'] as Timestamp?,
        'deliveryDate': claim['deliveryDate'] as Timestamp?,
        'reason': claim['description'] ?? claim['reason'] ?? 'N/A',
        'resolution': claim['resolution'] ?? 'N/A',
        'investigatedBy': claim['investigatedBy'] ?? 'N/A',
        'resolutionNotes': claim['resolutionNotes'] ?? 'N/A',
        'evidenceQualityScore': claim['evidenceQualityScore'] as num? ?? 0,
        'hasAllRequiredEvidence': claim['hasAllRequiredEvidence'] as bool? ?? false,
      });
    }

    // Sort by created date descending (client-side)
    data.sort((a, b) {
      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    // Calculate additional metrics
    int urgentClaims = 0;
    int highPriority = 0;
    int resolvedWithinSLA = 0;
    int overdue = 0;
    double averageResolutionTime = 0.0;
    int resolvedClaims = 0;

    for (var claim in data) {
      if (claim['priority'] == 'urgent') urgentClaims++;
      if (claim['priority'] == 'high') highPriority++;

      final createdAt = claim['createdAt'] as Timestamp?;
      final resolvedAt = claim['resolvedAt'] as Timestamp?;
      final dueDate = claim['dueDate'] as Timestamp?;

      if (createdAt != null && resolvedAt != null) {
        resolvedClaims++;
        final resolutionTime = resolvedAt.toDate().difference(createdAt.toDate()).inDays;
        averageResolutionTime += resolutionTime;

        // Check if resolved within SLA (assuming 7 days)
        if (resolutionTime <= 7) resolvedWithinSLA++;
      }

      // FIX: Only count truly overdue claims (exclude approved, rejected, resolved)
      if (dueDate != null && DateTime.now().isAfter(dueDate.toDate()) && 
          !['resolved', 'approved', 'rejected'].contains(claim['status'])) {
        overdue++;
      }
    }

    averageResolutionTime = resolvedClaims > 0 ? averageResolutionTime / resolvedClaims : 0.0;

    setState(() {
      _reportData = data;
      _summaryStats = {
        'total': total,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'totalAmount': totalAmount,
        'approvedAmount': approvedAmount,
        'approvalRate': approved > 0 ? ((approved / total) * 100).toStringAsFixed(1) : '0.0',
        'urgentClaims': urgentClaims,
        'highPriority': highPriority,
        'overdue': overdue,
        'resolvedWithinSLA': resolvedWithinSLA,
        'averageResolutionTime': '${averageResolutionTime.toStringAsFixed(1)} days',
        'resolutionRate': total > 0 ? (((approved + rejected) / total) * 100).toStringAsFixed(1) : '0.0',
      };
    });
  }

  Future<void> _loadCustomersReport(String companyId) async {
    final customersSnapshot = await FirebaseFirestore.instance
        .collection('customers')
        .where('companyId', isEqualTo: companyId)
        .get();

    // Get ALL deliveries for company (no date range in query)
    final allDeliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .get();

    List<Map<String, dynamic>> data = [];

    for (var customerDoc in customersSnapshot.docs) {
      final customer = customerDoc.data();

      // Filter deliveries for this customer by date range (client-side)
      final customerDeliveries = allDeliveriesSnapshot.docs
          .where((doc) {
            final deliveryData = doc.data();
            if (deliveryData['customerId'] != customerDoc.id) return false;
            
            final scheduledDate = deliveryData['scheduledDate'] as Timestamp?;
            if (scheduledDate == null) return false;
            
            final deliveryDate = scheduledDate.toDate();
            return !deliveryDate.isBefore(_startDate) && !deliveryDate.isAfter(_endDate);
          })
          .toList();

      int completedCount = 0;
      double totalAmount = 0;
      DateTime? lastDeliveryDate;
      int pendingDeliveries = 0;
      int failedDeliveries = 0;

      for (var delivery in customerDeliveries) {
        final deliveryData = delivery.data();
        final status = deliveryData['status'] as String? ?? 'unknown';
        final amount = (deliveryData['invoiceTotal'] as num?)?.toDouble() ?? 0.0;
        final scheduledDate = (deliveryData['scheduledDate'] as Timestamp?)?.toDate();

        if (status == 'delivered') {
          completedCount++;
          if (scheduledDate != null && (lastDeliveryDate == null || scheduledDate.isAfter(lastDeliveryDate))) {
            lastDeliveryDate = scheduledDate;
          }
        } else if (status == 'pending') {
          pendingDeliveries++;
        } else if (status == 'cancelled' || status == 'failed') {
          failedDeliveries++;
        }

        totalAmount += amount;
      }

      data.add({
        'id': customerDoc.id,
        'name': customer['name'] ?? 'N/A',
        'email': customer['email'] ?? 'N/A',
        'phone': customer['phone'] ?? 'N/A',
        'city': customer['city'] ?? 'N/A',
        'address': customer['address'] ?? 'N/A',
        'accountNumber': customer['accountNumber'] ?? customer['customerNumber'] ?? 'N/A',
        'customerType': customer['customerType'] ?? 'regular',
        'deliveriesCount': customerDeliveries.length,
        'completedCount': completedCount,
        'pendingCount': pendingDeliveries,
        'failedCount': failedDeliveries,
        'totalAmount': totalAmount,
        'lastDeliveryDate': lastDeliveryDate,
        'createdAt': customer['createdAt'] as Timestamp?,
        'rating': customer['rating'] as num? ?? 0.0,
        'preferredDriver': customer['preferredDriver'] ?? 'N/A',
      });
    }

    // Calculate additional summary metrics
    int totalDeliveries = 0;
    int totalCompleted = 0;
    int totalPending = 0;
    int totalFailed = 0;
    double totalRevenue = 0.0;
    int activeCustomers = 0;
    int vipCustomers = 0;

    for (var customer in data) {
      totalDeliveries += customer['deliveriesCount'] as int;
      totalCompleted += customer['completedCount'] as int;
      totalPending += customer['pendingCount'] as int;
      totalFailed += customer['failedCount'] as int;
      totalRevenue += customer['totalAmount'] as double;

      if (customer['deliveriesCount'] > 0) activeCustomers++;
      if (customer['customerType'] == 'vip' || customer['totalAmount'] > 10000) vipCustomers++;
    }

    setState(() {
      _reportData = data;
      _summaryStats = {
        'totalCustomers': customersSnapshot.docs.length,
        'activeCustomers': activeCustomers,
        'vipCustomers': vipCustomers,
        'totalDeliveries': totalDeliveries,
        'totalCompleted': totalCompleted,
        'totalPending': totalPending,
        'totalFailed': totalFailed,
        'completionRate': totalDeliveries > 0 ? ((totalCompleted / totalDeliveries) * 100).toStringAsFixed(1) : '0.0',
        'totalRevenue': totalRevenue,
        'averageOrderValue': totalDeliveries > 0 ? (totalRevenue / totalDeliveries).toStringAsFixed(2) : '0.00',
      };
    });
  }

  Future<void> _loadPODReport(String companyId) async {
    final podsSnapshot = await FirebaseFirestore.instance
        .collection('pods')
        .where('companyId', isEqualTo: companyId)
        .get();

    List<Map<String, dynamic>> data = [];
    int total = 0;
    int signed = 0;
    int withPhotos = 0;
    int withNotes = 0;

    for (var doc in podsSnapshot.docs) {
      final pod = doc.data();
      
      // Client-side date filtering
      final createdAt = pod['createdAt'] as Timestamp?;
      if (createdAt == null) continue;
      
      final podDate = createdAt.toDate();
      if (podDate.isBefore(_startDate) || podDate.isAfter(_endDate)) {
        continue;
      }

      total++;

      final hasSigned = (pod['signatureData'] as String?)?.isNotEmpty ?? false;
      final hasPhotos = ((pod['photos'] as List?)?.isNotEmpty) ?? false;
      final hasNotes = (pod['notes'] as String?)?.isNotEmpty ?? false;

      final photos = pod['photos'] as List<dynamic>? ?? [];
      final photoCount = photos.length;
      final notes = pod['notes'] as String? ?? '';

      // Extract GPS location if available
      final location = pod['location'] as Map<String, dynamic>?;
      final latitude = location?['latitude'] as double?;
      final longitude = location?['longitude'] as double?;
      final hasLocation = latitude != null && longitude != null;

      // Extract delivery items if available
      final deliveryItems = pod['deliveryItems'] as List<dynamic>? ?? [];
      final itemCount = deliveryItems.length;

      if (hasSigned) signed++;
      if (hasPhotos) withPhotos++;
      if (hasNotes) withNotes++;

      data.add({
        'id': doc.id,
        'deliveryId': pod['deliveryId'] ?? 'N/A',
        'driverName': pod['driverName'] ?? 'N/A',
        'customerName': pod['customerName'] ?? 'N/A',
        'customerPhone': pod['customerPhone'] ?? 'N/A',
        'receiverName': pod['receiverName'] ?? 'Not specified',
        'hasSigned': hasSigned,
        'hasPhotos': hasPhotos,
        'hasNotes': hasNotes,
        'photoCount': photoCount,
        'notes': notes.length > 50 ? '${notes.substring(0, 50)}...' : notes,
        'fullNotes': notes,
        'hasLocation': hasLocation,
        'latitude': latitude,
        'longitude': longitude,
        'itemCount': itemCount,
        'signatureQuality': pod['signatureQuality'] as num? ?? 0,
        'evidenceScore': pod['evidenceScore'] as num? ?? 0,
        'createdAt': pod['createdAt'] as Timestamp?,
        'deviceInfo': pod['deviceInfo'] ?? 'N/A',
      });
    }

    // Sort by created date descending (client-side)
    data.sort((a, b) {
      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _reportData = data;
      _summaryStats = {
        'total': total,
        'signed': signed,
        'withPhotos': withPhotos,
        'withNotes': withNotes,
        'signatureRate': total > 0 ? ((signed / total) * 100).toStringAsFixed(1) : '0.0',
      };
    });
  }

  void _showDateRangePicker() async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showDateRangePicker,
            tooltip: 'Date Range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Enhanced Sidebar
                Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.assessment, color: Colors.white, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'Reports',
                              style: AppTextStyles.heading3.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Business Analytics',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSidebarItem(ReportType.delivery, 'Deliveries', Icons.local_shipping),
                      _buildSidebarItem(ReportType.driver, 'Drivers', Icons.person),
                      _buildSidebarItem(ReportType.claims, 'Claims', Icons.assignment),
                      _buildSidebarItem(ReportType.customers, 'Customers', Icons.business),
                      _buildSidebarItem(ReportType.pod, 'PODs', Icons.receipt),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
          child: SingleChildScrollView(
            // Top padding removed so content sits flush under the AppBar
            padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          _getReportTitle(),
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Showing data from ${DateFormat('MMM dd, yyyy').format(_startDate)} to ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),

                        // Summary Statistics
                        _buildSummaryStats(),
                        const SizedBox(height: 12),

                        // Report Table
                        _buildReportTable(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSidebarItem(ReportType type, String label, IconData icon) {
    final isSelected = _selectedReport == type;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppTheme.primaryColor, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : Colors.black87,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        selected: isSelected,
        onTap: () {
          setState(() => _selectedReport = type);
          _loadReport();
        },
      ),
    );
  }

  String _getReportTitle() {
    switch (_selectedReport) {
      case ReportType.delivery:
        return 'Delivery Report';
      case ReportType.driver:
        return 'Driver Report';
      case ReportType.claims:
        return 'Claims Report';
      case ReportType.customers:
        return 'Customer Report';
      case ReportType.pod:
        return 'POD Report';
    }
  }

  Widget _buildSummaryStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: AppTextStyles.heading3.copyWith(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        // Use LayoutBuilder + Wrap so each card sizes to its content (compact height)
        LayoutBuilder(
          builder: (context, constraints) {
            final int columns = 4;
            final double spacing = 8.0;
            final double cardWidth = (constraints.maxWidth - (columns - 1) * spacing) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _buildSummaryCards()
                  .map((w) => SizedBox(width: cardWidth, child: w))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildSummaryCards() {
    List<Widget> cards = [];

    switch (_selectedReport) {
      case ReportType.delivery:
        cards = [
          _buildStatCard('Total', _summaryStats['total']?.toString() ?? '0', Colors.blue),
          _buildStatCard('Completed', _summaryStats['completed']?.toString() ?? '0', Colors.green),
          _buildStatCard('Pending', _summaryStats['pending']?.toString() ?? '0', Colors.orange),
          _buildStatCard('In Transit', _summaryStats['inTransit']?.toString() ?? '0', Colors.purple),
          _buildStatCard('Completion Rate', '${_summaryStats['completionRate'] ?? '0.0'}%', Colors.teal),
          _buildStatCard('On-Time Rate', '${_summaryStats['onTimeRate'] ?? '0.0'}%', Colors.indigo),
          _buildStatCard('Total Items', _summaryStats['totalItems']?.toString() ?? '0', Colors.amber),
          _buildStatCard('Revenue', 'R${(_summaryStats['totalAmount'] as double?)?.toStringAsFixed(2) ?? '0.00'}', Colors.green),
        ];
        break;
      case ReportType.driver:
        cards = [
          _buildStatCard('Total Drivers', _summaryStats['totalDrivers']?.toString() ?? '0', Colors.blue),
          _buildStatCard('Active', _summaryStats['activeDrivers']?.toString() ?? '0', Colors.green),
          _buildStatCard('Approved', _summaryStats['approvedDrivers']?.toString() ?? '0', Colors.purple),
          _buildStatCard('Pending', _summaryStats['pendingApprovals']?.toString() ?? '0', Colors.orange),
          _buildStatCard('Total Deliveries', _summaryStats['totalDeliveries']?.toString() ?? '0', Colors.teal),
          _buildStatCard('Completion Rate', '${_summaryStats['completionRate'] ?? '0.0'}%', Colors.indigo),
          _buildStatCard('Avg On-Time', '${_summaryStats['averageOnTimeRate'] ?? '0.0'}%', Colors.amber),
          _buildStatCard('Total Revenue', 'R${(_summaryStats['totalRevenue'] as double?)?.toStringAsFixed(2) ?? '0.00'}', Colors.green),
        ];
        break;
      case ReportType.claims:
        cards = [
          _buildStatCard('Total Claims', _summaryStats['total']?.toString() ?? '0', Colors.blue),
          _buildStatCard('Pending', _summaryStats['pending']?.toString() ?? '0', Colors.orange),
          _buildStatCard('Approved', _summaryStats['approved']?.toString() ?? '0', Colors.green),
          _buildStatCard('Rejected', _summaryStats['rejected']?.toString() ?? '0', Colors.red),
          _buildStatCard('Urgent', _summaryStats['urgentClaims']?.toString() ?? '0', Colors.red),
          _buildStatCard('Overdue', _summaryStats['overdue']?.toString() ?? '0', Colors.purple),
          _buildStatCard('Resolution Rate', '${_summaryStats['resolutionRate'] ?? '0.0'}%', Colors.teal),
          _buildStatCard('Avg Resolution', _summaryStats['averageResolutionTime']?.toString() ?? '0 days', Colors.indigo),
        ];
        break;
      case ReportType.customers:
        cards = [
          _buildStatCard('Total Customers', _summaryStats['totalCustomers']?.toString() ?? '0', Colors.blue),
          _buildStatCard('Active', _summaryStats['activeCustomers']?.toString() ?? '0', Colors.green),
          _buildStatCard('VIP Customers', _summaryStats['vipCustomers']?.toString() ?? '0', Colors.purple),
          _buildStatCard('Total Deliveries', _summaryStats['totalDeliveries']?.toString() ?? '0', Colors.teal),
          _buildStatCard('Completion Rate', '${_summaryStats['completionRate'] ?? '0.0'}%', Colors.indigo),
          _buildStatCard('Total Revenue', 'R${(_summaryStats['totalRevenue'] as double?)?.toStringAsFixed(2) ?? '0.00'}', Colors.green),
          _buildStatCard('Avg Order Value', 'R${_summaryStats['averageOrderValue'] ?? '0.00'}', Colors.amber),
          _buildStatCard('Pending Orders', _summaryStats['totalPending']?.toString() ?? '0', Colors.orange),
        ];
        break;
      case ReportType.pod:
        cards = [
          _buildStatCard('Total PODs', _summaryStats['total']?.toString() ?? '0', Colors.blue),
          _buildStatCard('Signed', _summaryStats['signed']?.toString() ?? '0', Colors.green),
          _buildStatCard('With Photos', _summaryStats['withPhotos']?.toString() ?? '0', Colors.purple),
          _buildStatCard('With Notes', _summaryStats['withNotes']?.toString() ?? '0', Colors.teal),
        ];
        break;
    }

    return cards;
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      // keep horizontal padding but reduce vertical to maximize compactness
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    // slightly larger, bolder label for readability
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _getStatCardIcon(label),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              // larger value text for emphasis while keeping compact card height
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _getStatCardIcon(String label) {
    IconData icon = Icons.info;
    if (label.contains('Total')) icon = Icons.assessment;
    if (label.contains('Completed') || label.contains('Approved')) icon = Icons.check_circle;
    if (label.contains('Pending')) icon = Icons.schedule;
    if (label.contains('Rate') || label.contains('Average')) icon = Icons.trending_up;
    if (label.contains('Revenue') || label.contains('Amount')) icon = Icons.monetization_on;
    if (label.contains('Signed')) icon = Icons.edit;
    if (label.contains('Photos')) icon = Icons.photo;
    if (label.contains('Transit')) icon = Icons.local_shipping;
    if (label.contains('Active')) icon = Icons.check;
    if (label.contains('Rejected') || label.contains('Overdue')) icon = Icons.error;
    if (label.contains('Urgent')) icon = Icons.priority_high;
    if (label.contains('Items')) icon = Icons.inventory;
    if (label.contains('VIP')) icon = Icons.star;
    
    return Icon(icon, size: 18, color: Colors.grey[600]);
  }

  Widget _buildReportTable() {
    if (_reportData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(64),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inbox, size: 64, color: Colors.blue.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 24),
              Text(
                'No data available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your date range or filters',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: _buildTableColumns(),
            rows: _buildTableRows(),
            columnSpacing: 24,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            headingRowHeight: 56,
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => AppTheme.primaryColor.withValues(alpha: 0.08),
            ),
            dataRowColor: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return Colors.grey[100]!;
              }
              return Colors.white;
            }),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: AppTheme.primaryColor,
      fontSize: 13,
      letterSpacing: 0.3,
    );

    switch (_selectedReport) {
      case ReportType.delivery:
        return [
          DataColumn(label: Text('Tracking #', style: headerStyle)),
          DataColumn(label: Text('Customer', style: headerStyle)),
          DataColumn(label: Text('Phone', style: headerStyle)),
          DataColumn(label: Text('Address', style: headerStyle)),
          DataColumn(label: Text('Driver', style: headerStyle)),
          DataColumn(label: Text('Status', style: headerStyle)),
          DataColumn(label: Text('Scheduled', style: headerStyle)),
          DataColumn(label: Text('Completed', style: headerStyle)),
          DataColumn(label: Text('Items', style: headerStyle)),
          DataColumn(label: Text('Amount', style: headerStyle)),
          DataColumn(label: Text('Order #', style: headerStyle)),
          DataColumn(label: Text('Invoice #', style: headerStyle)),
          DataColumn(label: Text('Notes', style: headerStyle)),
        ];
      case ReportType.driver:
        return [
          DataColumn(label: Text('Name', style: headerStyle)),
          DataColumn(label: Text('Email', style: headerStyle)),
          DataColumn(label: Text('Phone', style: headerStyle)),
          DataColumn(label: Text('Status', style: headerStyle)),
          DataColumn(label: Text('Deliveries', style: headerStyle)),
          DataColumn(label: Text('Completed', style: headerStyle)),
          DataColumn(label: Text('On-Time %', style: headerStyle)),
          DataColumn(label: Text('Avg Time', style: headerStyle)),
          DataColumn(label: Text('Revenue', style: headerStyle)),
        ];
      case ReportType.claims:
        return [
          DataColumn(label: Text('Claim #', style: headerStyle)),
          DataColumn(label: Text('Customer', style: headerStyle)),
          DataColumn(label: Text('Type', style: headerStyle)),
          DataColumn(label: Text('Priority', style: headerStyle)),
          DataColumn(label: Text('Status', style: headerStyle)),
          DataColumn(label: Text('Amount', style: headerStyle)),
          DataColumn(label: Text('Due Date', style: headerStyle)),
          DataColumn(label: Text('Resolution', style: headerStyle)),
        ];
      case ReportType.customers:
        return [
          DataColumn(label: Text('Name', style: headerStyle)),
          DataColumn(label: Text('Email', style: headerStyle)),
          DataColumn(label: Text('Phone', style: headerStyle)),
          DataColumn(label: Text('City', style: headerStyle)),
          DataColumn(label: Text('Account #', style: headerStyle)),
          DataColumn(label: Text('Deliveries', style: headerStyle)),
          DataColumn(label: Text('Completed', style: headerStyle)),
          DataColumn(label: Text('Total Amount', style: headerStyle)),
          DataColumn(label: Text('Last Delivery', style: headerStyle)),
        ];
      case ReportType.pod:
        return [
          DataColumn(label: Text('Delivery ID', style: headerStyle)),
          DataColumn(label: Text('Driver', style: headerStyle)),
          DataColumn(label: Text('Customer', style: headerStyle)),
          DataColumn(label: Text('Receiver', style: headerStyle)),
          DataColumn(label: Text('Phone', style: headerStyle)),
          DataColumn(label: Text('Signed', style: headerStyle)),
          DataColumn(label: Text('Photos', style: headerStyle)),
          DataColumn(label: Text('Notes', style: headerStyle)),
          DataColumn(label: Text('Items', style: headerStyle)),
          DataColumn(label: Text('Location', style: headerStyle)),
          DataColumn(label: Text('Quality', style: headerStyle)),
          DataColumn(label: Text('Date', style: headerStyle)),
        ];
    }
  }

  List<DataRow> _buildTableRows() {
    switch (_selectedReport) {
      case ReportType.delivery:
        return _reportData.map((data) {
          final scheduledDate = data['scheduledDate'] as Timestamp?;
          final completedAt = data['completedAt'] as Timestamp?;
          return DataRow(cells: [
            DataCell(Text((data['trackingNumber'] ?? 'N/A').toString().length > 15
                ? '${(data['trackingNumber'] ?? 'N/A').toString().substring(0, 15)}...'
                : (data['trackingNumber'] ?? 'N/A').toString())),
            DataCell(Text((data['customerName'] ?? 'N/A').toString())),
            DataCell(Text((data['customerPhone'] ?? 'N/A').toString())),
            DataCell(Text((data['address'] ?? 'N/A').toString())),
            DataCell(Text((data['driverName'] ?? 'N/A').toString())),
            DataCell(
              Chip(
                label: Text((data['status'] ?? 'unknown').toString()),
                backgroundColor: _getStatusColor((data['status'] ?? 'unknown').toString()).withValues(alpha: 0.3),
                labelStyle: TextStyle(color: _getStatusColor((data['status'] ?? 'unknown').toString())),
              ),
            ),
            DataCell(Text(scheduledDate != null ? DateFormat('MMM dd, yyyy').format(scheduledDate.toDate()) : 'N/A')),
            DataCell(Text(completedAt != null ? DateFormat('MMM dd, yyyy').format(completedAt.toDate()) : 'N/A')),
            DataCell(Text((data['itemCount'] ?? 0).toString())),
            DataCell(Text('R${((data['amount'] as num?) ?? 0.0).toDouble().toStringAsFixed(2)}')),
            DataCell(Text((data['orderNumber'] ?? 'N/A').toString())),
            DataCell(Text((data['invoiceNumber'] ?? 'N/A').toString())),
            DataCell(Text((data['notes'] ?? '').toString())),
          ]);
        }).toList();

      case ReportType.driver:
        return _reportData.map((data) {
          return DataRow(cells: [
            DataCell(Text((data['fullName'] ?? 'N/A').toString())),
            DataCell(Text((data['email'] ?? 'N/A').toString())),
            DataCell(Text((data['phone'] ?? 'N/A').toString())),
            DataCell(
              Chip(
                label: Text((data['approvalStatus'] ?? 'pending').toString()),
                backgroundColor: _getStatusColor((data['approvalStatus'] ?? 'pending').toString()).withValues(alpha: 0.3),
                labelStyle: TextStyle(color: _getStatusColor((data['approvalStatus'] ?? 'pending').toString())),
              ),
            ),
            DataCell(Text((data['deliveriesCount'] ?? 0).toString())),
            DataCell(Text((data['completedCount'] ?? 0).toString())),
            DataCell(Text('${data['onTimeRate'] ?? 0}%')),
            DataCell(Text((data['averageDeliveryTime'] ?? 'N/A').toString())),
            DataCell(Text('R${((data['totalRevenue'] as num?) ?? 0.0).toDouble().toStringAsFixed(2)}')),
          ]);
        }).toList();

      case ReportType.claims:
        return _reportData.map((data) {
          final dueDate = data['dueDate'] as Timestamp?;
          return DataRow(cells: [
            DataCell(Text((data['claimNumber'] ?? 'N/A').toString())),
            DataCell(Text((data['customerName'] ?? 'N/A').toString())),
            DataCell(Text((data['type'] ?? 'N/A').toString())),
            DataCell(
              Chip(
                label: Text((data['priority'] ?? 'normal').toString()),
                backgroundColor: _getPriorityColor((data['priority'] ?? 'normal').toString()).withValues(alpha: 0.3),
                labelStyle: TextStyle(color: _getPriorityColor((data['priority'] ?? 'normal').toString())),
              ),
            ),
            DataCell(
              Chip(
                label: Text((data['status'] ?? 'pending').toString()),
                backgroundColor: _getStatusColor((data['status'] ?? 'pending').toString()).withValues(alpha: 0.3),
                labelStyle: TextStyle(color: _getStatusColor((data['status'] ?? 'pending').toString())),
              ),
            ),
            DataCell(Text('R${((data['amount'] as num?) ?? 0.0).toDouble().toStringAsFixed(2)}')),
            DataCell(Text(dueDate != null ? DateFormat('MMM dd, yyyy').format(dueDate.toDate()) : 'N/A')),
            DataCell(Text((data['resolution'] ?? 'N/A').toString())),
          ]);
        }).toList();

      case ReportType.customers:
        return _reportData.map((data) {
          final lastDeliveryDate = data['lastDeliveryDate'] as DateTime?;
          return DataRow(cells: [
            DataCell(Text((data['name'] ?? 'N/A').toString())),
            DataCell(Text((data['email'] ?? 'N/A').toString())),
            DataCell(Text((data['phone'] ?? 'N/A').toString())),
            DataCell(Text((data['city'] ?? 'N/A').toString())),
            DataCell(Text((data['accountNumber'] ?? 'N/A').toString())),
            DataCell(Text((data['deliveriesCount'] ?? 0).toString())),
            DataCell(Text((data['completedCount'] ?? 0).toString())),
            DataCell(Text('R${((data['totalAmount'] as num?) ?? 0.0).toDouble().toStringAsFixed(2)}')),
            DataCell(Text(lastDeliveryDate != null ? DateFormat('MMM dd, yyyy').format(lastDeliveryDate) : 'Never')),
          ]);
        }).toList();

      case ReportType.pod:
        return _reportData.map((data) {
          final createdAt = data['createdAt'] as Timestamp?;
          return DataRow(cells: [
            DataCell(Text((data['deliveryId'] ?? 'N/A').toString())),
            DataCell(Text((data['driverName'] ?? 'N/A').toString())),
            DataCell(Text((data['customerName'] ?? 'N/A').toString())),
            DataCell(Text((data['receiverName'] ?? 'Not specified').toString())),
            DataCell(Text((data['customerPhone'] ?? 'N/A').toString())),
            DataCell(
              Icon(
                data['hasSigned'] as bool? ?? false ? Icons.check_circle : Icons.cancel,
                color: (data['hasSigned'] as bool? ?? false) ? Colors.green : Colors.red,
              ),
            ),
            DataCell(
              Row(
                children: [
                  Icon(
                    data['hasPhotos'] as bool? ?? false ? Icons.photo : Icons.photo_camera,
                    color: (data['hasPhotos'] as bool? ?? false) ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text('${data['photoCount'] ?? 0}'),
                ],
              ),
            ),
            DataCell(
              Tooltip(
                message: (data['fullNotes'] ?? data['notes'] ?? '').toString(),
                child: Text((data['notes'] ?? '').toString()),
              ),
            ),
            DataCell(Text((data['itemCount'] ?? 0).toString())),
            DataCell(
              Icon(
                data['hasLocation'] as bool? ?? false ? Icons.location_on : Icons.location_off,
                color: (data['hasLocation'] as bool? ?? false) ? Colors.blue : Colors.grey,
                size: 16,
              ),
            ),
            DataCell(
              Row(
                children: [
                  Icon(
                    (data['evidenceScore'] as num? ?? 0) > 70 ? Icons.star : Icons.star_border,
                    color: (data['evidenceScore'] as num? ?? 0) > 70 ? Colors.amber : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text('${data['evidenceScore'] ?? 0}%'),
                ],
              ),
            ),
            DataCell(Text(createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt.toDate()) : 'N/A')),
          ]);
        }).toList();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'intransit':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
