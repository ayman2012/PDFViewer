//
//  PDFAnnotatorView.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//

import UIKit
import PDFKit
import PencilKit

public class PDFAnnotatorView: UIView {
    
    // MARK: - UI Components
    public let pdfView = PDFView()
    public let canvasView = PKCanvasView()
    public let signatureContainerView = UIView() // Container for signatures
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 1. PDF View
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pdfView)
        
        // 2. Canvas View (Overlay)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        // CRITICAL: Allow any input (finger/pencil) and manual frame management
        canvasView.drawingPolicy = .anyInput
        // canvasView.translatesAutoresizingMaskIntoConstraints = true // Default is true, don't set to false
        addSubview(canvasView)
        
        // 3. Signature Container (Overlay)
        signatureContainerView.backgroundColor = .clear // Changed to clear for production
        signatureContainerView.isUserInteractionEnabled = false // Let touches pass through unless hitting a subview
        signatureContainerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(signatureContainerView)
        
        // Constraints
        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Canvas frame is managed manually by the Engine to match the PDF page bounds
            // Do NOT add constraints here
            
            // Signature container pinned to edges (full screen overlay)
            signatureContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            signatureContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            signatureContainerView.topAnchor.constraint(equalTo: topAnchor),
            signatureContainerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Layout Updates
    
    public var onLayoutSubviews: (() -> Void)?
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // The Engine will handle updating the canvas frame to match the PDF page
        onLayoutSubviews?()
    }
}
