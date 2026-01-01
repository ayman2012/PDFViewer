//
//  NewPDFViewerVC.swift
//  Moamalat-App
//
//  Created by AI Assistant on 10/12/2024.
//

import UIKit
import PDFKit
import PencilKit

// MARK: - Protocols (for AttachmentsIpadVC compatibility)

@objc protocol ViewerProtocol: AnyObject {
    func startPinEditing()
    func startEditWithAnnotation()
    func SaveChanges()
    func startStampOption(_ isStamp: Bool, _ isSign: Bool)
}

@objc protocol ViewerToAttachmentProtocol: AnyObject {
    func endEditAnnotationn()
    func uploadAnnotationAttachment(_ isStamp: Bool)
}

// MARK: - Main ViewController

class NewPDFViewerVC: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var toolsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var topbarheightConstrain: NSLayoutConstraint!
    @IBOutlet weak var pdfContainerView: UIView!
    @IBOutlet weak var topSaveCancelBar: UIView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var toolbarContainerView: UIView!
    
    // MARK: - Properties
    
    private var annotatorEngine: PDFAnnotatorEngine!
    private var toolbarManager: ToolbarManager!
    private var toolbarView: DefaultToolbarView!
    private var annotatorView: PDFAnnotatorView!
    
    weak var parentdelegate: ViewerToAttachmentProtocol?
    var shouldEnableAnnotation: Bool = false

    private var currentMode: PDFViewMode = .view
    private var pdfDocumentURL: URL?
    private var isStampMode: Bool = false
    private var isSignMode: Bool = false
    
    enum PDFViewMode {
        case view
        case annotation
        case signature
        case stamp
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPDFEngine()
        setupToolbar()
        setupSaveCancelBar()
        
        // Check if a PDF was queued for loading before view loaded
        if let url = pdfDocumentURL {
            print("📄 Loading queued PDF from: \(url.lastPathComponent)")
            annotatorEngine.loadPDF(url: url)
        }
        
        if shouldEnableAnnotation {
            enterAnnotationMode()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Engine handles layout updates via its view's layoutSubviews
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup right button panel styling
        
        // Setup save/cancel bar styling
        topSaveCancelBar?.backgroundColor = UIColor(white: 0.95, alpha: 0.95)
        topSaveCancelBar?.layer.shadowColor = UIColor.black.cgColor
        topSaveCancelBar?.layer.shadowOffset = CGSize(width: 0, height: 2)
        topSaveCancelBar?.layer.shadowRadius = 4
        topSaveCancelBar?.layer.shadowOpacity = 0.2
    }
    
    private func setupPDFEngine() {
        // Create PDFAnnotatorView and add to container
        annotatorView = PDFAnnotatorView(frame: pdfContainerView.bounds)
        annotatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pdfContainerView.insertSubview(annotatorView, at: 0)
        
        // Initialize PDFAnnotatorEngine
        annotatorEngine = PDFAnnotatorEngine(view: annotatorView)
        annotatorEngine.delegate = self
    }
    
    private func setupToolbar() {
        // Initialize ToolbarManager (logic)
        toolbarManager = ToolbarManager()
        toolbarManager.delegate = self
        
        // Initialize DefaultToolbarView (UI)
        toolbarView = DefaultToolbarView(manager: toolbarManager)
        toolbarView.delegate = self
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainerView.addSubview(toolbarView)
        
        NSLayoutConstraint.activate([
            toolbarView.leadingAnchor.constraint(equalTo: toolbarContainerView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: toolbarContainerView.trailingAnchor),
            toolbarView.topAnchor.constraint(equalTo: toolbarContainerView.topAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: toolbarContainerView.bottomAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Initially hide toolbar (shown when entering edit mode)
        toolbarContainerView.isHidden = true
        toolsHeightConstraint.constant = 0
    }
    
    private func setupSaveCancelBar() {
        // Initially hide the save/cancel bar
        hideSaveCancelBar(animated: false)
        
        // Setup button titles (RTL support)
        saveButton?.setTitle("حفظ", for: .normal)
        cancelButton?.setTitle("إلغاء", for: .normal)
        
        // Setup button styling
        saveButton?.backgroundColor = .systemBlue
        saveButton?.setTitleColor(.white, for: .normal)
        saveButton?.layer.cornerRadius = 8
        
        cancelButton?.backgroundColor = .systemGray
        cancelButton?.setTitleColor(.white, for: .normal)
        cancelButton?.layer.cornerRadius = 8
    }
    
    // MARK: - Public API for PDF Loading
    
    func loadPDF(from path: String) {
        pdfDocumentURL = URL(fileURLWithPath: path)
        if isViewLoaded {
            annotatorEngine.loadPDF(fromPath: path)
        }
    }
    
    func loadPDF(from data: Data) {
        // Store data in temp file for re-loading if needed
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_pdf_\(UUID().uuidString).pdf")
        try? data.write(to: tempURL)
        pdfDocumentURL = tempURL
        
        if isViewLoaded {
            annotatorEngine.loadPDF(fromData: data)
        }
    }
    
    func loadPDF(from url: URL) {
        pdfDocumentURL = url
        if isViewLoaded {
            annotatorEngine.loadPDF(url: url)
        }
    }
    
    // MARK: - Public Reset API
    
    public func resetAllChanges() {
        annotatorEngine.resetAllChanges()
        hideSaveCancelBar(animated: true)
        enterViewMode()
    }
    
    // MARK: - Mode Management
    
    private func enterViewMode() {
        currentMode = .view
        annotatorEngine.setMode(.view)
        toolbarContainerView.isHidden = true
        toolsHeightConstraint.constant = 0
        hideSaveCancelBar(animated: true)
    }
    private func enterFakeViewMode() {
        currentMode = .view
        annotatorEngine.setMode(.view)
        toolbarContainerView.isHidden = false
        toolsHeightConstraint.constant = 60
        showSaveCancelBar(animated: true)
    }
    
    private func enterAnnotationMode() {
        currentMode = .annotation
        annotatorEngine.setMode(.editDrawings)
        toolbarContainerView.isHidden = false
        toolsHeightConstraint.constant = 60
        showSaveCancelBar(animated: true)
    }
    
    private func enterSignatureMode(isSign: Bool) {
        currentMode = .signature
        isSignMode = true
        isStampMode = true
        toolbarContainerView.isHidden = true // Signature mode doesn't need drawing toolbar
        toolsHeightConstraint.constant = 0
        showSaveCancelBar(animated: true)
        addSignatureTapped(isSign: isSign)
    }
    
    private func enterStampMode(isSign: Bool) {
        currentMode = .stamp
        isSignMode = isSign
        isStampMode = true
        toolbarContainerView.isHidden = true
        toolsHeightConstraint.constant = 0
        showSaveCancelBar(animated: true)
        addSignatureTapped(isSign: isSign)
    }
    @objc private func addSignatureTapped(isSign: Bool) {
        guard let image = UserDefaults.standard.imageForKey(key: isSign ? "SignImage" : "MarkImage") else { return }
        
        // CRITICAL FIX: Wait for mode switch to complete before adding signature
        // This prevents the signature from being cleared by loadCurrentPageData()
        annotatorEngine.setMode(.editSignatures) { [weak self] in
            self?.annotatorEngine.addSignature(image: image)
        }
    }
    // MARK: - Save/Cancel Bar Animation
    
    private func showSaveCancelBar(animated: Bool) {
        topbarheightConstrain.constant = 60
        topSaveCancelBar.isHidden = false
    }
    
    private func hideSaveCancelBar(animated: Bool) {
        topbarheightConstrain.constant = 0
        topSaveCancelBar.isHidden = true
        
    }
    
    // MARK: - Save/Cancel Actions
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        handleSave()
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        handleCancel()
    }
    
    
    private func handleSave() {
        guard let pdfData = annotatorEngine.exportPDF() else {
            print("❌ Failed to export PDF")
            // Show error to user
            let alert = UIAlertController(title: "خطأ", message: "فشل حفظ التعديلات", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "حسناً", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Save the exported PDF back to the original location if possible
        if let url = pdfDocumentURL {
            do {
                try pdfData.write(to: url)
                print("✅ PDF saved successfully to: \(url)")
                NotificationCenter.default.post(
                    name: .pdfDidSave,
                    object: nil,
                    userInfo: [
                        "pdfPath": url.path,
                        "isStamp": isStampMode
                    ]
                )
                
                // Notify parent delegate
                parentdelegate?.uploadAnnotationAttachment(isStampMode)
                
                // Hide UI and return to view mode
                hideSaveCancelBar(animated: true)
                enterViewMode()
            } catch {
                print("⚠️ Could not write PDF to original location: \(error)")
            }
        }
    }

    private func showSaveError() {
        let alert = UIAlertController(
            title: "خطأ",
            message: "فشل حفظ التعديلات",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "حسناً", style: .default))
        present(alert, animated: true)
    }
    private func handleCancel() {
        // Reset all changes (drawings and signatures)
        resetAllChanges()
        
        // Notify parent delegate
        parentdelegate?.endEditAnnotationn()
        
        // Reset stamp flags
        isStampMode = false
        isSignMode = false
    }
}

// MARK: - ViewerProtocol Conformance

extension NewPDFViewerVC: ViewerProtocol {
    
    func startPinEditing() {
        // Placeholder - not currently used in the system
        print("⚠️ Pin editing not implemented")
    }
    
    func startEditWithAnnotation() {
        print("📝 Starting annotation mode")
        enterAnnotationMode()
    }
    
    func SaveChanges() {
        print("💾 Saving changes")
        handleSave()
    }
    
    func startStampOption(_ isStamp: Bool, _ isSign: Bool) {
        print("🖊️ Starting stamp/sign mode - isStamp: \(isStamp), isSign: \(isSign)")
        
        if isSign {
            enterSignatureMode(isSign: isSign)
        } else {
            enterStampMode(isSign: false)
        }
    }
}

// MARK: - ViewerToAttachmentProtocol Conformance

extension NewPDFViewerVC: ViewerToAttachmentProtocol {
    
    func endEditAnnotationn() {
        print("🔚 Ending edit annotation")
        enterViewMode()
    }
    
    func uploadAnnotationAttachment(_ isStamp: Bool) {
        print("📤 Upload annotation attachment - isStamp: \(isStamp)")
        // This is called by parent when upload should be triggered
        // The actual upload is handled by the parent (AttachmentsIpadVC)
    }
}

// MARK: - ToolbarManagerDelegate

extension NewPDFViewerVC: ToolbarManagerDelegate {
    
    func didChangeTool(_ tool: PKInkingTool) {
        annotatorEngine.setTool(tool)
    }
    
    func didSelectEraser() {
        annotatorEngine.setEraser()
    }
    
    func didTapUndo() {
        annotatorEngine.undo()
    }
    
    func didTapRedo() {
        annotatorEngine.redo()
    }
    
    func didToggleDrawing(enabled: Bool) {
        if enabled {
            // Ensure we are in annotation mode if not already
            if currentMode != .annotation {
                enterAnnotationMode()
            }
            // Explicitly enable drawing gesture when tool is selected
            annotatorEngine.setDrawingEnabled(true)
        } else {
            // User deselected all tools -> Switch to view mode
            if currentMode != .view {
                enterFakeViewMode()
            }
        }
    }
    
    func didUpdateUndoRedoState(canUndo: Bool, canRedo: Bool) {
        toolbarView.updateUndoRedoState(canUndo: canUndo, canRedo: canRedo)
    }
}

// MARK: - DefaultToolbarViewDelegate

extension NewPDFViewerVC: DefaultToolbarViewDelegate {
    
    func toolbarView(_ view: DefaultToolbarView, didSelectTool type: ToolbarManager.ToolType) {
        toolbarManager.selectTool(type)
    }
    
    func toolbarView(_ view: DefaultToolbarView, didToggleDrawing enabled: Bool) {
        if !enabled {
            toolbarManager.deselectTools()
        }
    }
    
    func toolbarViewDidTapUndo(_ view: DefaultToolbarView) {
        toolbarManager.performUndo()
    }
    
    func toolbarViewDidTapRedo(_ view: DefaultToolbarView) {
        toolbarManager.performRedo()
    }
    
    func toolbarView(_ view: DefaultToolbarView, didUpdateToolSettings type: ToolbarManager.ToolType, color: UIColor, width: CGFloat) {
        toolbarManager.updateToolSettings(type: type, color: color, width: width)
    }
}

// MARK: - PDFAnnotatorEngineDelegate

extension NewPDFViewerVC: PDFAnnotatorEngineDelegate {
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangeUndoRedoState canUndo: Bool, canRedo: Bool) {
        toolbarManager.setUndoRedoState(canUndo: canUndo, canRedo: canRedo)
    }
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangeTool tool: PKInkingTool) {
        // Bi-directional sync if needed
    }
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangePage pageIndex: Int) {
        print("📄 Page changed to: \(pageIndex)")
        // Update page indicator if needed
    }
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didToggleDrawing enabled: Bool) {
        // Update UI if needed
    }
}
