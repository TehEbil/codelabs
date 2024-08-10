import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'chatbot_screen.dart';
import 'package:intl/intl.dart';

class TalkToAIScreen extends StatefulWidget {
  const TalkToAIScreen({super.key});

  @override
  TalkToAIScreenState createState() => TalkToAIScreenState();
}

class TalkToAIScreenState extends State<TalkToAIScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  Future<List<DocumentSnapshot>> _fetchLatestChats() async {
    try {
      QuerySnapshot snapshot = await _firebaseService.chatCollection
          .where('userId', isEqualTo: _firebaseService.currentUser)
          .where('title', isNotEqualTo: '')
          .orderBy('timestamp', descending: true)
          .orderBy('title')
          .get();

      return snapshot.docs;
    } catch (e) {
      print('Error fetching chats: $e');
      return [];
    }
  }

  Future<DocumentReference?> _findEmptyChat() async {
    try {
      QuerySnapshot snapshot = await _firebaseService.chatCollection
          .where('userId', isEqualTo: _firebaseService.currentUser)
          .where('title', isEqualTo: '')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.reference;
      }
      return null;
    } catch (e) {
      print('Error finding empty chat: $e');
      return null;
    }
  }

  void _openChat(BuildContext context, DocumentSnapshot chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatbotScreen(chatId: chat.id),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _startNewChat(BuildContext context) async {
    DocumentReference? emptyChat = await _findEmptyChat();
    if (emptyChat != null) {
      _openChat(context, await emptyChat.get());
    } else {
      DocumentReference newChat = await _firebaseService.createEmptyChat();
      _openChat(context, await newChat.get());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk to an AI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Chats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true, // Make the search bar smaller
                  contentPadding: EdgeInsets.all(8.0), // Adjust padding
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<DocumentSnapshot>>(
                future: _fetchLatestChats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No recent chats.'));
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8.0), // Compact padding
                          onTap: () => _openChat(context, chat),
                        );
                      },
                    );
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: Icon(Icons.question_answer),
                label: Text('Ask your Question to an AI Therapist'),
                onPressed: () => _startNewChat(context),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.teal, // Text color
                  textStyle:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
