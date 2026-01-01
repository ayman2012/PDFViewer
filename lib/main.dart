import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.example.momo/pdf');

  Future<void> openPdfViewer(String pdfPath) async {
    try {
      await platform.invokeMethod('openPdfViewer', {'pdfPath': pdfPath});
    } on PlatformException catch (e) {
      print("Failed to open PDF viewer: '${e.message}'.");
    }
  }

  Future<void> openPdfViewerWithAnotation(String pdfPath) async {
    try {
      await platform.invokeMethod('openPdfViewerWithAnnotation', {'pdfPath': pdfPath});
    } on PlatformException catch (e) {
      print("Failed to open PDF viewer: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        title: Text(widget.title),
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

            /// 🔴 Existing button (unchanged)
            ElevatedButton.icon(
              onPressed: () async {
                await openPdfViewer('sample.pdf');
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Open PDF Viewer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),

            const SizedBox(height: 16),


            ElevatedButton.icon(
              onPressed: () async {
                await openPdfViewerWithAnotation('sample.pdf');
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF Viewer (New)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}