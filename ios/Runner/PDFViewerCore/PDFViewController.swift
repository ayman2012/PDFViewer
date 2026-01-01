import UIKit
import PDFKit
import PencilKit

class PDFViewController: UIViewController {

    // MARK: - Properties
    
    private var annotatorEngine: PDFAnnotatorEngine!
    private var toolbarManager: ToolbarManager!
    private var toolbarView: DefaultToolbarView!
    private var addSignatureButton: UIBarButtonItem?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupEngine()
        setupToolbar()
        loadDocument()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Engine handles layout updates via its view's layoutSubviews
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Navigation
        let modeControl = UISegmentedControl(items: ["View", "Draw", "Sign"])
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        navigationItem.titleView = modeControl
        
        addSignatureButton = UIBarButtonItem(
            image: UIImage(systemName: "signature"),
            style: .plain,
            target: self,
            action: #selector(addSignatureTapped)
        )
        navigationItem.rightBarButtonItems = [addSignatureButton!]
        
        // Export Button
        setupExportButton()
    }
    
    private func setupEngine() {
        // Create the view
        let annotatorView = PDFAnnotatorView(frame: view.bounds)
        annotatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(annotatorView, at: 0) // Add at bottom
        
        // Create the engine
        annotatorEngine = PDFAnnotatorEngine(view: annotatorView)
        annotatorEngine.delegate = self
    }
    
    private func setupToolbar() {
        // 1. Initialize Logic
        toolbarManager = ToolbarManager()
        toolbarManager.delegate = self
        
        // 2. Initialize UI
        toolbarView = DefaultToolbarView(manager: toolbarManager)
        toolbarView.delegate = self
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbarView)
        
        NSLayoutConstraint.activate([
            toolbarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            toolbarView.heightAnchor.constraint(equalToConstant: 50),
            toolbarView.widthAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
        
        toolbarView.isHidden = false 
    }
    
    private func loadDocument() {
//        annotatorEngine.loadPDF(resource: "viewport_test", withExtension: "pdf")
    }
    
    private func setupExportButton() {
        let exportButton = UIButton(type: .system)
        exportButton.setTitle("Share PDF", for: .normal)
        exportButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        exportButton.backgroundColor = .white
        exportButton.layer.cornerRadius = 10.0
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exportButton)
        NSLayoutConstraint.activate([
            exportButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            exportButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            exportButton.heightAnchor.constraint(equalToConstant: 50),
            exportButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            toolbarManager.deselectTools()
            toolbarView.deselectAll()
            annotatorEngine.setMode(.view)
        case 1:
            annotatorEngine.setMode(.editDrawings)
        case 2:
            annotatorEngine.setMode(.editSignatures)
        default: break
        }
    }
    
    @objc private func addSignatureTapped() {
        annotatorEngine.setMode(.editSignatures)
        guard let image = UIImage(named: "signature") else { return }
        annotatorEngine.addSignature(image: image)
    }
    
    @objc private func exportTapped() {
        guard let data = annotatorEngine.exportPDF() else { return }
        let activityVC = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
    }
}

// MARK: - ToolbarManagerDelegate (Model/Logic Updates)
extension PDFViewController: ToolbarManagerDelegate {
    
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
            if let segment = navigationItem.titleView as? UISegmentedControl, segment.selectedSegmentIndex != 1 {
                segment.selectedSegmentIndex = 1
                annotatorEngine.setMode(.editDrawings)
            }
            // Explicitly enable drawing gesture when tool is selected
            annotatorEngine.setDrawingEnabled(true)
        } else {
             if let segment = navigationItem.titleView as? UISegmentedControl, segment.selectedSegmentIndex != 0 {
                segment.selectedSegmentIndex = 0
                annotatorEngine.setMode(.view)
            }
        }
    }
    
    func didUpdateUndoRedoState(canUndo: Bool, canRedo: Bool) {
        toolbarView.updateUndoRedoState(canUndo: canUndo, canRedo: canRedo)
    }
}

// MARK: - DefaultToolbarViewDelegate (UI Events)
extension PDFViewController: DefaultToolbarViewDelegate {
    
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
extension PDFViewController: PDFAnnotatorEngineDelegate {
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangeUndoRedoState canUndo: Bool, canRedo: Bool) {
        toolbarManager.setUndoRedoState(canUndo: canUndo, canRedo: canRedo)
    }
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangeTool tool: PKInkingTool) {
        // Update toolbar UI if needed (bi-directional sync)
    }
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didChangePage pageIndex: Int) {
        // Handle page change if needed
    }
    
    func annotatorEngine(_ engine: PDFAnnotatorEngine, didToggleDrawing enabled: Bool) {
        toolbarView.isHidden = false
    }
}
