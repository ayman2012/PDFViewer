//
//  PDFAnnotatorEngine.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//
import UIKit
import PDFKit
import PencilKit

public protocol PDFAnnotatorEngineDelegate: AnyObject {
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangeUndoRedoState canUndo: Bool, canRedo: Bool)
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangeTool tool: PKInkingTool)
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangePage pageIndex: Int)
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didToggleDrawing enabled: Bool)
}

public class PDFAnnotatorEngine: NSObject {
    
    // MARK: - Dependencies
    public let annotatorView: PDFAnnotatorView
    public weak var delegate: PDFAnnotatorEngineDelegate?
    
    private var isHandlingRotation = false
    private var rotationWorkItem: DispatchWorkItem?
    private var isSwitchingModes = false // Flag to prevent saves during mode transitions
    
    // Internal Managers
    let modeManager = ModeManager()
    let drawingManager = DrawingManager()
    let signatureManager = SignatureManager()
    let exportManager = ExportManager()
    
    // MARK: - State
    public private(set) var currentPageIndex: Int = 0
    private var previousPageIndex: Int = 0
    // private var pendingDataReload: Bool = false // REMOVED: Using Reactive Layout
    public var currentDocumentURL: URL?
    
    // MARK: - Initialization
    
    public init(view: PDFAnnotatorView) {
        self.annotatorView = view
        super.init()
        setupManagers()
        setupNotifications()
        
        // Initial State
        modeManager.switchMode(to: .view, currentPage: 0)
        updateUI(for: .view)
        
        setupLayoutObservation()
    }
    
    private func setupLayoutObservation() {
        annotatorView.onLayoutSubviews = { [weak self] in
            // Update frame when view lays out (e.g. rotation, resizing)
            // Use simple async to push to next runloop cycle without arbitrary delay
            DispatchQueue.main.async {
                self?.updateCanvasFrame(reloadOnResize: false)
            }
        }
    }
    
    private func setupManagers() {
        modeManager.pdfView = annotatorView.pdfView
        modeManager.drawingManager = drawingManager
        modeManager.signatureManager = signatureManager
        
        // Handle Signature Actions
        signatureManager.onSaveRequest = { [weak self] in
            self?.switchToViewMode()
        }
        
        signatureManager.onDeleteRequest = { [weak self] in
            self?.switchToViewMode()
        }
        
        // Canvas Delegate
        annotatorView.canvasView.delegate = self
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChange), name: .PDFViewPageChanged, object: annotatorView.pdfView)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScaleChange), name: .PDFViewScaleChanged, object: annotatorView.pdfView)
        // NEW: Robust trigger for when layout/fit is actually complete
        NotificationCenter.default.addObserver(self, selector: #selector(handleVisiblePagesChanged), name: .PDFViewVisiblePagesChanged, object: annotatorView.pdfView)
    }
    
    // MARK: - Public API
    
    public func loadPDF(url: URL) {
        self.currentDocumentURL = url
        self.modeManager.sourceDocumentURL = url
        annotatorView.pdfView.document = PDFDocument(url: url)
    }
    
    public func loadPDF(fromPath path: String) {
        let url = URL(fileURLWithPath: path)
        loadPDF(url: url)
    }
    
    public func loadPDF(fromData data: Data) {
        // Write data to a temporary file so we have a URL for ModeManager/ExportManager
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        
        do {
            try data.write(to: tempURL)
            loadPDF(url: tempURL)
        } catch {
            print("❌ PDFAnnotatorEngine: Failed to write temp PDF data: \(error)")
        }
    }
    
    public func loadPDF(resource: String, withExtension ext: String = "pdf") {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            print("❌ PDFAnnotatorEngine: Resource \(resource).\(ext) not found")
            return
        }
        loadPDF(url: url)
    }
    
    public func setMode(_ mode: ModeManager.AppMode, completion: (() -> Void)? = nil) {
        // Prevent redundant mode switches which can cause state reset issues
        guard modeManager.currentMode != mode else {
            print("⚠️ PDFAnnotatorEngine: Already in mode \(mode), skipping switch")
            completion?() // Call completion immediately if already in target mode
            return
        }
        changeMode(to: mode, completion: completion)
    }
    
    public func setTool(_ tool: PKTool) {
        annotatorView.canvasView.tool = tool
    }
    
    public func setEraser() {
        if #available(iOS 16.4, *) {
            annotatorView.canvasView.tool = PKEraserTool(.bitmap, width: 25)
        } else {
            annotatorView.canvasView.tool = PKEraserTool(.bitmap)
        }
    }
    
    public func setDrawingEnabled(_ enabled: Bool) {
        annotatorView.canvasView.drawingGestureRecognizer.isEnabled = enabled
    }
    
    public func addSignature(image: UIImage) {
        signatureManager.addSignature(image: image, to: annotatorView.signatureContainerView, pdfView: annotatorView.pdfView)
    }
    
    public func exportPDF() -> Data? {
        saveCurrentPageData()
        
        guard let url = currentDocumentURL,
              let pdf = exportManager.generateAnnotatedPDF(
                sourceURL: url,
                drawings: drawingManager.drawingsByPage,
                signatures: signatureManager.getAllSignatures(),
                includeDrawings: true,
                includeSignatures: true
              ) else { return nil }
        
        return pdf.dataRepresentation()
    }
    
    public func resetAllChanges() {
        print("🔄 PDFAnnotatorEngine: Resetting all changes")
        
        // 1. Reset Managers (Clear persistence)
        drawingManager.reset()
        signatureManager.reset()
        
        // 2. Clear current views & UI State
        drawingManager.clearCanvas(annotatorView.canvasView)
        delegate?.annotatorEngine(self, didChangeUndoRedoState: false, canRedo: false)
        
        // 3. Reset Mode
        // This stops edit mode logic and ensures we are in a clean "View" state
        // Calls saveCurrentPageData, but managers are empty/cleared so nothing persists
        modeManager.switchMode(to: .view, currentPage: currentPageIndex)
        updateUI(for: .view)
        
        // 4. Reload PDF
        // Re-loads the original clean document URL
        if let url = currentDocumentURL {
            loadPDF(url: url)
        }
        
        print("✅ PDFAnnotatorEngine: Reset complete")
    }
    
    public func undo() {
        let manager = drawingManager.undoManager(for: currentPageIndex)
        guard manager.canUndo else { return }
        
        performUndoRedoAction { [weak self] in
            guard let self = self else { return }
            if let prevState = manager.undo() {
                self.updateDrawingWithoutNotifying {
                    self.drawingManager.loadDrawing(into: self.annotatorView.canvasView, currentState: prevState)
                }
            }
        }
        updateUndoRedoUI()
    }
    
    public func redo() {
        let manager = drawingManager.undoManager(for: currentPageIndex)
        guard manager.canRedo else { return }
        
        performUndoRedoAction { [weak self] in
            guard let self = self else { return }
            if let nextState = manager.redo() {
                self.updateDrawingWithoutNotifying {
                    self.drawingManager.loadDrawing(into: self.annotatorView.canvasView, currentState: nextState)
                }
            }
        }
        updateUndoRedoUI()
    }
    
    // MARK: - Private Logic
    
    private func switchToViewMode() {
        if modeManager.currentMode != .view {
            changeMode(to: .view)
            // Notify delegate if needed, or let the caller handle UI updates
        }
    }
    
    private func changeMode(to mode: ModeManager.AppMode, completion: (() -> Void)? = nil) {
        // IMPORTANT: Ensure we know the correct page index before doing anything
        // This fixes the issue where scrolling in View Mode (Fake View) updates PDFView
        // but might leave currentPageIndex stale if the notification handler lags.
        updatePageIndex()
        
        print("\n🔀🔀🔀 PDFAnnotatorEngine: Changing mode from \(modeManager.currentMode) to \(mode) on page \(currentPageIndex)")
        print("   📐 BEFORE MODE SWITCH:")
        if let page = annotatorView.pdfView.currentPage {
            let pageFrame = annotatorView.pdfView.convert(page.bounds(for: .mediaBox), from: page)
            print("      PDF Page bounds: \(page.bounds(for: .mediaBox))")
            print("      PDF Page frame in view: \(pageFrame)")
        }
        print("      Canvas frame: \(annotatorView.canvasView.frame)")
        print("      Canvas bounds: \(annotatorView.canvasView.bounds)")
        
        // CRITICAL: Set flag to prevent page change handler from saving with wrong bounds
        isSwitchingModes = true
        
        // 1. Save current state
        saveCurrentPageData()
        
        // 2. Perform switch (generates temp PDF)
        modeManager.switchMode(to: mode, currentPage: self.currentPageIndex)
        
        print("   📐 AFTER MODE SWITCH (before frame update):")
        if let page = annotatorView.pdfView.currentPage {
            let pageFrame = annotatorView.pdfView.convert(page.bounds(for: .mediaBox), from: page)
            print("      PDF Page bounds: \(page.bounds(for: .mediaBox))")
            print("      PDF Page frame in view: \(pageFrame)")
        }
        print("      Canvas frame: \(annotatorView.canvasView.frame)")
        print("      Canvas bounds: \(annotatorView.canvasView.bounds)")
        
        // NEW: Force Fit-to-Width/Page robustness
        annotatorView.pdfView.autoScales = true
        
        // 3. Update UI State (Show views)
        updateUI(for: mode)
        
        // 4. CRITICAL FIX: Update canvas frame BEFORE loading data
        // This ensures canvas bounds are correct when drawings are loaded
        // Prevents annotation position drift when switching modes
        updateCanvasFrame(reloadOnResize: false)
        
        print("   📐 AFTER FRAME UPDATE (before loading data):")
        if let page = annotatorView.pdfView.currentPage {
            let pageFrame = annotatorView.pdfView.convert(page.bounds(for: .mediaBox), from: page)
            print("      PDF Page bounds: \(page.bounds(for: .mediaBox))")
            print("      PDF Page frame in view: \(pageFrame)")
        }
        print("      Canvas frame: \(annotatorView.canvasView.frame)")
        print("      Canvas bounds: \(annotatorView.canvasView.bounds)")
        
        // 5. CRITICAL FIX FOR iOS 16: Delay loading to allow UI layout to settle
        // The toolbar show/hide causes the PDF view to shift, which changes the canvas frame position
        // We need to wait for the layout to complete before loading drawings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            print("   📐 DELAYED FRAME UPDATE (after UI settled):")
            if let page = self.annotatorView.pdfView.currentPage {
                let pageFrame = self.annotatorView.pdfView.convert(page.bounds(for: .mediaBox), from: page)
                print("      PDF Page frame in view: \(pageFrame)")
            }
            print("      Canvas frame: \(self.annotatorView.canvasView.frame)")
            
            // Update frame one more time after UI has settled
            self.updateCanvasFrame(reloadOnResize: false)
            
            // Now load data with the correct frame
            self.loadCurrentPageData()
            
            // Clear the mode switching flag
            self.isSwitchingModes = false
            
            print("✅ PDFAnnotatorEngine: Mode switch complete\n")
            
            // Call completion handler after mode switch is fully complete
            completion?()
        }
    }
    
    private func updateUI(for mode: ModeManager.AppMode) {
        let isDrawing = mode == .editDrawings
        let isSigning = mode == .editSignatures
        let isView = mode == .view
        
        annotatorView.pdfView.isUserInteractionEnabled = (mode == .view)
        
        annotatorView.canvasView.isHidden = !isDrawing
        annotatorView.canvasView.isUserInteractionEnabled = isDrawing
        
        // Signature container should allow touches only on subviews (signatures)
        // But we can toggle visibility of signatures
        signatureManager.setSignaturesHidden(!isSigning)
        annotatorView.signatureContainerView.isUserInteractionEnabled = isSigning
        
        if isDrawing {
            annotatorView.canvasView.becomeFirstResponder()
            // annotatorView.canvasView.drawingGestureRecognizer.isEnabled = true // REMOVED: Managed by setDrawingEnabled
            delegate?.annotatorEngine(self, didToggleDrawing: true)
        } else if isView {
            annotatorView.canvasView.drawingGestureRecognizer.isEnabled = false
            delegate?.annotatorEngine(self, didToggleDrawing: false)
        }
    }
    
    private func saveCurrentPageData() {
        // Skip if we're in the middle of handling rotation and already saved
        if isHandlingRotation {
            print("⏭️ PDFAnnotatorEngine: Skipping duplicate save during rotation")
            return
        }
        
        performSave()
    }
    
    // Internal save that bypasses rotation guard - used for post-rotation save
    private func performSave() {
        print("💾 PDFAnnotatorEngine: Saving page \(currentPageIndex) data (mode: \(modeManager.currentMode))")
        if modeManager.currentMode == .editDrawings {
            print("   Canvas bounds: \(annotatorView.canvasView.bounds)")
            print("   Canvas frame: \(annotatorView.canvasView.frame)")
            drawingManager.saveDrawing(from: annotatorView.canvasView, at: currentPageIndex)
        } else if modeManager.currentMode == .editSignatures {
            signatureManager.saveSignatures(from: annotatorView.signatureContainerView, pdfView: annotatorView.pdfView, at: currentPageIndex)
        }
        updateUndoRedoUI()
    }
    
    private func loadCurrentPageData() {
        print("📂📂📂 PDFAnnotatorEngine: Loading page \(currentPageIndex) data (mode: \(modeManager.currentMode))")
        let wasDelegate = annotatorView.canvasView.delegate
        annotatorView.canvasView.delegate = nil
        
        drawingManager.clearCanvas(annotatorView.canvasView)
        
        if modeManager.currentMode == .editDrawings {
            print("   📐 BEFORE LOADING DRAWING:")
            print("      Canvas bounds: \(annotatorView.canvasView.bounds)")
            print("      Canvas frame: \(annotatorView.canvasView.frame)")
            if let page = annotatorView.pdfView.currentPage {
                let pageFrame = annotatorView.pdfView.convert(page.bounds(for: .mediaBox), from: page)
                print("      PDF Page frame: \(pageFrame)")
            }
            
            drawingManager.loadDrawing(into: annotatorView.canvasView, at: currentPageIndex)
            
            print("   📐 AFTER LOADING DRAWING:")
            print("      Drawing loaded with \(annotatorView.canvasView.drawing.strokes.count) strokes")
            if annotatorView.canvasView.drawing.strokes.count > 0 {
                let bounds = annotatorView.canvasView.drawing.bounds
                print("      Drawing bounds: \(bounds)")
            }
        } else if modeManager.currentMode == .editSignatures {
            signatureManager.loadSignatures(into: annotatorView.signatureContainerView, pdfView: annotatorView.pdfView, at: currentPageIndex)
        }
        
        annotatorView.canvasView.delegate = wasDelegate
        updateUndoRedoUI()
    }
    
    private func updateUndoRedoUI() {
        let manager = drawingManager.undoManager(for: currentPageIndex)
        delegate?.annotatorEngine(self, didChangeUndoRedoState: manager.canUndo, canRedo: manager.canRedo)
    }
    
    private func updateDrawingWithoutNotifying(_ block: () -> Void) {
        annotatorView.canvasView.delegate = nil
        block()
        annotatorView.canvasView.delegate = self
    }
    
    private func performUndoRedoAction(action: () -> Void) {
        let wasInViewMode = (modeManager.currentMode == .view)
        
        if wasInViewMode {
            annotatorView.canvasView.delegate = nil
            
            modeManager.switchMode(to: .editDrawings, currentPage: currentPageIndex)
            updateUI(for: .editDrawings)
            
            self.drawingManager.loadDrawing(into: self.annotatorView.canvasView, at: currentPageIndex)

            annotatorView.canvasView.delegate = self
        }
        
        action()
        
        if wasInViewMode {
            annotatorView.canvasView.delegate = nil
            drawingManager.saveDrawing(from: annotatorView.canvasView, at: currentPageIndex)
            annotatorView.canvasView.delegate = self
            
            modeManager.switchMode(to: .view, currentPage: currentPageIndex)
            updateUI(for: .view)
            
            annotatorView.canvasView.drawingGestureRecognizer.isEnabled = false
        }
    }
    
    // MARK: - Event Handlers
    
    @objc private func handlePageChange() {
        previousPageIndex = currentPageIndex
        updatePageIndex()
        
        print("\n📄 PDFAnnotatorEngine: Page change detected")
        print("   Previous page: \(previousPageIndex) → Current page: \(currentPageIndex)")
        print("   Current mode: \(modeManager.currentMode)")
        print("   Is switching modes: \(isSwitchingModes)")
        
        if previousPageIndex != currentPageIndex {
            // 1. Save previous page data BEFORE canvas frame changes
            // CRITICAL: Only save in edit mode. In view mode, drawings are baked into PDF.
            // CRITICAL: Don't save during mode switches - canvas bounds are being updated!
            if modeManager.currentMode == .editDrawings && !isSwitchingModes {
                print("   💾 Saving previous page \(previousPageIndex) BEFORE canvas resize")
                print("      Current canvas bounds (for page \(previousPageIndex)): \(annotatorView.canvasView.bounds)")
                drawingManager.saveDrawing(from: annotatorView.canvasView, at: previousPageIndex)
            } else if isSwitchingModes {
                print("   ⏭️ Skipping save during mode switch - canvas bounds are transitioning")
            } else {
                print("   ⏭️ Skipping save in \(modeManager.currentMode) mode - drawings are in PDF")
            }
            
            // 2. Clear canvas to prevent rendering issues during frame update
            // IMPORTANT: Disable delegate to prevent empty drawing from polluting undo manager
            let wasDelegate = annotatorView.canvasView.delegate
            annotatorView.canvasView.delegate = nil
            drawingManager.clearCanvas(annotatorView.canvasView)
            annotatorView.canvasView.delegate = wasDelegate
        }
        
        // 3. Update canvas frame to match NEW page
        // Pass false to avoid reloading, as we will load the new page data explicitly below
        updateCanvasFrame(reloadOnResize: false)
        
        if previousPageIndex != currentPageIndex {
            // 4. Load new page data into the correctly sized canvas
            loadCurrentPageData()
            delegate?.annotatorEngine(self, didChangePage: currentPageIndex)
        }
        
        print("✅ Page change complete\n")
    }
    
    private func updatePageIndex() {
        if let page = annotatorView.pdfView.currentPage, let doc = annotatorView.pdfView.document {
            currentPageIndex = doc.index(for: page)
        }
    }
    
    @objc private func handleVisiblePagesChanged() {
        // This notification fires when PDFKit finishes laying out visible pages (e.g. after zoom or load)
        // It is the most reliable "Layout Ready" signal.
        print("👁️ PDFAnnotatorEngine: Visible Pages Changed (Layout Ready)")
        updateCanvasFrame(reloadOnResize: false)
    }
    
    @objc private func handleScaleChange() {
        // Debounce: Cancel any pending rotation handling
        rotationWorkItem?.cancel()
        
        guard !isHandlingRotation else {
            print("⏭️ PDFAnnotatorEngine: Skipping redundant scale change")
            return
        }
        
        // Only handle in edit mode - view mode doesn't need special handling
        guard modeManager.currentMode == .editDrawings else {
            updateCanvasFrame(reloadOnResize: false)
            return
        }
        
        print("📐 PDFAnnotatorEngine: Scale change detected in edit mode")
        
        // Mark that we're handling rotation
        isHandlingRotation = true
        
        // NO save before rotation - we'll save after with new bounds
        
        // Create a work item for the actual frame update
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Update frame to new size
            self.updateCanvasFrame(reloadOnResize: true)
            
            // IMPORTANT: Save after rotation to update drawingsByPage with new bounds
            // Use performSave() to bypass the rotation guard
            self.performSave()
            
            // Reset flag after a short delay to allow all updates to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isHandlingRotation = false
                print("✅ PDFAnnotatorEngine: Rotation handling complete")
            }
        }
        
        rotationWorkItem = workItem
        
        // Execute the frame update after a tiny delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
    
    private func updateCanvasFrame(reloadOnResize: Bool) {
        // Guard: Skip if no document is loaded yet
        guard annotatorView.pdfView.document != nil else {
            // Silently skip - this is normal during initial view setup
            return
        }
        
        print("📐📐📐 PDFAnnotatorEngine: updateCanvasFrame called (reloadOnResize: \(reloadOnResize))")
        
        guard let page = annotatorView.pdfView.currentPage else {
            print("   ⚠️ No current page, setting frames to zero")
            annotatorView.canvasView.frame = .zero
            annotatorView.signatureContainerView.frame = .zero
            return
        }
        
        // Get the current page frame in PDFView coordinates
        let pageFrame = annotatorView.pdfView.convert(page.bounds(for: .mediaBox), from: page)
        print("   PDF Page bounds (mediaBox): \(page.bounds(for: .mediaBox))")
        print("   PDF Page frame in view coordinates: \(pageFrame)")
        print("   Current canvas frame: \(annotatorView.canvasView.frame)")
        
        if !annotatorView.canvasView.frame.equalTo(pageFrame) {
            let oldFrame = annotatorView.canvasView.frame
            
            // Update frame to match PDF page position and size
            annotatorView.canvasView.frame = pageFrame
            
            // Explicitly set bounds to ensure coordinate system matches
            annotatorView.canvasView.bounds = CGRect(origin: .zero, size: pageFrame.size)
            
            print("   ✅ Canvas frame UPDATED:")
            print("      Old frame: \(oldFrame)")
            print("      New frame: \(pageFrame)")
            print("      New bounds: \(annotatorView.canvasView.bounds)")
            
            // If we're in drawing mode and the frame changed (e.g., rotation), reload to rescale
            if reloadOnResize && modeManager.currentMode == .editDrawings && !oldFrame.isEmpty {
                print("   🔄 PDFAnnotatorEngine: Reloading drawing for new canvas size")
                // Disable delegate to prevent undo stack additions during reload
                let wasDelegate = annotatorView.canvasView.delegate
                annotatorView.canvasView.delegate = nil
                
                loadCurrentPageData()
                
                // Re-enable delegate
                annotatorView.canvasView.delegate = wasDelegate
            }
        } else {
            print("   ℹ️ Canvas frame already matches page frame, no update needed")
        }
        
        // NEW: Reactive Layout Update
        // Ensure signatures track the PDF frame continuously
        if modeManager.currentMode == .editSignatures {
            signatureManager.refreshLayout(pdfView: annotatorView.pdfView, view: annotatorView.signatureContainerView)
        }
    }
}

// MARK: - PKCanvasViewDelegate
extension PDFAnnotatorEngine: PKCanvasViewDelegate {
    public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard modeManager.currentMode == .editDrawings else { return }
        
        drawingManager.updateUndoStack(for: currentPageIndex, with: canvasView.drawing, canvasBounds: canvasView.bounds)
        
        DispatchQueue.main.async {
            self.updateUndoRedoUI()
        }
    }
}
