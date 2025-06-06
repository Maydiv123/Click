import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({Key? key}) : super(key: key);

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String? _selectedTeamCode;
  List<Map<String, dynamic>> _availableTeams = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchAvailableTeams();
    _teamCodeController.addListener(() {
      if (_teamCodeController.text.trim().toUpperCase() != (_selectedTeamCode ?? '')) {
        setState(() {
          _selectedTeamCode = null;
        });
      }
    });
  }

  Future<void> _fetchAvailableTeams() async {
    setState(() {
      _isSearching = true;
    });
    try {
      // Debug print to verify query execution
      print('Fetching teams from Firestore...');
      
      final teams = await _firestore.collection('teams').get();
      
      // Debug print to check results
      print('Teams found: ${teams.docs.length}');
      
      final List<Map<String, dynamic>> teamsData = [];
      
      for (var doc in teams.docs) {
        // Skip dummy documents
        if (doc.data()['isDummy'] == true) continue;
        
        final teamData = doc.data();
        // Debug each team
        print('Team: ${teamData['teamName']} - Code: ${doc.id}');
        
        teamsData.add({
          'code': doc.id,
          'name': teamData['teamName'] ?? 'Unnamed Team',
        });
      }
      
      if (mounted) {
        setState(() {
          _availableTeams = teamsData;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error fetching teams: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Failed to load teams: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _searchTeamByCode() async {
    final code = _teamCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    
    try {
      // Debug print
      print('Searching for team with code: $code');
      
      final teamDoc = await _firestore.collection('teams').doc(code).get();
      
      if (teamDoc.exists && teamDoc.data()?['isDummy'] != true) {
        final teamData = teamDoc.data()!;
        print('Team found: ${teamData['teamName']}');
        
        if (mounted) {
          setState(() {
            _selectedTeamCode = code;
            // Make sure this team is in the available teams list
            if (!_availableTeams.any((team) => team['code'] == code)) {
              _availableTeams.add({
                'code': code,
                'name': teamData['teamName'] ?? 'Unnamed Team',
              });
            }
          });
        }
      } else {
        print('Team not found for code: $code');
        if (mounted) {
          setState(() {
            _errorMessage = 'No team found with code $code';
          });
        }
      }
    } catch (e) {
      print('Error searching team: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error searching team: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _joinTeam() async {
    if (!_formKey.currentState!.validate()) return;
    
    final teamCode = _teamCodeController.text.trim().toUpperCase();
    
    // First search for the team if it's not already selected
    if (_selectedTeamCode == null) {
      await _searchTeamByCode();
      // If still no team found after search, stop
      if (_selectedTeamCode == null) {
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not logged in.';
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      
      // Check if the user is already in a team
      if (userDoc.exists && 
          userData != null && 
          userData['teamCode'] != null && 
          userData['teamCode'].toString().isNotEmpty) {
        throw 'You are already in a team. Leave your current team to join another.';
      }
      
      // Get team document directly by ID (which is the team code)
      final teamDoc = await _firestore.collection('teams').doc(teamCode).get();
      final teamData = teamDoc.data();
      
      if (!teamDoc.exists || teamData == null || teamData['isDummy'] == true) {
        throw 'Invalid team code.';
      }
      
      // Update user document
      await _firestore.collection('users').doc(user.uid).update({
        'teamCode': teamCode,
        'teamName': teamData['teamName'],
        'isTeamOwner': false,
        'teamMemberStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update team document
      await _firestore.collection('teams').doc(teamCode).update({
        'memberCount': FieldValue.increment(1),
        'activeMembers': FieldValue.increment(1),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the team!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _teamCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Join Team',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter or Select Team Code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask your team leader for the team code or select from the list.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.group,
                        size: 50,
                        color: Color(0xFF35C2C1),
                      ),
                      const SizedBox(height: 16),
                      if (_isSearching)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        _availableTeams.isEmpty
                            ? Center(
                                child: Text(
                                  'No teams available. You can create one or enter a team code.',
                                  style: TextStyle(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedTeamCode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Select Team',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.list),
                                ),
                                items: _availableTeams.map((team) {
                                  return DropdownMenuItem<String>(
                                    value: team['code'] as String,
                                    child: Text('${team['name']} (${team['code']})'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTeamCode = value;
                                    _teamCodeController.text = value ?? '';
                                    _errorMessage = null;
                                  });
                                },
                                hint: const Text('Select a team'),
                                validator: (value) {
                                  return null; // No validation here, handled by text field
                                },
                              ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _teamCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Team Code',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.code),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter team code';
                                }
                                if (value.length < 6) {
                                  return 'Team code must be at least 6 characters';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (value.trim().toUpperCase() != (_selectedTeamCode ?? '')) {
                                  setState(() {
                                    _selectedTeamCode = null;
                                    _errorMessage = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isSearching ? null : _searchTeamByCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _joinTeam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Join Team',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Note: You can only join one team at a time.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 