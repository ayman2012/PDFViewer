//
//  ModeManager.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//

import PDFKit

public class ModeManager {
   public enum AppMode {
        case view
        case editDrawings
        case editSignatures
    }
    
    private(set) var currentMode: AppMode = .view
    private let exportManager = ExportManager()
    
    // Dependencies
    weak var pdfView: PDFView?
    var drawingManager: DrawingManager?
    var signatureManager: SignatureManager?
    var sourceDocumentURL: URL?
    
    // In ModeManager.swift

    func switchMode(to newMode: AppMode, currentPage: Int) {
        guard let pdfView = pdfView, let url = sourceDocumentURL else { return }
        
        // ... (Drawing/Signature boolean logic remains the same) ...
        var includeDrawings = false
        var includeSignatures = false
        
        switch newMode {
        case .view:
            includeDrawings = true
            includeSignatures = true
        case .editDrawings:
            includeDrawings = false
            includeSignatures = true
        case .editSignatures:
            includeDrawings = true
            includeSignatures = false
        }
        
        print("📝 ModeManager: Switching to \(newMode)")
        print("   Include drawings: \(includeDrawings)")
        print("   Include signatures: \(includeSignatures)")
        print("   Drawings in memory: \(drawingManager?.drawingsByPage.keys.sorted() ?? [])")
        print("   Signatures in memory: \(signatureManager?.getAllSignatures().keys.sorted() ?? [])")
        
        // 2. Generate PDF
        if let newDoc = exportManager.generateAnnotatedPDF(
            sourceURL: url,
            drawings: drawingManager?.drawingsByPage ?? [:],
            signatures: signatureManager?.getAllSignatures() ?? [:],
            includeDrawings: includeDrawings,
            includeSignatures: includeSignatures
        ) {
            
            pdfView.document = newDoc
            print("   ✅ PDF regenerated with \(newDoc.pageCount) pages")
            
            // --- START CHANGE ---
            // Fix: Use the Integer 'currentPage' index instead of looking for the old Page object
            if currentPage < newDoc.pageCount, let newPage = newDoc.page(at: currentPage) {
                pdfView.go(to: newPage)
            }
        }
        
        self.currentMode = newMode
    }
}
