import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _trackingHistory = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadTrackingHistory();
  }
  
  Future<void> _loadTrackingHistory() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final history = await _databaseService.getDailyTrackingHistory(limit: 30);
      setState(() {
        _trackingHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tracking history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('EEEE, MMM d, yyyy').format(date);
  }
  
  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, h:mm a').format(date);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrackingHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trackingHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No travel history available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your daily travel distances will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _trackingHistory.length,
                  itemBuilder: (context, index) {
                    final tracking = _trackingHistory[index];
                    final distance = (tracking['distanceTraveled'] as num?)?.toDouble() ?? 0.0;
                    final date = tracking['date'] as Timestamp;
                    final firstLocation = tracking['firstLocation'] as Map<String, dynamic>;
                    final lastLocation = tracking['lastLocation'] as Map<String, dynamic>;
                    final checkpoints = tracking['checkpoints'] as List<dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.directions_car, color: Colors.blue),
                        ),
                        title: Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Distance: ${distance.toStringAsFixed(2)} km • Checkpoints: ${checkpoints.length}',
                        ),
                        trailing: Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  'Start Time',
                                  _formatDateTime(firstLocation['timestamp']),
                                  Icons.play_circle_outline,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Start Location',
                                  '${firstLocation['latitude'].toStringAsFixed(6)}, ${firstLocation['longitude'].toStringAsFixed(6)}',
                                  Icons.location_on_outlined,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'End Time',
                                  _formatDateTime(lastLocation['timestamp']),
                                  Icons.stop_circle_outlined,
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'End Location',
                                  '${lastLocation['latitude'].toStringAsFixed(6)}, ${lastLocation['longitude'].toStringAsFixed(6)}',
                                  Icons.location_on,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Checkpoints',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: checkpoints.length <= 1
                                      ? const Center(
                                          child: Text('Not enough checkpoints to display'),
                                        )
                                      : ListView.builder(
                                          itemCount: checkpoints.length,
                                          itemBuilder: (context, i) {
                                            final checkpoint = checkpoints[i] as Map<String, dynamic>;
                                            return ListTile(
                                              dense: true,
                                              leading: CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.blue,
                                                child: Text(
                                                  (i + 1).toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                '${checkpoint['latitude'].toStringAsFixed(6)}, ${checkpoint['longitude'].toStringAsFixed(6)}',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                              subtitle: Text(
                                                _formatDateTime(checkpoint['timestamp']),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // TODO: Implement view on map functionality
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('View on map functionality coming soon'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.map),
                                  label: const Text('View on Map'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
