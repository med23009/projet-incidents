import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/stats_service.dart';

class StatsOverviewWidget extends StatelessWidget {
  final StatsService statsService = Get.find<StatsService>();
  final bool isCompact;

  StatsOverviewWidget({Key? key, this.isCompact = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = statsService.isLoading.value;
      
      if (isLoading) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Incident Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => statsService.refreshStats(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Total',
                  statsService.totalIncidents.value.toString(),
                  Icons.assessment,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Synced',
                  statsService.syncedIncidents.value.toString(),
                  Icons.cloud_done,
                  Colors.green,
                ),
                _buildStatCard(
                  'Pending',
                  statsService.pendingIncidents.value.toString(),
                  Icons.cloud_upload,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSyncProgressIndicator(),
            const SizedBox(height: 20),
            if (statsService.incidentsByType.isNotEmpty) _buildIncidentTypeChart() else const SizedBox(),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildSyncProgressIndicator() {
    final syncRate = statsService.getSyncCompletionRate();
    final percentage = (syncRate * 100).toStringAsFixed(1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sync Progress',
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
                    widthFactor: syncRate,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
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

  Widget _buildIncidentTypeChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Incidents by Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...statsService.incidentsByType.entries.map((entry) {
          final type = entry.key;
          final count = entry.value;
          final total = statsService.totalIncidents.value;
          final percentage = total > 0 ? count / total : 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '$count (${(percentage * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getColorForIncidentType(type),
                  ),
                  minHeight: 8,
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Color _getColorForIncidentType(String type) {
    // Map incident types to colors
    final colors = {
      'Accident': Colors.red,
      'Near Miss': Colors.orange,
      'Hazard': Colors.yellow[800],
      'Damage': Colors.purple,
      'Injury': Colors.redAccent,
    };
    
    return colors[type] ?? Colors.blue;
  }
} 