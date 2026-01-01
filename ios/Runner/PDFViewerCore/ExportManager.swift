//
//  ExportManager.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//

import PDFKit


class ExportManager {
    
    func generateAnnotatedPDF(
        sourceURL: URL,
        drawings: [Int: DrawingModel],
        signatures: [Int: [SignatureModel]],
        includeDrawings: Bool,
        includeSignatures: Bool
    ) -> PDFDocument? {
        
        guard let annotatedDocument = PDFDocument(url: sourceURL) else { return nil }
        
        let allPageIndices = Set(drawings.keys).union(signatures.keys)
        
        for pageIndex in allPageIndices.sorted() {
            guard let page = annotatedDocument.page(at: pageIndex) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            
            // 1. Drawings
            if includeDrawings, let drawingModel = drawings[pageIndex] {
                // Clean old image annotations first
                page.annotations.filter { $0 is ImageAnnotation }.forEach { page.removeAnnotation($0) }
                
                let targetScale = UIScreen.main.scale * 2.0
                let image = drawingModel.drawing.image(from: drawingModel.canvasBoundsAtCreation, scale: targetScale)
                let annotation = ImageAnnotation(image: image, bounds: pageBounds)
                page.addAnnotation(annotation)
            }
            
            // 2. Signatures
            if includeSignatures, let pageSignatures = signatures[pageIndex] {
                for model in pageSignatures {
                    // Try to load from imageData first, fall back to imageName
                    var image: UIImage?
                    if let imageData = model.imageData {
                        image = UIImage(data: imageData)
                    } else {
                        image = UIImage(named: model.imageName)
                    }
                    
                    guard let signatureImage = image else { continue }
                    let annotation = ImageAnnotation(image: signatureImage, bounds: model.frameInPDFCoordinates)
                    page.addAnnotation(annotation)
                }
            }
        }
        
        return annotatedDocument
    }
    
    func share(data: Data, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        viewController.present(activityVC, animated: true)
    }
}
