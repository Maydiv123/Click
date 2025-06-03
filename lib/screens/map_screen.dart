import 'package:flutter/material.dart';
import 'petrol_pump_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Start the animation to show the bottom panel
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Placeholder for the map
          Positioned.fill(
            child: Container(
              color: Colors.grey[300],
              child: Center(
                child: Text(
                  'Map View Placeholder',
                  style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                ),
              ),
            ),
          ),
          // Custom Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const Text(
                      'Map',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Panel (will be animated)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final double bottomPosition = MediaQuery.of(context).size.height * (1 - _animation.value);
              return Positioned(
                bottom: bottomPosition,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Petrol Pump Near By',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                // Edit functionality
                              },
                              icon: const Icon(Icons.edit, size: 18, color: Colors.black54),
                              label: const Text(
                                'Edit',
                                style: TextStyle(color: Colors.black54, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.location_pin, color: Colors.red),
                              title: const Text('Kings Cross Underground Statio...', style: TextStyle(color: Colors.black)),
                              subtitle: const Text('New York', style: TextStyle(color: Colors.grey)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PetrolPumpDetailsScreen(
                                      name: 'Kings Cross Underground Station',
                                      location: 'New York',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.location_pin, color: Colors.red),
                              title: const Text('83, Midwood St', style: TextStyle(color: Colors.black)),
                              subtitle: const Text('New York', style: TextStyle(color: Colors.grey)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PetrolPumpDetailsScreen(
                                      name: '83, Midwood St',
                                      location: 'New York',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.location_pin, color: Colors.red),
                              title: const Text('67, Grand Central Pkwy', style: TextStyle(color: Colors.black)),
                              subtitle: const Text('New York', style: TextStyle(color: Colors.grey)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PetrolPumpDetailsScreen(
                                      name: '67, Grand Central Pkwy',
                                      location: 'New York',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
} 