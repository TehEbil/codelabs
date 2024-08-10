import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_service.dart';

class FilePickerService {
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> pickAndUploadFile({bool isPhoto = false}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: isPhoto ? FileType.image : FileType.any,
      );

      if (result != null) {
        String fileName = result.files.single.name;

        if (kIsWeb) {
          Uint8List? fileBytes = result.files.single.bytes;
          if (fileBytes != null) {
            String fileUrl =
                await _firebaseService.uploadFile(fileBytes, fileName);
            await _firebaseService.sendMessage(
                fileUrl, isPhoto ? 'image' : 'file', 'User');
          }
        } else {
          String? filePath = result.files.single.path;
          if (filePath != null) {
            String fileUrl =
                await _firebaseService.uploadFileFromPath(filePath, fileName);
            await _firebaseService.sendMessage(
                fileUrl, isPhoto ? 'image' : 'file', 'User');
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
}
