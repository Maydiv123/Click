import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/custom_auth_service.dart';

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
  bool _isLoadingUserData = true;
  String? _errorMessage;
  String? _selectedTeamCode;
  List<Map<String, dynamic>> _availableTeams = [];
  Map<String, dynamic> _userData = {};
  bool _isAlreadyInTeam = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CustomAuthService _authService = CustomAuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _teamCodeController.addListener(() {
      if (_teamCodeController.text.trim().toUpperCase() != (_selectedTeamCode ?? '')) {
        setState(() {
          _selectedTeamCode = null;
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUserData = true;
    });
    
    try {
      final userData = await _authService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isAlreadyInTeam = userData['teamCode'] != null && userData['teamCode'].toString().isNotEmpty;
          _isLoadingUserData = false;
        });
        
        // Commented out fetching available teams since we're not showing the dropdown
        /*if (!_isAlreadyInTeam) {
          _fetchAvailableTeams();
        }*/
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
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
    final code = _teamCodeController.text.trim();
    if (code.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    
    try {
      // Debug print
      print('Searching for team with code: $code');
      
      // Try to find the team by exact code match first
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
        // If not found, try case-insensitive search
        final teamsSnapshot = await _firestore.collection('teams').get();
        bool found = false;
        
        for (final doc in teamsSnapshot.docs) {
          if (doc.id.toLowerCase() == code.toLowerCase() && doc.data()?['isDummy'] != true) {
            final teamData = doc.data();
            print('Team found with case-insensitive search: ${teamData['teamName']}');
            
            if (mounted) {
              setState(() {
                _selectedTeamCode = doc.id; // Use the actual case from the database
                _teamCodeController.text = doc.id; // Update the text field
                // Make sure this team is in the available teams list
                if (!_availableTeams.any((team) => team['code'] == doc.id)) {
                  _availableTeams.add({
                    'code': doc.id,
                    'name': teamData['teamName'] ?? 'Unnamed Team',
                  });
                }
              });
            }
            found = true;
            break;
          }
        }
        
        if (!found) {
          print('Team not found for code: $code');
          if (mounted) {
            setState(() {
              _errorMessage = 'No team found with code $code';
            });
          }
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
    
    // Use the selected team code if available, otherwise use the text input
    final teamCode = _selectedTeamCode ?? _teamCodeController.text.trim();
    
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
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw 'User not logged in.';
      
      final userDoc = await _firestore.collection('user_data').doc(userId).get();
      final userDataMap = userDoc.data() as Map<String, dynamic>?;
      
      // Check if the user is already in a team
      if (userDoc.exists && 
          userDataMap != null && 
          userDataMap['teamCode'] != null && 
          userDataMap['teamCode'].toString().isNotEmpty) {
        throw 'You are already in a team. Leave your current team to join another.';
      }
      
      // Get team document directly by ID (which is the team code)
      final teamDoc = await _firestore.collection('teams').doc(teamCode).get();
      final teamData = teamDoc.data();
      
      if (!teamDoc.exists || teamData == null || teamData['isDummy'] == true) {
        throw 'Invalid team code.';
      }
      
      // Get current user type
      final currentUserType = userDataMap != null ? userDataMap['userType'] : 'member';
      
      // Update user document - preserve leader status if they're already a leader
      await _firestore.collection('user_data').doc(userId).update({
        'teamCode': teamCode,
        'teamName': teamData['teamName'],
        'isTeamOwner': false,
        'teamMemberStatus': 'active',
        // Only change userType to 'member' if they're not already a leader
        'userType': currentUserType == 'leader' ? 'leader' : 'member',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update team document - add user to members array and increment counts
      await _firestore.collection('teams').doc(teamCode).update({
        'memberCount': FieldValue.increment(1),
        'activeMembers': FieldValue.increment(1),
        'members': FieldValue.arrayUnion([userId]), // Add user to members array
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

  Future<void> _leaveTeam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId == null) throw 'User not logged in.';
      
      final teamCode = _userData['teamCode'];
      if (teamCode == null) throw 'No team code found.';
      
      // Check if user is team owner
      if (_userData['isTeamOwner'] == true) {
        throw 'You are the team owner. Please transfer ownership before leaving.';
      }
      
      // Get current user type from userData
      final currentUserType = _userData['userType'];
      
      // Update user document - preserve leader status
      await _firestore.collection('user_data').doc(userId).update({
        'teamCode': null,
        'teamName': null,
        'isTeamOwner': false,
        'teamMemberStatus': null,
        // Only change userType to 'user' if they're not a leader
        'userType': currentUserType == 'leader' ? 'leader' : 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update team document
      await _firestore.collection('teams').doc(teamCode).update({
        'memberCount': FieldValue.increment(-1),
        'activeMembers': FieldValue.increment(-1),
        'members': FieldValue.arrayRemove([userId]), // Remove user from members array
      });
      
      // Reload user data
      await _loadUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully left the team!'), backgroundColor: Colors.green),
        );
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
          'Team Management',
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
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF35C2C1)))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _isAlreadyInTeam ? _buildCurrentTeamView() : _buildJoinTeamView(),
              ),
            ),
    );
  }

  Widget _buildCurrentTeamView() {
    final teamName = _userData['teamName'] ?? 'Your Team';
    final teamCode = _userData['teamCode'] ?? '';
    final isOwner = _userData['isTeamOwner'] == true;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Team',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You are currently a member of a team.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF35C2C1), const Color(0xFF35C2C1).withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOwner ? 'Team Owner' : 'Team Member',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Code',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          teamCode,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Team code copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (!isOwner) ...[
          const Text(
            'Leave Team',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'If you leave the team, you will need to be invited again to rejoin.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _leaveTeam,
              icon: const Icon(Icons.exit_to_app),
              label: const Text(
                'Leave Team',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ] else if (isOwner) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Team Owner Notice',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'As the team owner, you need to transfer ownership before you can leave the team.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
        if (_isLoading) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator(color: Color(0xFF35C2C1))),
        ],
      ],
    );
  }

  Widget _buildJoinTeamView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join a Team',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your team leader for the team code to join.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      child: CircularProgressIndicator(color: Color(0xFF35C2C1)),
                    ),
                  ),
                /* Team selection dropdown commented out as requested
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
                          decoration: InputDecoration(
                            labelText: 'Select Team',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            prefixIcon: const Icon(Icons.list, color: Color(0xFF35C2C1)),
                            filled: true,
                            fillColor: Colors.white,
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
                */
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _teamCodeController,
                        decoration: InputDecoration(
                          labelText: 'Enter your team code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          prefixIcon: const Icon(Icons.code, color: Color(0xFF35C2C1)),
                          filled: true,
                          fillColor: Colors.white,
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
                        backgroundColor: const Color(0xFF35C2C1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _joinTeam,
              icon: const Icon(Icons.group_add),
              label: const Text(
                'Join Team',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35C2C1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF35C2C1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF35C2C1).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF35C2C1), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Note',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF35C2C1),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You can only join one team at a time. If you need to switch teams, you\'ll need to leave your current team first.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF35C2C1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 