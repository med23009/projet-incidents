import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../incidents/controllers/incident_controller.dart';
import '../../incidents/widgets/incident_card.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/network/connectivity_service.dart';
import '../../incidents/widgets/stats_overview_widget.dart';
import '../../incidents/widgets/user_stats_widget.dart';
import '../../incidents/services/stats_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IncidentController _incidentController = Get.find<IncidentController>();
  final AuthController _authController = Get.find<AuthController>();
  late final ConnectivityService _connectivityService = Get.find<ConnectivityService>();
  late final StatsService _statsService = Get.find<StatsService>();
  
  // Toggle between user-focused stats and sync-focused stats
  final RxBool _showUserStats = true.obs;
  
  @override
  void initState() {
    super.initState();
    _incidentController.loadIncidents();
    
    // Refresh statistics when screen loads
    _statsService.refreshStats();
    _statsService.fetchUserDashboardStats();
    
    // Verify if we need to prompt for biometric activation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricPrompt();
    });
  }
  
  void _checkBiometricPrompt() {
    if (_authController.shouldAskForBiometric.value) {
      _showBiometricEnableDialog();
    }
  }
  
  void _showBiometricEnableDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Enable biometrics?'),
        content: const Text(
          'Would you like to enable biometric authentication for faster, more secure logins in the future?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _authController.cancelBiometricEnabling();
              Get.back();
            },
            child: const Text('No, thanks'),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final success = await _authController.enableBiometricAuthentication();
              if (success) {
                Get.snackbar(
                  'Success',
                  'Biometric authentication enabled!',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 30),
            SizedBox(width: 8),
            Text('Incidents App', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Obx(() => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: _connectivityService.isConnected.value ? 'Online' : 'Offline',
              child: _connectivityService.isConnected.value
                ? const Icon(Icons.wifi, color: Colors.white)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white),
                      Container(
                        width: 20,
                        height: 2,
                        color: Colors.white,
                        transform: Matrix4.rotationZ(0.785398), // 45 degrés en radians
                      ),
                    ],
                  ),
            ),
          )),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _incidentController.loadIncidents();
              _statsService.refreshStats();
              _statsService.fetchUserDashboardStats();
              Get.snackbar(
                'Refresh', 
                'Data updated',
                snackPosition: SnackPosition.BOTTOM,
                duration: Duration(seconds: 2),
              );
            },
          ),
          PopupMenuButton(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 18, 
                color: Colors.white
              ),
            ),
            offset: Offset(0, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Theme.of(context).primaryColor, size: 20),
                    SizedBox(width: 12),
                    Text('My profile'),
                  ],
                ),
                onTap: () => Get.toNamed('/profile'),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.grey[700], size: 20),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
                onTap: () => Get.toNamed('/settings'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () => _authController.logout(),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _incidentController.loadIncidents();
          await _statsService.refreshAllStats();
        },
        child: Obx(() {
          if (_incidentController.isLoading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading data...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatsSection(),
              const SizedBox(height: 20),
              _buildQuickActionsBar(),
              const SizedBox(height: 24),
              _buildRecentIncidentsHeader(),
              const SizedBox(height: 12),
              if (_incidentController.incidents.isEmpty)
                _buildEmptyState()
              else
                ..._buildIncidentsList(),
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/incident/create'),
        tooltip: 'Report an incident',
        icon: const Icon(Icons.add),
        label: const Text('Report'),
        elevation: 4,
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(_showUserStats.value ? Icons.public : Icons.person, size: 18),
                          label: Text(_showUserStats.value ? 'Global' : 'Personal', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _toggleStatsView(),
              ),
            ],
          ),
          Divider(height: 24),
          Obx(() => _showUserStats.value
            ? UserStatsWidget()
            : StatsOverviewWidget(isCompact: true)
          ),
        ],
      ),
    );
  }
  
  // Toggle between different stats views
  void _toggleStatsView() {
    _showUserStats.value = !_showUserStats.value;
    
    // Refresh the appropriate stats when toggling
    if (_showUserStats.value) {
      _statsService.refreshUserDashboardStats();
    } else {
      _statsService.refreshStats();
      _statsService.fetchRemoteStats();
    }
  }
  
  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'Quick actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.add_circle,
                label: 'Report',
                color: Colors.blue,
                onTap: () => Get.toNamed('/incident/create'),
              ),
              _buildActionButton(
                icon: Icons.history,
                label: 'History',
                color: Colors.purple,
                onTap: () => Get.toNamed('/incidents'),
              ),
              Obx(() => _buildActionButton(
                icon: Icons.sync,
                label: 'Sync',
                color: Colors.green,
                badge: _statsService.pendingIncidents.value,
                onTap: () => _incidentController.syncIncidents(),
              )),
              _buildActionButton(
                icon: Icons.map,
                label: 'Map',
                color: Colors.orange,
                onTap: () => Get.toNamed('/map'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badge > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentIncidentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent incidents',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        TextButton(
          onPressed: () => Get.toNamed('/incidents'),
          child: Text('See all'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/empty_state.png',
            height: 120,
            width: 120,
          ),
          const SizedBox(height: 24),
          const Text(
            'No incidents reported',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use the "Report" button to add a new incident',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/incident/create'),
            icon: const Icon(Icons.add),
            label: const Text('Report an incident'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildIncidentsList() {
    // Only show the 5 most recent incidents on the home screen
    final recentIncidents = _incidentController.incidents.take(5).toList();
    
    return recentIncidents.map((incident) => 
      Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: IncidentCard(
          incident: incident,
          onTap: () => Get.toNamed(
            '/incident/details',
            arguments: incident,
          ),
        ),
      )
    ).toList();
  }
} 