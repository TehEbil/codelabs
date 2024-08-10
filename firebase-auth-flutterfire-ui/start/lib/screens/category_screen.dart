import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chatroom_screen.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  void _joinCategoryChat(BuildContext context, String category) async {
    final chatRoomId = await _getOrCreateChatRoomId(category);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatRoomScreen(chatRoomId: chatRoomId, category: category),
      ),
    );
  }

  Future<String> _getOrCreateChatRoomId(String category) async {
    final chatRoomsRef =
        FirebaseFirestore.instance.collection('category_chatrooms');
    final snapshot = await chatRoomsRef
        .where('category', isEqualTo: category)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    } else {
      final newChatRoom = await chatRoomsRef.add({
        'category': category,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return newChatRoom.id;
    }
  }

  Widget categoryCard(String category, IconData icon, BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        leading: Icon(icon, size: 30.0, color: Colors.green[700]),
        title: Text(category, style: TextStyle(fontSize: 18.0)),
        onTap: () => _joinCategoryChat(context, category),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Category'),
      ),
      body: ListView(
        children: [
          categoryCard('Relationships', Icons.favorite, context),
          categoryCard('Abuse', Icons.report_problem, context),
          categoryCard('LGBT', Icons.people, context),
          categoryCard('Depression', Icons.mood_bad, context),
          categoryCard('Environment', Icons.eco, context),
          categoryCard('Animals', Icons.pets, context),
        ],
      ),
    );
  }
}
