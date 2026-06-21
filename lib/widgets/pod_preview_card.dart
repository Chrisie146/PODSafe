import 'package:flutter/material.dart';
import '../../models/ocr_fields_model.dart';

/// Reusable card widget for previewing extracted OCR fields
/// Used in driver capture screen and admin review dashboard
class PodPreviewCard extends StatelessWidget {
  final OcrFields fields;
  final DetectionFlags? flags;
  final VoidCallback? onEdit;
  final bool isCompact; // For admin dashboard listing

  const PodPreviewCard({
    super.key,
    required this.fields,
    this.flags,
    this.onEdit,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactCard();
    }
    return _buildFullCard(context);
  }

  /// Full card for driver review screen
  Widget _buildFullCard(BuildContext context) {
    return Card(
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Invoice Details Extracted',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (flags != null && flags!.ocrConfident)
                  Tooltip(
                    message: 'High confidence extraction',
                    child: Icon(Icons.verified, color: Colors.green.shade600),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary fields
                _buildFieldRow(
                  'Invoice Number',
                  fields.invoiceNo ?? '(Not detected)',
                  Icons.receipt,
                  fields.invoiceNo != null,
                ),
                const SizedBox(height: 12),
                _buildFieldRow(
                  'Date',
                  fields.documentDate?.toString() ?? '(Not detected)',
                  Icons.calendar_today,
                  fields.documentDate != null,
                ),
                const SizedBox(height: 12),
                _buildFieldRow(
                  'Total Amount',
                  fields.totalIncl != null
                      ? 'R${fields.totalIncl!.toStringAsFixed(2)}'
                      : '(Not detected)',
                  Icons.attach_money,
                  fields.totalIncl != null,
                ),
                const SizedBox(height: 12),
                _buildFieldRow(
                  'Tax Amount',
                  fields.totalVat != null
                      ? 'R${fields.totalVat!.toStringAsFixed(2)}'
                      : '(Not detected)',
                  Icons.percent,
                  fields.totalVat != null,
                ),

                const Divider(height: 24),

                // Secondary fields
                Text(
                  'Additional Information',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFieldRow(
                  'Supplier',
                  fields.supplier ?? '(Not detected)',
                  Icons.business,
                  fields.supplier != null,
                ),
                const SizedBox(height: 8),
                _buildFieldRow(
                  'Customer',
                  fields.customer ?? '(Not detected)',
                  Icons.person,
                  fields.customer != null,
                ),
                const SizedBox(height: 8),
                _buildFieldRow(
                  'Branch/Site',
                  fields.branch ?? '(Not detected)',
                  Icons.location_on,
                  fields.branch != null,
                ),
                const SizedBox(height: 8),
                _buildFieldRow(
                  'Vehicle Registration',
                  fields.truckReg ?? '(Not detected)',
                  Icons.directions_car,
                  fields.truckReg != null,
                ),
                const SizedBox(height: 8),
                _buildFieldRow(
                  'Driver Name',
                  fields.driverName ?? '(Not detected)',
                  Icons.badge,
                  fields.driverName != null,
                ),

                if (fields.totalQty != null || fields.totalMassKg != null) ...[
                  const Divider(height: 24),
                  Text(
                    'Delivery Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (fields.totalQty != null)
                    _buildFieldRow(
                      'Quantity',
                      '${fields.totalQty} items',
                      Icons.inventory_2,
                      true,
                    ),
                  if (fields.totalMassKg != null) ...[
                    const SizedBox(height: 8),
                    _buildFieldRow(
                      'Total Weight',
                      '${fields.totalMassKg!.toStringAsFixed(2)} kg',
                      Icons.scale,
                      true,
                    ),
                  ],
                ],

                // Quality indicators
                if (flags != null) ...[
                  const Divider(height: 24),
                  _buildQualityIndicators(),
                ],

                // Warnings
                if (fields.ocrRawText?.contains('warning') == true) ...[
                  const SizedBox(height: 16),
                  _buildWarningsBox(),
                ],
              ],
            ),
          ),

          // Action buttons
          if (onEdit != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Compact card for admin dashboard listing
  Widget _buildCompactCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fields.invoiceNo ?? 'Invoice #',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fields.supplier ?? 'Unknown Supplier',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (flags != null && flags!.ocrConfident)
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fields.totalIncl != null
                      ? 'R${fields.totalIncl!.toStringAsFixed(2)}'
                      : 'R0.00',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  fields.documentDate?.toString() ?? 'Date N/A',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Individual field row
  Widget _buildFieldRow(
    String label,
    String value,
    IconData icon,
    bool detected,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: detected ? Colors.blue.shade700 : Colors.grey.shade400,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: detected ? FontWeight.w500 : FontWeight.normal,
                  color: detected ? Colors.black : Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Quality indicators box
  Widget _buildQualityIndicators() {
    if (flags == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extraction Quality',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQualityMetric(
                  'Confidence',
                  '${(flags!.ocrConfidenceScore * 100).toStringAsFixed(0)}%',
                  flags!.ocrConfidenceScore >= 0.85,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQualityMetric(
                  'Signature',
                  flags!.hasSignature ? 'Yes' : 'No',
                  flags!.hasSignature,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQualityMetric(
                  'Stamp',
                  flags!.hasStamp ? 'Yes' : 'No',
                  flags!.hasStamp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Quality metric chip
  Widget _buildQualityMetric(String label, String value, bool isGood) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              isGood ? Icons.check_circle : Icons.info,
              size: 12,
              color: isGood ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Warnings box
  Widget _buildWarningsBox() {
    if (fields.ocrRawText == null) return const SizedBox.shrink();

    final warnings = <String>[];
    if (fields.invoiceNo == null) warnings.add('Invoice number missing');
    if (fields.totalIncl == null) warnings.add('Total amount not found');
    if (fields.documentDate == null) warnings.add('Date not detected');
    if (fields.supplier == null) warnings.add('Supplier name missing');

    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Review Recommended',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.circle, size: 4, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  warning,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
