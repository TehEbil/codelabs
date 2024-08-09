import 'dart:typed_data';
import 'dart:io' as io;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final CollectionReference chatCollection =
      FirebaseFirestore.instance.collection('chats');
  final String currentUser = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _pickAndUploadFile({bool isPhoto = false}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: isPhoto ? FileType.image : FileType.any,
      );

      if (result != null) {
        String fileName = result.files.single.name;

        if (kIsWeb) {
          Uint8List? fileBytes = result.files.single.bytes;
          if (fileBytes != null) {
            final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
            UploadTask uploadTask = storageRef.putData(fileBytes);

            TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
            String fileUrl = await taskSnapshot.ref.getDownloadURL();
            await chatCollection.add({
              'message': fileUrl,
              'sender': 'User',
              'timestamp': FieldValue.serverTimestamp(),
              'userId': currentUser,
              'type': isPhoto ? 'image' : 'file',
            });
          }
        } else {
          String? filePath = result.files.single.path;
          if (filePath != null) {
            io.File file = io.File(filePath);

            final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
            UploadTask uploadTask = storageRef.putFile(file);

            TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
            String fileUrl = await taskSnapshot.ref.getDownloadURL();
            await chatCollection.add({
              'message': fileUrl,
              'sender': 'User',
              'timestamp': FieldValue.serverTimestamp(),
              'userId': currentUser,
              'type': isPhoto ? 'image' : 'file',
            });
          }
        }

        print('File uploaded successfully');
      } else {
        print('No file selected');
      }
    } catch (e) {
      print('Error picking or uploading file: $e');
    }
  }

  Future<void> _recordAndSendMessage() async {
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(onResult: (val) {
        setState(() {
          _messageController.text = val.recognizedWords;
        });
      });
      await Future.delayed(const Duration(milliseconds: 200)); // Delay before stopping
      _speech.stop();
      _sendMessage();
      _messageController.clear();
    }
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: () => _pickAndUploadFile(isPhoto: true),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () => _pickAndUploadFile(),
          ),
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _recordAndSendMessage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Enter your message',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    try {
      await chatCollection.add({
        'message': _messageController.text,
        'sender': 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser,
        'type': 'text',
      });

      await Future<void>.delayed(const Duration(seconds: 1));
      await chatCollection.add({
        'message': 'This is an AI response to: ${_messageController.text}',
        'sender': 'AI',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser,
        'type': 'text',
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatCollection
                  .where('userId', isEqualTo: currentUser)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                List<DocumentSnapshot> docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final message = data['message'] ?? 'No message';
                    final sender = data['sender'] ?? 'Unknown sender';
                    final isCurrentUser = sender == 'User';

                    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    final time = timestamp?.toDate() ?? DateTime.now();

                    bool showDateBadge = false;
                    if (index == 0 ||
                        (index > 0 && !_isSameDay(docs[index - 1]['timestamp'], timestamp))) {
                      showDateBadge = true;
                    }

                    return Column(
                      crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (showDateBadge) _buildDateBadge(time),
                        _buildMessageBubble(message, isCurrentUser, data['type'], time),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isCurrentUser, String type, DateTime time) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blueAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == 'text') ...[
              Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ] else if (type == 'image') ...[
              Image.network(message),
            ] else ...[
              InkWell(
                onTap: () => _openFile(message),
                child: Row(
                  children: [
                    Icon(Icons.insert_drive_file, color: Colors.white),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Open File',
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              time.toLocal().toString(),
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(DateTime date) {
    String formattedDate;
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      formattedDate = "Heute";
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      formattedDate = "Gestern";
    } else {
      formattedDate = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(formattedDate),
      ),
    );
  }

  bool _isSameDay(Timestamp? t1, Timestamp? t2) {
    if (t1 == null || t2 == null) return false;
    final d1 = t1.toDate();
    final d2 = t2.toDate();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  void _openFile(String url) {
    // Implement logic to open the file URL in a browser or using a file viewer
    print('Opening file: $url');
  }
}
