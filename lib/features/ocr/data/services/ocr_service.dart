// import 'dart:io';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// /// On-device offline OCR service powered by Google ML Kit.
// class OcrService {
//   TextRecognizer? _textRecognizer;

//   OcrService() {
//     try {
//       _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
//     } catch (_) {
//       // Platform fallback if ML Kit native library initialization is unsupported
//       _textRecognizer = null;
//     }
//   }

//   /// Processes local image file at [imagePath] and returns recognized text string.
//   Future<String> processImage(String imagePath) async {
//     if (imagePath.isEmpty) return '';
//     final file = File(imagePath);
//     if (!await file.exists()) return '';

//     if (_textRecognizer == null) {
//       return '';
//     }

//     try {
//       final inputImage = InputImage.fromFilePath(imagePath);
//       final recognizedText = await _textRecognizer!.processImage(inputImage);
//       return recognizedText.text;
//     } catch (_) {
//       // Return empty text gracefully without throwing or exposing platform errors
//       return '';
//     }
//   }

//   /// Disposes text recognizer instance resources.
//   Future<void> dispose() async {
//     try {
//       await _textRecognizer?.close();
//     } catch (_) {}
//   }
// }
