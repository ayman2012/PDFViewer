import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Init native PDF bridge
  PdfBridge.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.picture_as_pdf,
              size: 100,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'PDF Viewer Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            ElevatedButton.icon(
              onPressed: () async {
                await PdfBridge.openPdfViewer('sample.pdf');
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Open PDF Viewer'),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                await PdfBridge.openPdfViewerWithAnnotation('sample.pdf');
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF Viewer (Annotation)'),
            ),
          ],
        ),
      ),
    );
  }
}
class PdfBridge {
  static const MethodChannel _channel = MethodChannel('pdf_native_channel');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPdfSaved') {
        final path = call.arguments['path'];
        final isStamp = call.arguments['isStamp'];

        debugPrint('📄 PDF Saved: $path');
        debugPrint('Stamp mode: $isStamp');

        // Open the modified PDF
        await openPdf(path);
      }
    });
  }

  static Future<void> openPdf(String path) async {
    // Implement your Flutter PDF viewer here
     debugPrint("Opening modified PDF: $path");
  }

  static Future<void> openPdfViewer(String pdfPath) async {
    await _channel.invokeMethod('openPdfViewer', {'pdfPath': pdfPath});
  }

  static Future<void> openPdfViewerWithAnnotation(String pdfPath) async {
    await _channel.invokeMethod('openPdfViewerWithAnnotation', {'pdfPath': pdfPath});
  }
}