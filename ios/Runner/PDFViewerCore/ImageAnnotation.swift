//
//  ImageAnnotation.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//

import UIKit
import PDFKit
import PencilKit

// MARK: - Models

// MARK: - Helper Classes

class ImageAnnotation: PDFAnnotation {
    private var image: UIImage
 
    init(image: UIImage, bounds: CGRect) {
        self.image = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }
 
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let cgImage = image.cgImage else { return }
        
        context.saveGState()
        
        // Calculate Aspect Fit Frame
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let aspect = imageWidth / imageHeight
        
        let viewWidth = bounds.width
        let viewHeight = bounds.height
        let viewAspect = viewWidth / viewHeight
        
        var drawRect = bounds
        
        if aspect > viewAspect {
            // Image is wider than view (fit to width)
            let newHeight = viewWidth / aspect
            let yOffset = (viewHeight - newHeight) / 2.0
            drawRect = CGRect(x: bounds.minX, y: bounds.minY + yOffset, width: viewWidth, height: newHeight)
        } else {
            // Image is taller than view (fit to height)
            let newWidth = viewHeight * aspect
            let xOffset = (viewWidth - newWidth) / 2.0
            drawRect = CGRect(x: bounds.minX + xOffset, y: bounds.minY, width: newWidth, height: viewHeight)
        }
        
        // Flip context for PDF coordinate system if needed, but PDFKit usually handles this.
        // However, standard CGContext drawing might come out upside down depending on the context setup.
        // Let's try standard drawing first. If it's upside down, we'll need to flip.
        // PDF coordinates: Origin bottom-left.
        // CGImage drawing: Usually expects origin bottom-left in PDF context.
        
        context.draw(cgImage, in: drawRect)
        context.restoreGState()
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
