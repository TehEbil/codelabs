import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'category_screen.dart';
import 'talk_to_ai_screen.dart'; // Import the new screen
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String searchQuery = '';

  User? _user;

  // Avatar options for the random selection
  final List<String> avatarOptions = [
    'assets/wolf.png',
    'assets/dash.png',
    'assets/fox-male.png',
    'assets/fox-female.png',
    'assets/lion.png',
    // Add more cartoon images as needed
  ];

  // Method to get a random avatar image path
  String getRandomAvatar() {
    final random = Random();
    return avatarOptions[random.nextInt(avatarOptions.length)];
  }

  // Method to get the display name or 'Anonymous' if empty
  String getDisplayName(User? user) {
    if (user == null) {
      return 'Anonymous';
    }
    final displayName = user.displayName;
    if (displayName == null || displayName.trim().isEmpty) {
      return 'Anonymous';
    }
    return displayName;
  }

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser; // Get the current user
  }

  void _showEmergencyContacts(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Contacts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ListTile(
                title: Text('Nummer gegen Kummer for Youths'),
                subtitle: Text('Tel. 116 111'),
              ),
              ListTile(
                title: Text('Nummer gegen Kummer for Parents'),
                subtitle: Text('Tel. 0800 11 10 550'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    appBar: AppBar(
                      title: const Text('User Profile'),
                    ),
                    actions: [
                      SignedOutAction((context) {
                        Navigator.of(context).pop();
                      })
                    ],
                    children: [
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.asset('assets/flutterfire_300x.png'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _user?.photoURL != null
                  ? NetworkImage(_user!.photoURL!)
                  : AssetImage(getRandomAvatar()) as ImageProvider,
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome back, ${getDisplayName(_user)}!',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TalkToAIScreen(),
                  ),
                );
              },
              child: const Text('Talk to an AI'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryScreen(),
                  ),
                );
              },
              child: const Text('Join a Category Chatroom'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _showEmergencyContacts(context);
              },
              child: const Text('Emergency Contacts'),
            ),
            const SizedBox(height: 20),
            const SignOutButton(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
