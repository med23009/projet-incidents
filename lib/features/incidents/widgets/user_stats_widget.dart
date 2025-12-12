import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/stats_service.dart';

class UserStatsWidget extends StatelessWidget {
  final StatsService _statsService = Get.find<StatsService>();
  final bool isCompact;
  
  UserStatsWidget({
    Key? key,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Show loading indicator if data is being loaded
      if (_statsService.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildStatusCards(context),
          const SizedBox(height: 20),
          _buildResolutionRateIndicator(context),
        ]),
      );
    });
  }
  
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Incident Status Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _statsService.refreshStats(),
          tooltip: 'Refresh status data',
        ),
      ],
    );
  }
  Widget _buildStatusCards(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatusCard(
          'Resolved',
          _statsService.resolvedIncidents.value.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatusCard(
          'In Progress',
          _statsService.inProgressIncidents.value.toString(),
          Icons.pending_actions,
          Colors.orange,
        ),
        _buildStatusCard(
          'Pending',
          _statsService.pendingStatusIncidents.value.toString(),
          Icons.hourglass_empty,
          Colors.red,
        ),
      ],
    );
  }
  
  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildResolutionRateIndicator(BuildContext context) {
    final resolutionRate = _statsService.resolutionRate.value;
    final percentage = (resolutionRate * 100).toStringAsFixed(1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resolution Rate',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: resolutionRate,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getResolutionRateColor(resolutionRate),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Color _getResolutionRateColor(double rate) {
    if (rate < 0.3) return Colors.red;
    if (rate < 0.7) return Colors.orange;
    return Colors.green;
  }
}