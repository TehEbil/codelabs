import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart'; // Import Gemini API

class FirebaseService {
  final CollectionReference chatCollection =
      FirebaseFirestore.instance.collection('chats');
  final String currentUser =
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  Future<void> sendMessage(
      String chatId, String message, String type, String sender) async {
    try {
      print('Sending message: $message, type: $type, sender: $sender');
      await chatCollection.doc(chatId).collection('messages').add({
        'message': message,
        'sender': sender,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': currentUser,
        'type': type,
      });
      print('Message sent successfully');
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<DocumentReference> createNewChatWithTitle(String firstMessage) async {
    try {
      final title = await generateTitleFromMessage(firstMessage);
      DocumentReference newChat = await chatCollection.add({
        'userId': currentUser,
        'timestamp': FieldValue.serverTimestamp(),
        'title': title,
      });
      return newChat;
    } catch (e) {
      print('Error creating new chat: $e');
      rethrow;
    }
  }

  Future<String> generateTitleFromMessage(String message) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: 'YOUR_API_KEY', // Replace with your actual API key
    );

    try {
      // Start a chat session to send the message
      final chat = model.startChat();

      // Send the message and await response
      final response = await chat.sendMessage(Content.text(message));

      // Extract the title from the response
      // You might need to parse or interpret this response based on how the API returns titles
      final title = response.text ?? 'Chat';

      return title;
    } catch (e) {
      print('Error generating title: $e');
      return 'Chat';
    }
  }

  Future<String> uploadFile(Uint8List fileBytes, String fileName) async {
    final storageRef =
        FirebaseStorage.instance.ref().child('uploads/$fileName');
    UploadTask uploadTask = storageRef.putData(fileBytes);

    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
    return await taskSnapshot.ref.getDownloadURL();
  }

  Future<String> uploadFileFromPath(String filePath, String fileName) async {
    io.File file = io.File(filePath);

    final storageRef =
        FirebaseStorage.instance.ref().child('uploads/$fileName');
    UploadTask uploadTask = storageRef.putFile(file);

    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
    return await taskSnapshot.ref.getDownloadURL();
  }
}
