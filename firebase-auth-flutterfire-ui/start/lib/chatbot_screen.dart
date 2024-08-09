import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
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

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      print(result);

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        // Upload file to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
        UploadTask uploadTask = storageRef.putFile(file);

        // Wait for the upload to complete
        TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});

        // Get download URL and send as a message
        String fileUrl = await taskSnapshot.ref.getDownloadURL();
        await chatCollection.add({
          'message': fileUrl,
          'sender': 'User',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': currentUser,
          'type': 'file', // Indicate this message is a file
        });

        print('File uploaded successfully');
      } else {
        print('No file selected or invalid file path');
      }
    } catch (e) {
      print('Error picking or uploading file: $e');
    }
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _pickAndUploadFile,
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            onPressed: _isListening ? _stopListening : _startListening,
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
      });

      // Simulate AI response
      await Future<void>.delayed(const Duration(seconds: 1));
      await chatCollection.add({
        'message': 'This is an AI response to: ${_messageController.text}',
        'sender': 'AI',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser,
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) => setState(() => _isListening = _speech.isListening),
      onError: (val) => print('Speech recognition error: $val'),
    );
    if (available) {
      _speech.listen(onResult: (val) {
        setState(() {
          _messageController.text = val.recognizedWords;
        });
      });
    }
  }

  Future<void> _stopListening() async {
    _speech.stop();
    setState(() => _isListening = false);
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

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final message = data['message'] ?? 'No message';
                    final sender = data['sender'] ?? 'Unknown sender';
                    final isCurrentUser = sender == 'User';

                    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    final time = timestamp?.toDate() ?? DateTime.now();

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
                            Text(
                              message,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              time.toLocal().toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
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
}
