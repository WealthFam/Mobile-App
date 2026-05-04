import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/modules/home/services/dashboard_service.dart';
import 'package:provider/provider.dart';

class SpendingHeatmapWidget extends StatefulWidget {
  const SpendingHeatmapWidget({super.key});

  @override
  State<SpendingHeatmapWidget> createState() => _SpendingHeatmapWidgetState();
}

class _SpendingHeatmapWidgetState extends State<SpendingHeatmapWidget> {
  List<dynamic> _heatmapData = [];
  List<WeightedLatLng> _weightedPoints = [];
  bool _isLoading = true;
  String? _error;
  final MapController _mapController = MapController();
  final StreamController<void> _rebuildStream = StreamController.broadcast();
  DashboardService? _dashboard;

  static final Map<double, MaterialColor> _heatGradient = {
    0.25: Colors.blue,
    0.55: Colors.green,
    0.85: Colors.orange,
    1.00: Colors.red,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dashboard = context.read<DashboardService>();
      _dashboard?.addListener(_fetchHeatmapData);
      _fetchHeatmapData();
    });
  }

  @override
  void dispose() {
    _dashboard?.removeListener(_fetchHeatmapData);
    _rebuildStream.close();
    super.dispose();
  }

  Future<void> _fetchHeatmapData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final dashboard = _dashboard;
    if (dashboard == null) return;

    final result = await dashboard.fetchGeographicalHeatmap(
      month: dashboard.selectedMonth,
      year: dashboard.selectedYear,
      memberId: dashboard.selectedMemberId,
    );

    if (mounted) {
      result.fold(
        (failure) {
          setState(() {
            _error = failure.message;
            _isLoading = false;
          });
        },
        (data) {
          // Calculate scale factor using 90th percentile for better visualization
          final amounts = data
              .map((p) => (p['amount'] as num).toDouble())
              .where((a) => a > 0)
              .toList()
            ..sort();
          
          double scaleMax = 1.0;
          if (amounts.isNotEmpty) {
            final idx = (amounts.length * 0.9).floor();
            scaleMax = amounts[idx < amounts.length ? idx : amounts.length - 1];
            if (scaleMax < 0.01) scaleMax = 0.01;
          }

          final weighted = data.map((pRaw) {
            final p = pRaw as Map<String, dynamic>;
            final lat = (p['latitude'] as num).toDouble();
            final lng = (p['longitude'] as num).toDouble();
            final amt = (p['amount'] as num).toDouble();
            
            final weight = (amt / scaleMax).clamp(0.1, 1.0);
            return WeightedLatLng(LatLng(lat, lng), weight);
          }).toList();

          setState(() {
            _heatmapData = data;
            _weightedPoints = weighted;
            _isLoading = false;
          });

          if (weighted.isNotEmpty) {
            _rebuildStream.add(null);
            _fitMapBounds();
          }
        },
      );
    }
  }

  void _fitMapBounds() {
    if (_heatmapData.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_heatmapData.length == 1) {
        final p = _heatmapData[0] as Map<String, dynamic>;
        _mapController.move(
          LatLng(
            (p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble(),
          ),
          14,
        );
      } else {
        final points = _heatmapData
            .map(
              (pRaw) {
                final p = pRaw as Map<String, dynamic>;
                return LatLng(
                  (p['latitude'] as num).toDouble(),
                  (p['longitude'] as num).toDouble(),
                );
              },
            )
            .toList();

        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = context.read<DashboardService>().currencySymbol;

    return Container(
      height: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          // Map layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.5937, 78.9629),
              initialZoom: 5,
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 19,
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'com.wealthfam.mobile',
              ),
              if (_weightedPoints.isNotEmpty)
                HeatMapLayer(
                  heatMapDataSource: InMemoryHeatMapDataSource(
                    data: _weightedPoints,
                  ),
                  heatMapOptions: HeatMapOptions(
                    gradient: _heatGradient,
                    layerOpacity: 0.7,
                    radius: 30,
                    blurFactor: 15,
                  ),
                  reset: _rebuildStream.stream,
                ),
              if (_heatmapData.isNotEmpty)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 45,
                    size: const Size(40, 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    markers: _heatmapData.map((pRaw) {
                      final p = pRaw as Map<String, dynamic>;
                      final lat = (p['latitude'] as num).toDouble();
                      final lng = (p['longitude'] as num).toDouble();
                      final amount = (p['amount'] as num).toDouble();
                      final category = (p['category'] ?? 'Expense') as String;
                      final desc = (p['description'] ?? '') as String;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 32,
                        height: 32,
                        child: _buildThematicMarker(
                          context,
                          category,
                          amount,
                          desc,
                          currency,
                        ),
                      );
                    }).toList(),
                    builder: (context, markers) {
                      return _buildClusterMarker(context, markers.length);
                    },
                  ),
                ),
            ],
          ),

          // Overlays
          _buildStatsOverlay(context),
          _buildModernLegend(context),

          // Loading overlay
          if (_isLoading)
            Container(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // Error/Empty state overlay
          if (!_isLoading && (_error != null || _heatmapData.isEmpty))
            Container(
              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _error != null ? '⚠️' : '📍',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error ?? 'No spending locations found for this period',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      if (_error != null)
                        TextButton(
                          onPressed: _fetchHeatmapData,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThematicMarker(
    BuildContext context,
    String category,
    double amount,
    String desc,
    String currency,
  ) {
    final theme = Theme.of(context);
    final icon = _getCategoryEmoji(category);

    return GestureDetector(
      onTap: () => _showTransactionDetail(context, category, amount, desc, currency),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Text(
            icon,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildClusterMarker(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.secondary.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverlay(BuildContext context) {
    final theme = Theme.of(context);
    if (_heatmapData.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore, size: 14, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              '${_heatmapData.length} Locations Tracking',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLegend(BuildContext context) {
    final theme = Theme.of(context);
    if (_heatmapData.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Text(
              'Intensity',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.layers_outlined, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('food')) return '🍔';
    if (lower.contains('shopping')) return '🛍️';
    if (lower.contains('travel')) return '✈️';
    if (lower.contains('health')) return '💊';
    if (lower.contains('home')) return '🏠';
    if (lower.contains('entertainment')) return '🎬';
    if (lower.contains('fuel')) return '⛽';
    if (lower.contains('grocery')) return '🛒';
    return '💰';
  }

  void _showTransactionDetail(
    BuildContext context,
    String category,
    double amount,
    String description,
    String currency,
  ) {
    final maskingFactor = context.read<DashboardService>().maskingFactor;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.location_on, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '$currency${(amount / maskingFactor).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
