# Click - Petrol Pump Management App

## Adding Hamburger Menu (AppDrawer) to Screens

The app includes a reusable `AppDrawer` widget that provides consistent navigation across all screens. Here's how to add it to any screen:

### 1. Import the AppDrawer widget

```dart
import '../widgets/app_drawer.dart';
```

### 2. Add the drawer to your Scaffold

```dart
return Scaffold(
  drawer: const AppDrawer(currentScreen: 'screen_name'),
  appBar: AppBar(
    // ... your app bar
  ),
  body: // ... your body content
);
```

### 3. Available screen names

The `currentScreen` parameter should be one of:
- `'home'` - Home/Dashboard screen
- `'map'` - Map screen
- `'search'` - Search petrol pumps screen
- `'profile'` - Profile screen
- `'add_pump'` - Add petrol pump screen

### 4. Features included in AppDrawer

The AppDrawer includes:
- **User Profile Section**: Shows user info and profile completion
- **Team Management**: Create/join teams or view team details
- **Navigation Menu**: Quick access to all app features
- **Services Section**: Dashboard, Map, Add Pump, Search, Camera, etc.
- **Coming Soon Features**: Team Chat, Special Offers, Support, Settings
- **Logout Functionality**: Properly signs out user

### 5. Example Implementation

```dart
import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentScreen: 'my_screen'),
      appBar: AppBar(
        title: const Text('My Screen'),
      ),
      body: const Center(
        child: Text('My Screen Content'),
      ),
    );
  }
}
```

### 6. Screens Already Updated

The following screens have been updated to include the AppDrawer:
- ✅ Home Screen (`home_screen.dart`)
- ✅ Search Petrol Pumps Screen (`search_petrol_pumps_screen.dart`)
- ✅ OpenStreet Map Screen (`openstreet_map_screen.dart`)
- ✅ Profile Screen (`profile_screen.dart`)
- ✅ Add Petrol Pump Screen (`add_petrol_pump_screen.dart`)

### 7. Benefits

- **Consistent Navigation**: Same menu structure across all screens
- **User Context**: Shows user profile and team information
- **Quick Access**: Easy navigation between different app sections
- **Proper Logout**: Handles authentication properly
- **Responsive Design**: Works well on different screen sizes

## Getting Started

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`

## Features

- User authentication and profile management
- Team creation and management
- Petrol pump location mapping
- Search and filter functionality
- Add new petrol pump locations
- Camera integration for photos
- Location history tracking
