import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../models/permission.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../widgets/permission_guard.dart';
import '../../widgets/analytics_map_widget.dart';
import 'analytics_dashboard_desktop.dart';

/// Analytics Dashboard - Protected by permission guard
/// Only users with analyticsView permission can access this screen
class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap entire screen with permission check
    return PermissionBuilder(
      permission: Permission.analyticsView,
      builder: (context, hasAccess) {
        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Analytics'),
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You don\'t have permission to view analytics',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        
        return LayoutBuilder(
          builder: (context, constraints) {
            // Desktop: Width > 1000px
            // Mobile: Width <= 1000px
            if (constraints.maxWidth > 1000) {
              return const AnalyticsDashboardDesktop();
            }
            return const AnalyticsDashboardMobile();
          },
        );
      },
    );
  }
}

class AnalyticsDashboardMobile extends StatefulWidget {
  const AnalyticsDashboardMobile({super.key});

  @override
  State<AnalyticsDashboardMobile> createState() => _AnalyticsDashboardMobileState();
}

class _AnalyticsDashboardMobileState extends State<AnalyticsDashboardMobile> {
  String _selectedPeriod = 'week'; // week, month, year
  bool _isLoading = true;
  
  // Analytics data
  int _totalDeliveries = 0;
  int _completedDeliveries = 0;
  int _activeDeliveries = 0;
  int _totalDrivers = 0;
  int _activeDrivers = 0;
  double _completionRate = 0.0;
  
  Map<String, int> _dailyDeliveries = {};
  Map<String, int> _deliveriesByStatus = {};
  List<Map<String, dynamic>> _topDrivers = [];
  List<Map<String, dynamic>> _locationData = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadDeliveryStats(),
        _loadDriverStats(),
        _loadDailyDeliveries(),
        _loadTopDrivers(),
        _loadLocationData(),
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
      debugPrint('⚠️ No companyId found for analytics');
      return;
    }

    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .get();

    int total = deliveriesSnapshot.docs.length;
    int completed = 0;
    int active = 0;

    Map<String, int> statusCount = {};

    for (var doc in deliveriesSnapshot.docs) {
      final status = doc.data()['status'] as String?;
      if (status != null) {
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        if (status == 'delivered') {
          completed++;
        } else if (status == 'inTransit') {
          active++;
        }
      }
    }

    setState(() {
      _totalDeliveries = total;
      _completedDeliveries = completed;
      _activeDeliveries = active;
      _completionRate = total > 0 ? (completed / total) * 100 : 0.0;
      _deliveriesByStatus = statusCount;
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

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'year':
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    final deliveriesSnapshot = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
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

    // Get top 5 drivers
    var sortedDrivers = driverDeliveries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    List<Map<String, dynamic>> topDriversList = [];

    for (var entry in sortedDrivers.take(5)) {
      try {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(entry.key)
            .get();
        
        if (driverDoc.exists) {
          topDriversList.add({
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

  Future<void> _loadLocationData() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final companyId = authProvider.companyId;

    if (companyId == null || companyId.isEmpty) {
      return;
    }

    List<Map<String, dynamic>> locations = [];

    try {
      // Load POD locations
      final podsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('pods')
          .get();

      for (var doc in podsSnapshot.docs) {
        final location = doc.data()['location'] as Map<String, dynamic>?;
        if (location != null && location['latitude'] != null && location['longitude'] != null) {
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
          
          locations.add({
            'latitude': (location['latitude'] as num).toDouble(),
            'longitude': (location['longitude'] as num).toDouble(),
            'type': 'pod',
            'id': doc.id,
            'customerName': doc.data()['customerName'] ?? 'Unknown',
            'invoiceNumber': doc.data()['invoiceNumber'] ?? 'N/A',
            'status': doc.data()['status'] ?? 'pending',
            'deliveryId': doc.data()['deliveryId'] ?? '',
            'vehicleInfo': vehicleInfo,
          });
        }
      }

      // Load Claim locations (uses gpsLocation field)
      final claimsSnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('claims')
          .get();

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
          
          locations.add({
            'latitude': (gpsLocation['latitude'] as num).toDouble(),
            'longitude': (gpsLocation['longitude'] as num).toDouble(),
            'type': 'claim',
            'id': doc.id,
            'title': doc.data()['title'] ?? 'Claim',
            'customerName': doc.data()['customerName'] ?? 'Unknown',
            'customerAccountNumber': doc.data()['customerAccountNumber'] ?? 'N/A',
            'customerId': doc.data()['customerId'] ?? '',
            'driverName': doc.data()['driverName'] ?? 'Unknown',
            'invoiceNumber': doc.data()['invoiceNumber'] ?? 'N/A',
            'podId': podId,
            'podInfo': podInfo,
            'claimAmount': doc.data()['claimAmount'] ?? 0.0,
            'vehicleInfo': vehicleInfo,
          });
        }
      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    _buildPeriodSelector(),
                    const SizedBox(height: 20),

                    // Overview Stats
                    const Text(
                      'Overview',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewStats(),
                    const SizedBox(height: 24),

                    // Delivery Trend Chart
                    const Text(
                      'Delivery Trend',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 12),
                    _buildDeliveryTrendChart(),
                    const SizedBox(height: 24),

                    // Delivery Locations Map - MOVED UP FOR VISIBILITY
                    const Text(
                      'Delivery Locations',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Locations loaded: ${_locationData.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AnalyticsMapWidget(
                          locations: _locationData,
                          height: 300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Distribution
                    const Text(
                      'Status Distribution',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusDistribution(),
                    const SizedBox(height: 24),

                    // Top Performers
                    const Text(
                      'Top Performing Drivers',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 12),
                    _buildTopDrivers(),
                    const SizedBox(height: 24),

                    // Driver Stats
                    const Text(
                      'Driver Statistics',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: 12),
                    _buildDriverStats(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20),
            const SizedBox(width: 12),
            const Text('Period:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Week')),
                  ButtonSegment(value: 'month', label: Text('Month')),
                  ButtonSegment(value: 'year', label: Text('Year')),
                ],
                selected: {_selectedPeriod},
                onSelectionChanged: (Set<String> selection) {
                  setState(() {
                    _selectedPeriod = selection.first;
                  });
                  _loadDailyDeliveries();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid: more columns on wider screens
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth > 800 ? 2.0 : 1.8;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: [
        _buildStatCard(
          'Total Deliveries',
          _totalDeliveries.toString(),
          Icons.local_shipping,
          AppTheme.primaryColor,
        ),
        _buildStatCard(
          'Completed',
          _completedDeliveries.toString(),
          Icons.check_circle,
          AppTheme.successColor,
        ),
        _buildStatCard(
          'In Transit',
          _activeDeliveries.toString(),
          Icons.pending_actions,
          AppTheme.infoColor,
        ),
        _buildStatCard(
          'Completion Rate',
          '${_completionRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          AppTheme.successColor,
        ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTrendChart() {
    if (_dailyDeliveries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.show_chart, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text(
                  'No delivery data available',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final entries = _dailyDeliveries.entries.toList();
    final maxValue = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxValue > 5 ? maxValue / 5 : 1,
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: entries.length > 10 ? 2 : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < entries.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            entries[index].key,
                            style: const TextStyle(fontSize: 10),
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
                    reservedSize: 35,
                    interval: maxValue > 5 ? maxValue / 5 : 1,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: entries.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value.value.toDouble());
                  }).toList(),
                  isCurved: true,
                  color: AppTheme.primaryColor,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryColor.withValues(alpha: 26),
                  ),
                ),
              ],
              minY: 0,
              maxY: maxValue + 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDistribution() {
    if (_deliveriesByStatus.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.pie_chart, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text(
                  'No status data available',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final total = _deliveriesByStatus.values.reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _deliveriesByStatus.entries.map((entry) {
            final percentage = (entry.value / total * 100).toStringAsFixed(1);
            final color = _getStatusColor(entry.key);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                          Text(
                            _formatStatus(entry.key),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        '${entry.value} ($percentage%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: entry.value / total,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopDrivers() {
    if (_topDrivers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                const Text(
                  'No driver performance data yet',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: _topDrivers.asMap().entries.map((entry) {
          final index = entry.key;
          final driver = entry.value;
          final isTop = index == 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isTop
                  ? AppTheme.successColor.withValues(alpha: 51)
                  : AppTheme.primaryColor.withValues(alpha: 26),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isTop ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
            ),
            title: Text(
              driver['name'],
              style: TextStyle(
                fontWeight: isTop ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTop
                    ? AppTheme.successColor
                    : AppTheme.primaryColor.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${driver['deliveries']} deliveries',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isTop ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDriverStats() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.people,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _totalDrivers.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Text(
                    'Total Drivers',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeDrivers.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const Text(
                    'Active Drivers',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warningColor;
      case 'inTransit':
        return AppTheme.infoColor;
      case 'delivered':
        return AppTheme.successColor;
      case 'failed':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'inTransit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}
