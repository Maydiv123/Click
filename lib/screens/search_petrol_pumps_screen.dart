import 'package:flutter/material.dart';
import 'petrol_pump_details_screen.dart';

class SearchPetrolPumpsScreen extends StatefulWidget {
  const SearchPetrolPumpsScreen({Key? key}) : super(key: key);

  @override
  State<SearchPetrolPumpsScreen> createState() => _SearchPetrolPumpsScreenState();
}

class _SearchPetrolPumpsScreenState extends State<SearchPetrolPumpsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _petrolPumps = [
    {
      'name': 'Kings Cross Underground Station',
      'location': 'New York',
    },
    {
      'name': '83, Midwood St',
      'location': 'New York',
    },
    {
      'name': '67, Grand Central Pkwy',
      'location': 'New York',
    },
    {
      'name': 'Shell Gas Station',
      'location': 'Brooklyn',
    },
    {
      'name': 'BP Express',
      'location': 'Queens',
    },
  ];
  List<Map<String, String>> _filteredPumps = [];

  @override
  void initState() {
    super.initState();
    _filteredPumps = List.from(_petrolPumps);
  }

  void _filterPumps(String query) {
    setState(() {
      _filteredPumps = _petrolPumps
          .where((pump) =>
              pump['name']!.toLowerCase().contains(query.toLowerCase()) ||
              pump['location']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Petrol Pumps'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or location',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterPumps,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredPumps.length,
              itemBuilder: (context, index) {
                final pump = _filteredPumps[index];
                return ListTile(
                  leading: const Icon(Icons.local_gas_station, color: Colors.red),
                  title: Text(pump['name']!),
                  subtitle: Text(pump['location']!),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetrolPumpDetailsScreen(
                          name: pump['name']!,
                          location: pump['location']!,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 