import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/custom_auth_service.dart';

class TeamDetailsScreen extends StatefulWidget {
  final String teamCode;
  final String teamName;
  final Map<String, dynamic> userData;
  
  const TeamDetailsScreen({
    Key? key,
    required this.teamCode,
    required this.teamName,
    required this.userData,
  }) : super(key: key);
  
  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final UserService userService = UserService();
  final CustomAuthService _authService = CustomAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _teamMembers = [];
  String? _currentUserId;
  bool _isLoadingMembers = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
    _getCurrentUserId();
  }
  
  Future<void> _getCurrentUserId() async {
    try {
      final userId = await _authService.getCurrentUserId();
      print('Current user ID: $userId');
      setState(() {
        _currentUserId = userId;
      });
    } catch (e) {
      print('Error getting current user ID: $e');
    }
  }
  
  Future<void> _loadTeamMembers() async {
    setState(() {
      _isLoadingMembers = true;
    });
    
    try {
      print('Loading team members for team code: ${widget.teamCode}');
      
      // Query users in the user_data collection with matching team code
      final QuerySnapshot teamMembersSnapshot = await _firestore
          .collection('user_data')
          .where('teamCode', isEqualTo: widget.teamCode)
          .get();
      
      print('Found ${teamMembersSnapshot.docs.length} team members');
      
      final List<Map<String, dynamic>> members = [];
      
      for (var doc in teamMembersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        members.add({
          'id': doc.id,
          'firstName': data['firstName'] ?? '',
          'lastName': data['lastName'] ?? '',
          'isTeamOwner': data['isTeamOwner'] ?? false,
          'mobile': data['mobile'] ?? '',
        });
      }
      
      setState(() {
        _teamMembers = members;
        _isLoadingMembers = false;
      });
      
      print('Loaded ${members.length} team members');
    } catch (e) {
      print('Error loading team members: $e');
      setState(() {
        _isLoadingMembers = false;
        _errorMessage = 'Failed to load team members: $e';
      });
    }
  }
  
  Future<void> _leaveTeam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final userId = await _authService.getCurrentUserId();
      print('Attempting to leave team ${widget.teamCode} for user $userId');
      
      if (userId == null) {
        throw 'User not logged in';
      }
      
      // Get the current user data from Firestore
      print('Fetching user data from Firestore...');
      final userDoc = await _firestore.collection('user_data').doc(userId).get();
      print('User document exists: ${userDoc.exists}');
      
      if (!userDoc.exists) {
        throw 'User document not found in user_data collection';
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      print('User data received: $userData');
      
      // Verify team code matches
      final userTeamCode = userData['teamCode'];
      print('User team code: $userTeamCode, Widget team code: ${widget.teamCode}');
      
      if (userTeamCode != widget.teamCode) {
        throw 'Team code mismatch: User is in team $userTeamCode, but trying to leave team ${widget.teamCode}';
      }
      
      // Use direct Firestore update with transaction for safety
      print('Starting transaction to leave team...');
      await _firestore.runTransaction((transaction) async {
        // Re-read the user document to ensure it's up to date
        final freshUserDoc = await transaction.get(_firestore.collection('user_data').doc(userId));
        
        if (!freshUserDoc.exists) {
          throw 'User document disappeared during transaction';
        }
        
        final freshUserData = freshUserDoc.data() as Map<String, dynamic>;
        if (freshUserData['teamCode'] != widget.teamCode) {
          throw 'Team code changed during transaction';
        }
        
        // Update user document
        print('Updating user document to remove team association');
        transaction.update(_firestore.collection('user_data').doc(userId), {
          'teamCode': null,
          'teamName': null,
          'isTeamOwner': false,
          'teamMemberStatus': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update team document
        print('Updating team document to decrease member count');
        transaction.update(_firestore.collection('teams').doc(widget.teamCode), {
          'memberCount': FieldValue.increment(-1),
          'activeMembers': FieldValue.increment(-1),
        });
      });
      
      print('Successfully left team');
      
      // Update local user data with CustomAuthService
      final currentUserData = await _authService.getCurrentUserData();
      if (currentUserData.isNotEmpty) {
        await _authService.updateUserProfile(userId, {
          'teamCode': null,
          'teamName': null,
          'isTeamOwner': false,
          'teamMemberStatus': null,
        });
        print('Updated user profile in auth service');
      }
      
      Navigator.pop(context); // Go back to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the team'), backgroundColor: Colors.green)
      );
    } catch (e) {
      print('Error leaving team: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red)
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF35C2C1), const Color(0xFF35C2C1).withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
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
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.groups, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.teamName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.tag, color: Colors.white, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.teamCode,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    // TODO: Copy to clipboard
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Team code copied to clipboard')),
                                    );
                                  },
                                  child: const Icon(Icons.copy, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Team Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Team Members',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_teamMembers.length} members',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: _isLoadingMembers
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: Color(0xFF35C2C1)),
                    ),
                  )
                : _teamMembers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          'No team members found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _teamMembers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = _teamMembers[index];
                        final isCurrentUser = member['id'] == _currentUserId;
                        final isOwner = member['isTeamOwner'] == true;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOwner
                                ? const Color(0xFF35C2C1).withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              color: isOwner ? const Color(0xFF35C2C1) : Colors.grey,
                            ),
                          ),
                          title: Text(
                            '${member['firstName']} ${member['lastName']}${isCurrentUser ? ' (You)' : ''}',
                          ),
                          subtitle: Text(isOwner ? 'Team Owner' : 'Team Member'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Color(0xFF35C2C1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
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
            
            const SizedBox(height: 24),
            
            // Team Settings Section
            const Text(
              'Team Settingscd',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF35C2C1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit, color: Color(0xFF35C2C1)),
                    ),
                    title: const Text('Edit Team Profile'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Navigate to edit team profile screen
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF35C2C1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add, color: Color(0xFF35C2C1)),
                    ),
                    title: const Text('Invite Members'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Navigate to invite members screen
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout, color: Colors.red),
                    ),
                    title: const Text('Leave Team', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      // Show confirmation dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Leave Team'),
                          content: const Text('Are you sure you want to leave this team? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _leaveTeam();
                              },
                              child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.red,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Leave', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 