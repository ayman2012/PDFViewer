//
//  SignatureManager.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//
import PDFKit


class SignatureManager {
    private var signaturesByPage: [Int: [SignatureModel]] = [:]
    private var signatureViews: [SignatureView] = []
    
    var hasSignatures: Bool { !signatureViews.isEmpty }
    
    // NEW: Callbacks for controller to handle mode switching
    var onSaveRequest: (() -> Void)?
    var onDeleteRequest: (() -> Void)?
    
    // MARK: - View Management
    
    func addSignature(image: UIImage, to view: UIView, pdfView: PDFView) {
        
        // Use view bounds directly since view is now synced to page frame
        let signatureWidth: CGFloat = 150
        let signatureHeight: CGFloat = 75
        
        // Center in the container view (screen center initially)
        let signatureFrame = CGRect(
            x: view.bounds.midX - signatureWidth / 2,
            y: view.bounds.midY - signatureHeight / 2,
            width: signatureWidth,
            height: signatureHeight
        )
        
        let newSignatureView = SignatureView(image: image)
        newSignatureView.frame = signatureFrame
        
        // Provide Dynamic Bounds via Closure
        newSignatureView.getPageBounds = { [weak pdfView] in
            guard let pdfView = pdfView, let page = pdfView.currentPage else { return .zero }
            // Convert page bounds to the container view's coordinate system directly
            // Since container is full screen overlay, converting to 'view' is correct
            let pageBounds = page.bounds(for: .mediaBox)
            return pdfView.convert(pageBounds, from: page)
        }
        
        // NEW: Store the initial PDF coordinates so we can re-project later
        if let currentPage = pdfView.currentPage {
            let pdfFrame = pdfView.convert(signatureFrame, to: currentPage)
            newSignatureView.pdfFrame = pdfFrame
            newSignatureView.pageIndex = pdfView.document?.index(for: currentPage) ?? 0
        }
        
        // NEW: Live Capture of Truth
        // Capture the PDF coordinates immediately when the user is interacting
        // This ensures what they see is what we save, ignoring any layout shifts later
        newSignatureView.onFrameChange = { [weak newSignatureView, weak pdfView] in
            guard let view = newSignatureView, let pdfView = pdfView, let page = pdfView.currentPage else { return }
            
            let frameInView = view.frame
            // Convert to PDFView then to Page
            let frameInPDFView = view.superview?.convert(frameInView, to: pdfView) ?? frameInView
            let pdfFrame = pdfView.convert(frameInPDFView, to: page)
            
            view.pdfFrame = pdfFrame
        }
        
        newSignatureView.onDelete = { [weak self] signature in
            self?.removeSignatureView(signature)
            self?.onDeleteRequest?() // Trigger mode switch after delete
        }
        
        newSignatureView.onSave = { [weak self] _ in
            self?.onSaveRequest?() // Trigger save & mode switch
        }
        
        view.addSubview(newSignatureView)
        signatureViews.append(newSignatureView)
        newSignatureView.select()
    }
    
    private func removeSignatureView(_ signature: SignatureView) {
        // CRITICAL: Remove from array IMMEDIATELY, not in animation completion
        // Otherwise if mode switches before animation completes, the signature gets saved!
        signatureViews.removeAll { $0 === signature }
        
        UIView.animate(withDuration: 0.25, animations: {
            signature.alpha = 0
            signature.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }) { _ in
            signature.removeFromSuperview()
        }
    }
    
    func deselectAll() {
        signatureViews.forEach { $0.deselect() }
    }
    
    func setSignaturesHidden(_ hidden: Bool) {
        signatureViews.forEach { $0.isHidden = hidden }
    }
    
    // MARK: - Persistence
    
    func saveSignatures(from view: UIView, pdfView: PDFView, at pageIndex: Int) {
        guard let page = pdfView.document?.page(at: pageIndex) else { return }
        
        let models = signatureViews.compactMap { signatureView -> SignatureModel? in
            // 1. Prefer Stored PDF Frame (Real-time capture) over Save-time calculation
            // This avoids layout drift issues during mode switching
            var pdfFrame = signatureView.pdfFrame
            
            if pdfFrame == nil {
                print("⚠️ Save Signature: Missing stored PDF frame, falling back to calculation (Likely inaccurate)")
                
                // Fallback Calculation (Legacy)
                // 1. Convert from Container View to PDFView
                let frameInPDFView = view.convert(signatureView.frame, to: pdfView)
                
                // 2. Convert from PDFView to Page
                pdfFrame = pdfView.convert(frameInPDFView, to: page)
            }
            
            // Unwrap finally
            guard let finalPdfFrame = pdfFrame else { return nil }
            
            // Capture the signature image data
            let imageData = signatureView.imageView.image?.pngData()
            
            print("💾 Save Signature:")
            print("   - View Frame: \(signatureView.frame)")
            print("   - Stored/Calculated PDF Frame: \(finalPdfFrame)")
            print("   - Page Bounds: \(page.bounds(for: .mediaBox))")
            
            return SignatureModel(
                imageData: imageData,
                frameInPDFCoordinates: finalPdfFrame,
                transform: signatureView.transform,
                pageIndex: pageIndex
            )
        }
        
        if !models.isEmpty {
            signaturesByPage[pageIndex] = models
            print("💾 SignatureManager: Saved \(models.count) signatures for page \(pageIndex)")
        } else {
            signaturesByPage.removeValue(forKey: pageIndex)
        }
    }
    
    func loadSignatures(into view: UIView, pdfView: PDFView, at pageIndex: Int) {
        // Clear existing views
        signatureViews.forEach { $0.removeFromSuperview() }
        signatureViews.removeAll()
        
        guard let models = signaturesByPage[pageIndex],
              let page = pdfView.document?.page(at: pageIndex) else { return }
        
        for model in models {
            // Valid Image Loading: Check data first, then name
            var image: UIImage?
            if let imageData = model.imageData {
                image = UIImage(data: imageData)
            } else {
                image = UIImage(named: model.imageName)
            }
            guard let signatureImage = image else { continue }
            
            // 1. Initial Frame Calculation (Snapshot)
            let viewFrame = pdfView.convert(model.frameInPDFCoordinates, from: page)
            
            print("🔍 Load Signature:")
            print("   - PDF Frame: \(model.frameInPDFCoordinates)")
            print("   - Page Bounds: \(page.bounds(for: .mediaBox))")
            print("   - Converted View Frame: \(viewFrame)")
            print("   - Current PDF Scale: \(pdfView.scaleFactor)")
            
            let signatureView = SignatureView(image: signatureImage)
            signatureView.frame = viewFrame
            signatureView.transform = model.transform
            
            // 2. Reactive Layout Setup (The "Generic Solution")
            // Store source of truth for continuous updates
            signatureView.pdfFrame = model.frameInPDFCoordinates
            signatureView.pageIndex = pageIndex
            
            // Provide Dynamic Bounds via Closure
            signatureView.getPageBounds = { [weak pdfView] in
                guard let pdfView = pdfView, let page = pdfView.document?.page(at: pageIndex) else { return .zero }
                let pageBounds = page.bounds(for: .mediaBox)
                return pdfView.convert(pageBounds, from: page)
            }
            
            // NEW: Live Capture of Truth
            signatureView.onFrameChange = { [weak signatureView, weak pdfView] in
                guard let view = signatureView, let pdfView = pdfView, let page = pdfView.document?.page(at: pageIndex) else { return }
                
                let frameInView = view.frame
                let frameInPDFView = view.superview?.convert(frameInView, to: pdfView) ?? frameInView
                let pdfFrame = pdfView.convert(frameInPDFView, to: page)
                
                view.pdfFrame = pdfFrame
            }
            
            signatureView.onDelete = { [weak self] signature in
                self?.removeSignatureView(signature)
                self?.onDeleteRequest?()
            }
            
            signatureView.onSave = { [weak self] _ in
                self?.onSaveRequest?()
            }
            
            view.addSubview(signatureView)
            signatureViews.append(signatureView)
        }
    }
    
    func reset() {
        signaturesByPage.removeAll()
        signatureViews.forEach { $0.removeFromSuperview() }
        signatureViews.removeAll()
        print("🗑️ SignatureManager: All state reset")
    }
    
    // Accessor for Export
    func getAllSignatures() -> [Int: [SignatureModel]] {
        return signaturesByPage
    }
    
    // MARK: - Layout Updates
    
    func refreshLayout(pdfView: PDFView, view: UIView) {
        for signatureView in signatureViews {
            guard let pdfFrame = signatureView.pdfFrame,
                  let page = pdfView.document?.page(at: signatureView.pageIndex) else { continue }
            
            // Re-project the stored PDF frame to the current view coordinates
            let viewFrame = pdfView.convert(pdfFrame, from: page)
            
            // Safe Update: Respect Transform
            // If we set .frame directly on a transformed view, the behavior is undefined/broken
            let newCenter = CGPoint(x: viewFrame.midX, y: viewFrame.midY)
            let newBounds = CGRect(origin: .zero, size: viewFrame.size)
            
            // Only convert center if needed (Container is full screen overlaid on PDFView's content view usually,
            // but if PDFView scrolls, we need to be careful.
            // Since SignatureContainer is a Subview of PDFAnnotatorView (which contains PDFView),
            // and we want signatures to track the PDF Content...
            // Actually: The previous logic convert(viewFrame, from: pdfView) was handling the scroll offset!
            
            let frameInContainer = view.convert(viewFrame, from: pdfView)
            
            // Update Center & Bounds instead of Frame to preserve transform
            signatureView.bounds = CGRect(origin: .zero, size: frameInContainer.size)
            signatureView.center = CGPoint(x: frameInContainer.midX, y: frameInContainer.midY)
            
            print("🔄 Refresh P\(signatureView.pageIndex): Center \(signatureView.center)")
        }
    }
}
