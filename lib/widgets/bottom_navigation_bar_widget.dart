import 'package:flutter/material.dart';
import '../screens/openstreet_map_screen.dart';
import '../screens/search_petrol_pumps_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/nearest_petrol_pumps_screen.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool showFloatingActionButton;
  final VoidCallback? onFloatingActionButtonPressed;
  final IconData? floatingActionButtonIcon;
  final String? floatingActionButtonTooltip;
  final Color? floatingActionButtonColor;

  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.showFloatingActionButton = false,
    this.onFloatingActionButtonPressed,
    this.floatingActionButtonIcon,
    this.floatingActionButtonTooltip,
    this.floatingActionButtonColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_outlined, 'Home'),
            _buildNavItem(1, Icons.map_outlined, 'Map'),
            if (showFloatingActionButton) 
              const SizedBox(width: 40) // Space for FAB
            else
              const SizedBox(width: 0),
            _buildNavItem(3, Icons.search, 'Search'),
            _buildNavItem(4, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    return InkWell(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: currentIndex == index ? const Color(0xFF35C2C1) : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: currentIndex == index ? const Color(0xFF35C2C1) : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to provide navigation logic for different screens
extension NavigationHelper on BuildContext {
  void navigateFromBottomNav(int index, String currentScreen) {
    switch (index) {
      case 0: // Home
        if (currentScreen != 'home') {
          Navigator.pushReplacementNamed(this, '/home');
        }
        break;
      case 1: // Map
        if (currentScreen != 'map') {
          Navigator.pushReplacement(
            this,
            MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
          );
        }
        break;
      case 3: // Search
        if (currentScreen != 'search') {
          Navigator.pushReplacement(
            this,
            MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
          );
        }
        break;
      case 4: // Profile
        if (currentScreen != 'profile') {
          Navigator.pushReplacementNamed(this, '/profile');
        }
        break;
    }
  }
}

// Helper class to create a complete scaffold with bottom navigation
class ScaffoldWithBottomNav extends StatelessWidget {
  final String currentScreen;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? floatingActionButtonColor;
  final IconData? floatingActionButtonIcon;
  final String? floatingActionButtonTooltip;
  final VoidCallback? onFloatingActionButtonPressed;

  const ScaffoldWithBottomNav({
    Key? key,
    required this.currentScreen,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonColor,
    this.floatingActionButtonIcon,
    this.floatingActionButtonTooltip,
    this.onFloatingActionButtonPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int currentIndex = _getCurrentIndex();
    final bool showFAB = floatingActionButton != null || onFloatingActionButtonPressed != null;

    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton ?? (onFloatingActionButtonPressed != null
          ? FloatingActionButton(
              onPressed: onFloatingActionButtonPressed!,
              backgroundColor: floatingActionButtonColor ?? const Color(0xFF35C2C1),
              child: Icon(
                floatingActionButtonIcon ?? Icons.add,
                color: Colors.white,
              ),
              tooltip: floatingActionButtonTooltip,
            )
          : null),
      floatingActionButtonLocation: floatingActionButtonLocation ?? FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _handleNavigation(context, index),
        showFloatingActionButton: showFAB,
      ),
    );
  }

  int _getCurrentIndex() {
    switch (currentScreen) {
      case 'home':
        return 0;
      case 'map':
        return 1;
      case 'search':
        return 3;
      case 'profile':
        return 4;
      default:
        return 0;
    }
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0: // Home
        if (currentScreen != 'home') {
          Navigator.pushReplacementNamed(context, '/home');
        }
        break;
      case 1: // Map
        if (currentScreen != 'map') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
          );
        }
        break;
      case 3: // Search
        if (currentScreen != 'search') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
          );
        }
        break;
      case 4: // Profile
        if (currentScreen != 'profile') {
          Navigator.pushReplacementNamed(context, '/profile');
        }
        break;
    }
  }
} 