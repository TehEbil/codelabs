import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' as io;
import 'dart:typed_data';

class FirebaseService {
  final CollectionReference chatCollection =
      FirebaseFirestore.instance.collection('chats');
  final String currentUser = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

  Future<void> sendMessage(String message, String type, String sender) async {
    await chatCollection.add({
      'message': message,
      'sender': sender,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': currentUser,
      'type': type,
    });
  }


  Future<String> uploadFile(Uint8List fileBytes, String fileName) async {
    final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
    UploadTask uploadTask = storageRef.putData(fileBytes);

    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
    return await taskSnapshot.ref.getDownloadURL();
  }

  Future<String> uploadFileFromPath(String filePath, String fileName) async {
    io.File file = io.File(filePath);

    final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
    UploadTask uploadTask = storageRef.putFile(file);

    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => {});
    return await taskSnapshot.ref.getDownloadURL();
  }
}
