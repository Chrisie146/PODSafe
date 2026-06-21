import 'package:flutter/material.dart';
import '../../utils/theme.dart';

/// Guided Tour Overlay
/// Shows an overlay with instructions for specific UI elements
class GuidedTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback? onComplete;
  final Widget child;

  const GuidedTourOverlay({
    super.key,
    required this.steps,
    this.onComplete,
    required this.child,
  });

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay> {
  int _currentStepIndex = 0;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    // Auto-show first step after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isVisible = true);
      }
    });
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() => _currentStepIndex++);
    } else {
      _completeTour();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
    }
  }

  void _completeTour() {
    setState(() => _isVisible = false);
    widget.onComplete?.call();
  }

  void _skipTour() {
    setState(() => _isVisible = false);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _currentStepIndex >= widget.steps.length) {
      return widget.child;
    }

    final currentStep = widget.steps[_currentStepIndex];

    return Stack(
      children: [
        // Main content with overlay
        widget.child,

        // Dark overlay
        Container(
          color: Colors.black.withValues(alpha: 179), // 0.7 opacity
        ),

        // Highlighted area (if target key is provided)
        if (currentStep.targetKey != null)
          _buildHighlight(currentStep),

        // Tour dialog
        _buildTourDialog(currentStep),
      ],
    );
  }

  Widget _buildHighlight(TourStep step) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _HighlightPainter(
          targetKey: step.targetKey!,
          highlightColor: AppTheme.primaryColor.withValues(alpha: 77), // 0.3 opacity
        ),
      ),
    );
  }

  Widget _buildTourDialog(TourStep step) {
    return Positioned(
      bottom: 100,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step ${_currentStepIndex + 1} of ${widget.steps.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _skipTour,
                    child: const Text('Skip Tour'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Title and description
              Text(
                step.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),

              const SizedBox(height: 12),

              Text(
                step.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
              ),

              // Custom content
              if (step.content != null) ...[
                const SizedBox(height: 16),
                step.content!,
              ],

              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                children: [
                  if (_currentStepIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentStepIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _currentStepIndex == widget.steps.length - 1
                            ? 'Got it!'
                            : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tour Step Model
class TourStep {
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final Widget? content;

  const TourStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.content,
  });
}

/// Highlight Painter
/// Paints a highlight around a target widget
class _HighlightPainter extends CustomPainter {
  final GlobalKey targetKey;
  final Color highlightColor;

  _HighlightPainter({
    required this.targetKey,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size targetSize = renderBox.size;

    // Create a path that covers the entire screen except the target area
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCenter(
        center: offset + Offset(targetSize.width / 2, targetSize.height / 2),
        width: targetSize.width + 20,
        height: targetSize.height + 20,
      ))
      ..fillType = PathFillType.evenOdd;

    final Paint paint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Predefined Tour Configurations
class TourConfigurations {
  static List<TourStep> getAdminDashboardTour() {
    return [
      TourStep(
        title: 'Welcome to Your Dashboard',
        description: 'This is your command center for managing deliveries, drivers, and operations. Let\'s take a quick tour of the key features.',
      ),
      TourStep(
        title: 'Quick Actions',
        description: 'Use these buttons to quickly create deliveries, register drivers, or import data from your systems.',
      ),
      TourStep(
        title: 'Analytics Overview',
        description: 'Monitor your delivery performance with real-time metrics and trends.',
      ),
      TourStep(
        title: 'Recent Activity',
        description: 'Stay updated with the latest deliveries, driver activities, and system notifications.',
      ),
      TourStep(
        title: 'Navigation Menu',
        description: 'Access all features through the menu. Settings, reports, and advanced tools are just a click away.',
      ),
    ];
  }

  static List<TourStep> getDriverDashboardTour() {
    return [
      TourStep(
        title: 'Your Driver Dashboard',
        description: 'Welcome! This is where you\'ll manage your deliveries and track your progress.',
      ),
      TourStep(
        title: 'Today\'s Deliveries',
        description: 'View all deliveries assigned to you for today. Tap on any delivery for details.',
      ),
      TourStep(
        title: 'Delivery Status',
        description: 'Update delivery status as you progress. Mark deliveries as "In Transit", "Delivered", etc.',
      ),
      TourStep(
        title: 'POD Collection',
        description: 'Capture proof of delivery with photos and signatures. This is required for most deliveries.',
      ),
      TourStep(
        title: 'Communication',
        description: 'Chat with your team and receive updates. Stay connected throughout your route.',
      ),
    ];
  }
}