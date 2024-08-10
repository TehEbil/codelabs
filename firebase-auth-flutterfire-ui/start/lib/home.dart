import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'chatbot_screen.dart'; // Import the chat screen
import 'chat/firebase_service.dart'; // Ensure FirebaseService is imported
import 'package:intl/intl.dart'; // Import for date formatting

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() =>
      HomeScreenState(); // Make the class name public
}

class HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  void _showEmergencyContacts(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Contacts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Nummer gegen Kummer for Youths'),
                subtitle: const Text('Tel. 116 111'),
              ),
              ListTile(
                title: const Text('Nummer gegen Kummer for Parents'),
                subtitle: const Text('Tel. 0800 11 10 550'),
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

  Future<List<DocumentSnapshot>> _fetchLatestChats() async {
    // Fetch all chats for the current user
    QuerySnapshot snapshot = await _firebaseService.chatCollection
        .where('userId', isEqualTo: _firebaseService.currentUser)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs;
  }

  void _openChat(BuildContext context, DocumentSnapshot chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatbotScreen(chatId: chat.id), // Pass chat ID
      ),
    ).then((_) {
      // Refresh the HomeScreen when returning from the chat screen
      setState(() {});
    });
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
                          child: Image.asset('flutterfire_300x.png'),
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('dash.png'),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome Back!',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _showEmergencyContacts(context);
              },
              child: const Text('Emergency Contacts'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<DocumentSnapshot>>(
                future: _fetchLatestChats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No recent chats.');
                  } else {
                    var filteredChats = snapshot.data!.where((chat) {
                      final data = chat.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Chat';
                      return title.toLowerCase().contains(searchQuery);
                    }).toList();

                    return ListView.builder(
                      itemCount: filteredChats.length,
                      itemBuilder: (context, index) {
                        final chat = filteredChats[index];
                        final data = chat.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Chat';
                        final timestamp = data['timestamp'] as Timestamp;
                        final time = DateFormat('dd/MM/yyyy HH:mm')
                            .format(timestamp.toDate());

                        return ListTile(
                          title: Text(title),
                          subtitle: Text(time),
                          onTap: () => _openChat(context, chat),
                        );
                      },
                    );
                  }
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ChatbotScreen(), // New chat screen
                  ),
                ).then((_) {
                  // Refresh the HomeScreen when returning from the chat screen
                  setState(() {});
                });
              },
              child: const Text('New Chat'),
            ),
            const SizedBox(height: 20),
            const SignOutButton(),
          ],
        ),
      ),
    );
  }
}
