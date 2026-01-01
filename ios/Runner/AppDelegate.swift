import Flutter
import UIKit

var window: UIWindow?

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channel to receive calls from Flutter
    let controller = window?.rootViewController as! FlutterViewController
    let pdfChannel = FlutterMethodChannel(name: "com.example.momo/pdf",
                                          binaryMessenger: controller.binaryMessenger)

    pdfChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
     
      // Extract the PDF path from arguments
      guard let args = call.arguments as? [String: Any],
            let pdfPath = args["pdfPath"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT",
                           message: "PDF path is required",
                           details: nil))
        return
      }

      // Get the full path to the PDF file from the bundle
       let fileName = (pdfPath as NSString).deletingPathExtension
       let fileExtension = (pdfPath as NSString).pathExtension.isEmpty ? "pdf" : (pdfPath as NSString).pathExtension

       if let bundlePath = Bundle.main.path(forResource: fileName, ofType: fileExtension) {
         // Call your native function to open the PDF
           if call.method == "openPdfViewer"  {
               self?.openMyNativePdfViewer(pdfFilePath: bundlePath)
           }
           
           if call.method == "openPdfViewerWithAnnotation"  {
               self?.openMyNativePdfViewerWithAnnotation(pdfFilePath: bundlePath)
           }

         result(true)
       } else {
         result(FlutterError(code: "FILE_NOT_FOUND",
                            message: "PDF file not found in bundle: \(pdfPath)",
                            details: nil))
       }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Your Native PDF Viewer Function
  // Add your native code here to open the PDF
  private func openMyNativePdfViewer(pdfFilePath: String) {
    // TODO: Add your native code to open the PDF viewer here
    // The pdfFilePath parameter contains the full path to sample.pdf

    print("Opening PDF at path: \(pdfFilePath)")
      
      window = UIWindow(frame: UIScreen.main.bounds)
      
      let vc = NewPDFViewerVC()
      vc.loadPDF(from: pdfFilePath)
 
      window?.rootViewController = vc
      window?.makeKeyAndVisible()
  }
    
    private func openMyNativePdfViewerWithAnnotation(pdfFilePath: String) {
      // TODO: Add your native code to open the PDF viewer here
      // The pdfFilePath parameter contains the full path to sample.pdf

      print("Opening PDF at path: \(pdfFilePath)")
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let vc = NewPDFViewerVC()
        vc.loadPDF(from: pdfFilePath)
        vc.shouldEnableAnnotation = true
   
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
    }
}
extension Notification.Name {
    static let pdfDidSave = Notification.Name("pdfDidSave")
}
