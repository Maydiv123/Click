import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'camera_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'add_petrol_pump_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20.0),
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.person, size: 30, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Patrick',
                              style: TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            Text(
                              'Ford Transit Connect',
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Edit profile functionality
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Edit', style: TextStyle(color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFF35C2C1)),
              title: const Text('Map', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.black54),
              title: const Text('Chat', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: Colors.black54),
              title: const Text('Add Petrol Pump', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddPetrolPumpScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.black54),
              title: const Text('Special offers', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined, color: Colors.black54),
              title: const Text('Support', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.black54),
              title: const Text('Settings', style: TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: () {
                      // Logout logic
                      Navigator.pushReplacementNamed(context, '/welcome');
                    },
                    child: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 18, decoration: TextDecoration.underline)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Map Card
              _buildCard(
                context,
                'View Map',
                'Find petrol pumps near you',
                Icons.map,
                Colors.blue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Search Card
              _buildCard(
                context,
                'Search Petrol Pumps',
                'Search through all available petrol pumps',
                Icons.search,
                Colors.green,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Add Petrol Pump Card
              _buildCard(
                context,
                'Add Petrol Pump',
                'Request to add a new petrol pump',
                Icons.add_location,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddPetrolPumpScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}