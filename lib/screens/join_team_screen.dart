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
    final teams = await _firestore.collection('teams').get();
    setState(() {
      _availableTeams = teams.docs.map((doc) => {
        'code': doc['teamCode'] ?? '',
        'name': doc['teamName'] ?? '',
      }).toList();
    });
  }

  Future<void> _joinTeam() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not logged in.';
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc['teamCode'] != null && userDoc['teamCode'].toString().isNotEmpty) {
        throw 'You are already in a team. Leave your current team to join another.';
      }
      final teamCode = _teamCodeController.text.trim().toUpperCase();
      final teamQuery = await _firestore
          .collection('teams')
          .where('teamCode', isEqualTo: teamCode)
          .limit(1)
          .get();
      if (teamQuery.docs.isEmpty) throw 'Invalid team code.';
      final teamDoc = teamQuery.docs.first;
      await _firestore.collection('users').doc(user.uid).update({
        'teamCode': teamCode,
        'teamName': teamDoc['teamName'],
        'isTeamOwner': false,
        'teamMemberStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('teams').doc(teamDoc.id).update({
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
                      DropdownButtonFormField<String>(
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
                          });
                        },
                        hint: const Text('Select a team'),
                        validator: (value) {
                          return null; // No validation here, handled by text field
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
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
                            });
                          }
                        },
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