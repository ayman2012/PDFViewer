import Flutter
import UIKit

var window: UIWindow?


@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private var pdfChannel: FlutterMethodChannel?

    
  override func application(_ application: UIApplication,
                            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
      
      
      window = UIWindow(frame: UIScreen.main.bounds)
      let flutterVC = FlutterViewController()
      pdfChannel = FlutterMethodChannel(
          name: "pdf_native_channel",
          binaryMessenger: flutterVC.binaryMessenger
      )
      window?.rootViewController = flutterVC
      window?.makeKeyAndVisible()
      
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channel to receive calls from Flutter
    let controller = window?.rootViewController as! FlutterViewController

      pdfChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
     
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
               self?.openNativePdfViewer(pdfPath: bundlePath, withAnnotation: false)
           }
           
           if call.method == "openPdfViewerWithAnnotation"  {
               self?.openNativePdfViewer(pdfPath: bundlePath, withAnnotation: true)
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
    
    private func openNativePdfViewer(pdfPath: String, withAnnotation: Bool) {
        DispatchQueue.main.async {
            // Load NewPDFViewerVC
            let pdfVC = NewPDFViewerVC()
            pdfVC.loadPDF(from: pdfPath)
            pdfVC.shouldEnableAnnotation = withAnnotation
            pdfVC.modalPresentationStyle = .fullScreen

            // Provide a callback to send back modified PDF
            pdfVC.onSaveCallback = { [weak self] modifiedPath, isStamp in
                self?.pdfChannel?.invokeMethod("onPdfSaved", arguments: [
                    "path": modifiedPath,
                    "isStamp": isStamp
                ])
            }

            // Present on top of the top-most VC
            if var topVC = self.window?.rootViewController {
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(pdfVC, animated: true)
            }
        }
    }
}
