import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/utils/receipt_parser.dart';

/// Result from a single OCR pass.
class OcrResult {
  const OcrResult({
    required this.items,
    required this.rawText,
    required this.hasLowConfidenceItems,
  });

  final List<ParsedReceiptLine> items;
  final String rawText;
  final bool hasLowConfidenceItems;
}

/// Wraps Google ML Kit text recognition and feeds output to [ReceiptParser].
class OcrService {
  OcrService()
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<OcrResult> recognizeFromFile(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return _process(inputImage);
  }

  Future<OcrResult> recognizeFromPath(String path) async {
    final inputImage = InputImage.fromFilePath(path);
    return _process(inputImage);
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<OcrResult> _process(InputImage inputImage) async {
    final recognized = await _recognizer.processImage(inputImage);
    final rawText = recognized.text;

    // Extract lines from all text blocks.
    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }

    final parsed = ReceiptParser.parseLines(lines);
    final hasLowConfidence = parsed.any((l) => l.confidence < 0.7);

    return OcrResult(
      items: parsed,
      rawText: rawText,
      hasLowConfidenceItems: hasLowConfidence,
    );
  }
}
