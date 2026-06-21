import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
import 'reports_desktop.dart';

/// Reports Screen - Main entry point
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: Width > 1200px
        // Mobile: Width <= 1200px
        if (constraints.maxWidth > 1200) {
          return const ReportsDesktop();
        }
        return const ReportsMobile();
      },
    );
  }
}

class ReportsMobile extends StatefulWidget {
  const ReportsMobile({super.key});

  @override
  State<ReportsMobile> createState() => _ReportsMobileState();
}

enum ReportType { delivery, driver, claims, customers, pod }

class _ReportsMobileState extends State<ReportsMobile> {
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
    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .orderBy('scheduledDate', descending: true)
        .get();

    List<Map<String, dynamic>> data = [];
    int total = 0;
    int completed = 0;
    int pending = 0;
    int inTransit = 0;
    double totalAmount = 0;

    for (var doc in deliveriesSnapshot.docs) {
      final delivery = doc.data();
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
    // Get all drivers for the company
    final driversSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'driver')
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

      // Get delivery count for this driver in the date range
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('driverId', isEqualTo: driverDoc.id)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
          .get();

      int completedCount = 0;
      int onTimeCount = 0;
      double totalDeliveryTime = 0.0;
      int deliveriesWithTime = 0;
      double totalRevenue = 0.0;

      for (var delivery in deliveriesSnapshot.docs) {
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
        'deliveriesCount': deliveriesSnapshot.docs.length,
        'completedCount': completedCount,
        'onTimeCount': onTimeCount,
        'onTimeRate': onTimeRate.toStringAsFixed(1),
        'averageDeliveryTime': '${(averageDeliveryTime / 60).toStringAsFixed(1)}h', // Convert minutes to hours
        'totalRevenue': totalRevenue,
        'joinDate': driver['createdAt'] as Timestamp?,
        'rating': driver['rating'] as num? ?? 0.0, // If you have driver ratings
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
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .orderBy('createdAt', descending: true)
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

        // Check if resolved within SLA (assuming 7 days for demo)
        if (resolutionTime <= 7) resolvedWithinSLA++;
      }

      if (dueDate != null && DateTime.now().isAfter(dueDate.toDate()) && claim['status'] != 'resolved') {
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

    List<Map<String, dynamic>> data = [];

    for (var customerDoc in customersSnapshot.docs) {
      final customer = customerDoc.data();

      // Get delivery count for this customer
      final deliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('customerId', isEqualTo: customerDoc.id)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
          .get();

      int completedCount = 0;
      double totalAmount = 0;
      DateTime? lastDeliveryDate;
      int pendingDeliveries = 0;
      int failedDeliveries = 0;

      for (var delivery in deliveriesSnapshot.docs) {
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
        'deliveriesCount': deliveriesSnapshot.docs.length,
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
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> data = [];
    int total = 0;
    int signed = 0;
    int withPhotos = 0;
    int withNotes = 0;

    for (var doc in podsSnapshot.docs) {
      final pod = doc.data();
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
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report Type Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          _buildReportTypeButton(ReportType.delivery, 'Deliveries'),
                          _buildReportTypeButton(ReportType.driver, 'Drivers'),
                          _buildReportTypeButton(ReportType.claims, 'Claims'),
                          _buildReportTypeButton(ReportType.customers, 'Customers'),
                          _buildReportTypeButton(ReportType.pod, 'PODs'),
                        ],
                      ),
                    ),
                  ),

                  // Summary Statistics
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildSummaryStats(),
                  ),

                  // Report Table
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildReportTable(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportTypeButton(ReportType type, String label) {
    final isSelected = _selectedReport == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedReport = type);
          _loadReport();
        },
        backgroundColor: Colors.grey[200],
        selectedColor: AppTheme.primaryColor.withOpacity(0.3),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: _buildSummaryCards(),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable() {
    if (_reportData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: _buildTableColumns(),
            rows: _buildTableRows(),
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => AppTheme.primaryColor.withOpacity(0.1),
            ),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    switch (_selectedReport) {
      case ReportType.delivery:
        return [
          const DataColumn(label: Text('Tracking #')),
          const DataColumn(label: Text('Customer')),
          const DataColumn(label: Text('Phone')),
          const DataColumn(label: Text('Address')),
          const DataColumn(label: Text('Driver')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Scheduled')),
          const DataColumn(label: Text('Completed')),
          const DataColumn(label: Text('Items')),
          const DataColumn(label: Text('Amount')),
          const DataColumn(label: Text('Order #')),
          const DataColumn(label: Text('Invoice #')),
          const DataColumn(label: Text('Notes')),
        ];
      case ReportType.driver:
        return [
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Phone')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Deliveries')),
          const DataColumn(label: Text('Completed')),
          const DataColumn(label: Text('On-Time %')),
          const DataColumn(label: Text('Avg Time')),
          const DataColumn(label: Text('Revenue')),
        ];
      case ReportType.claims:
        return [
          const DataColumn(label: Text('Claim #')),
          const DataColumn(label: Text('Customer')),
          const DataColumn(label: Text('Type')),
          const DataColumn(label: Text('Priority')),
          const DataColumn(label: Text('Status')),
          const DataColumn(label: Text('Amount')),
          const DataColumn(label: Text('Due Date')),
          const DataColumn(label: Text('Resolution')),
        ];
      case ReportType.customers:
        return [
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Email')),
          const DataColumn(label: Text('Phone')),
          const DataColumn(label: Text('City')),
          const DataColumn(label: Text('Account #')),
          const DataColumn(label: Text('Deliveries')),
          const DataColumn(label: Text('Completed')),
          const DataColumn(label: Text('Total Amount')),
          const DataColumn(label: Text('Last Delivery')),
        ];
      case ReportType.pod:
        return [
          const DataColumn(label: Text('Delivery ID')),
          const DataColumn(label: Text('Driver')),
          const DataColumn(label: Text('Customer')),
          const DataColumn(label: Text('Receiver')),
          const DataColumn(label: Text('Phone')),
          const DataColumn(label: Text('Signed')),
          const DataColumn(label: Text('Photos')),
          const DataColumn(label: Text('Notes')),
          const DataColumn(label: Text('Items')),
          const DataColumn(label: Text('Location')),
          const DataColumn(label: Text('Quality')),
          const DataColumn(label: Text('Date')),
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
            DataCell(Text(data['trackingNumber'].toString().length > 10
                ? data['trackingNumber'].toString().substring(0, 10)
                : data['trackingNumber'].toString())),
            DataCell(Text(data['customerName'].toString().length > 15
                ? '${data['customerName'].toString().substring(0, 15)}...'
                : data['customerName'].toString())),
            DataCell(Text(data['customerPhone'].toString())),
            DataCell(Text(data['address'].toString().length > 20
                ? '${data['address'].toString().substring(0, 20)}...'
                : data['address'].toString())),
            DataCell(Text(data['driverName'].toString().length > 12
                ? data['driverName'].toString().substring(0, 12)
                : data['driverName'].toString())),
            DataCell(
              Chip(
                label: Text(data['status']),
                backgroundColor: _getStatusColor(data['status']).withOpacity(0.3),
                labelStyle: TextStyle(color: _getStatusColor(data['status'])),
              ),
            ),
            DataCell(Text(scheduledDate != null ? DateFormat('MMM dd').format(scheduledDate.toDate()) : 'N/A')),
            DataCell(Text(completedAt != null ? DateFormat('MMM dd').format(completedAt.toDate()) : 'N/A')),
            DataCell(Text(data['itemCount'].toString())),
            DataCell(Text('R${(data['amount'] as double).toStringAsFixed(2)}')),
            DataCell(Text(data['orderNumber'].toString())),
            DataCell(Text(data['invoiceNumber'].toString())),
            DataCell(Text(data['notes'].toString().length > 15
                ? '${data['notes'].toString().substring(0, 15)}...'
                : data['notes'].toString())),
          ]);
        }).toList();

      case ReportType.driver:
        return _reportData.map((data) {
          return DataRow(cells: [
            DataCell(Text(data['fullName'].toString())),
            DataCell(Text(data['email'].toString().length > 20
                ? '${data['email'].toString().substring(0, 20)}...'
                : data['email'].toString())),
            DataCell(Text(data['phone'].toString())),
            DataCell(
              Chip(
                label: Text(data['approvalStatus']),
                backgroundColor: _getStatusColor(data['approvalStatus']).withOpacity(0.3),
                labelStyle: TextStyle(color: _getStatusColor(data['approvalStatus'])),
              ),
            ),
            DataCell(Text(data['deliveriesCount'].toString())),
            DataCell(Text(data['completedCount'].toString())),
            DataCell(Text('${data['onTimeRate']}%')),
            DataCell(Text(data['averageDeliveryTime'].toString())),
            DataCell(Text('R${(data['totalRevenue'] as double).toStringAsFixed(2)}')),
          ]);
        }).toList();

      case ReportType.claims:
        return _reportData.map((data) {
          final dueDate = data['dueDate'] as Timestamp?;
          return DataRow(cells: [
            DataCell(Text(data['claimNumber'].toString())),
            DataCell(Text(data['customerName'].toString().length > 15
                ? '${data['customerName'].toString().substring(0, 15)}...'
                : data['customerName'].toString())),
            DataCell(Text(data['type'].toString())),
            DataCell(
              Chip(
                label: Text(data['priority'].toString()),
                backgroundColor: _getPriorityColor(data['priority']).withOpacity(0.3),
                labelStyle: TextStyle(color: _getPriorityColor(data['priority'])),
              ),
            ),
            DataCell(
              Chip(
                label: Text(data['status']),
                backgroundColor: _getStatusColor(data['status']).withOpacity(0.3),
                labelStyle: TextStyle(color: _getStatusColor(data['status'])),
              ),
            ),
            DataCell(Text('R${(data['amount'] as double).toStringAsFixed(2)}')),
            DataCell(Text(dueDate != null ? DateFormat('MMM dd').format(dueDate.toDate()) : 'N/A')),
            DataCell(Text(data['resolution'].toString().length > 10
                ? '${data['resolution'].toString().substring(0, 10)}...'
                : data['resolution'].toString())),
          ]);
        }).toList();

      case ReportType.customers:
        return _reportData.map((data) {
          final lastDeliveryDate = data['lastDeliveryDate'] as DateTime?;
          return DataRow(cells: [
            DataCell(Text(data['name'].toString())),
            DataCell(Text(data['email'].toString().length > 20
                ? '${data['email'].toString().substring(0, 20)}...'
                : data['email'].toString())),
            DataCell(Text(data['phone'].toString())),
            DataCell(Text(data['city'].toString())),
            DataCell(Text(data['accountNumber'].toString())),
            DataCell(Text(data['deliveriesCount'].toString())),
            DataCell(Text(data['completedCount'].toString())),
            DataCell(Text('R${(data['totalAmount'] as double).toStringAsFixed(2)}')),
            DataCell(Text(lastDeliveryDate != null ? DateFormat('MMM dd').format(lastDeliveryDate) : 'Never')),
          ]);
        }).toList();

      case ReportType.pod:
        return _reportData.map((data) {
          final createdAt = data['createdAt'] as Timestamp?;
          return DataRow(cells: [
            DataCell(Text(data['deliveryId'].toString().substring(0, 8))),
            DataCell(Text(data['driverName'].toString().length > 12
                ? '${data['driverName'].toString().substring(0, 12)}...'
                : data['driverName'].toString())),
            DataCell(Text(data['customerName'].toString().length > 15
                ? '${data['customerName'].toString().substring(0, 15)}...'
                : data['customerName'].toString())),
            DataCell(Text(data['receiverName'].toString().length > 15
                ? '${data['receiverName'].toString().substring(0, 15)}...'
                : data['receiverName'].toString())),
            DataCell(Text(data['customerPhone'].toString())),
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
                message: data['fullNotes'] ?? data['notes'] ?? '',
                child: Text(data['notes'].toString().length > 10
                    ? '${data['notes'].toString().substring(0, 10)}...'
                    : data['notes'].toString()),
              ),
            ),
            DataCell(Text(data['itemCount'].toString())),
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
            DataCell(Text(createdAt != null ? DateFormat('MMM dd').format(createdAt.toDate()) : 'N/A')),
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
      case 'inTransit':
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
