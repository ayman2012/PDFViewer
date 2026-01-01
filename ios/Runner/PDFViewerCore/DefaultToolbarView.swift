//
//  DefaultToolbarView.swift
//  SignatureAppDemo
//
//  Created by ahmed on 03/12/2025.
//

import UIKit
import PencilKit

protocol DefaultToolbarViewDelegate: AnyObject {
    func toolbarView(_ view: DefaultToolbarView, didSelectTool type: ToolbarManager.ToolType)
    func toolbarView(_ view: DefaultToolbarView, didToggleDrawing enabled: Bool)
    func toolbarViewDidTapUndo(_ view: DefaultToolbarView)
    func toolbarViewDidTapRedo(_ view: DefaultToolbarView)
    func toolbarView(_ view: DefaultToolbarView, didUpdateToolSettings type: ToolbarManager.ToolType, color: UIColor, width: CGFloat)
}

class DefaultToolbarView: UIView, ToolOptionsDelegate {
    
    weak var delegate: DefaultToolbarViewDelegate?
    private weak var manager: ToolbarManager?
    
    // UI Components
    private let stackView = UIStackView()
    private let penButton = UIButton(type: .system)
    private let highlighterButton = UIButton(type: .system)
    private let eraserButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    
    private var toolButtons: [UIButton] = []
    private var selectedButton: UIButton?
    
    // Local state for options
    private var currentPenColor: UIColor = .black
    private var currentPenWidth: CGFloat = 5
    private var currentHighlighterColor: UIColor = .yellow
    private var currentHighlighterWidth: CGFloat = 20
    
    // Helper to handle the delegate callback ambiguity
    private var editingToolType: ToolbarManager.ToolType = .pen 
    
    init(manager: ToolbarManager) {
        self.manager = manager
        super.init(frame: .zero)
        setupUI()
        setupActions()
        updateFromManager()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Style
        backgroundColor = UIColor.white.withAlphaComponent(0.9)
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 5
        
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium, scale: .large)
        
        // Buttons
        undoButton.setImage(UIImage(systemName: "arrow.uturn.backward", withConfiguration: largeConfig), for: .normal)
        penButton.setImage(UIImage(systemName: "pencil.tip", withConfiguration: largeConfig), for: .normal)
        highlighterButton.setImage(UIImage(systemName: "highlighter", withConfiguration: largeConfig), for: .normal)
        eraserButton.setImage(UIImage(systemName: "eraser.line.dashed", withConfiguration: largeConfig), for: .normal)
        redoButton.setImage(UIImage(systemName: "arrow.uturn.forward", withConfiguration: largeConfig), for: .normal)
        
        undoButton.tintColor = .lightGray
        redoButton.tintColor = .lightGray
        
        // Stack
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 5
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        
        [undoButton, penButton, highlighterButton, eraserButton, redoButton].forEach {
            stackView.addArrangedSubview($0)
            $0.tintColor = .darkGray
            $0.backgroundColor = .clear
            $0.layer.cornerRadius = 8
        }
        
        toolButtons = [penButton, highlighterButton, eraserButton]
        
        penButton.tag = 0
        highlighterButton.tag = 1
        eraserButton.tag = 2
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    private func setupActions() {
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        redoButton.addTarget(self, action: #selector(redoTapped), for: .touchUpInside)
        
        toolButtons.forEach {
            $0.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
        }
        
        // Long press
        let penLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        penButton.addGestureRecognizer(penLongPress)
        
        let hlLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        highlighterButton.addGestureRecognizer(hlLongPress)
    }
    
    // MARK: - Actions
    
    @objc private func undoTapped() {
        delegate?.toolbarViewDidTapUndo(self)
    }
    
    @objc private func redoTapped() {
        delegate?.toolbarViewDidTapRedo(self)
    }
    
    @objc private func toolTapped(_ sender: UIButton) {
        if sender == selectedButton {
            // Deselect
            updateSelectionUI(nil)
            delegate?.toolbarView(self, didToggleDrawing: false)
            return
        }
        
        updateSelectionUI(sender)
        delegate?.toolbarView(self, didToggleDrawing: true)
        
        switch sender.tag {
        case 0: delegate?.toolbarView(self, didSelectTool: .pen)
        case 1: delegate?.toolbarView(self, didSelectTool: .highlighter)
        case 2: delegate?.toolbarView(self, didSelectTool: .eraser)
        default: break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let button = gesture.view as? UIButton else { return }
        
        let optionsVC: ToolOptionsViewController
        let isPen = (button == penButton)
        
        if isPen {
            let color = manager?.currentPenColor ?? .black
            let width = manager?.currentPenWidth ?? 5
            optionsVC = ToolOptionsViewController(color: color, width: width, minWidth: 1, maxWidth: 30)
            setEditingTool(.pen)
        } else {
            let color = manager?.currentHighlighterColor ?? .yellow
            let width = manager?.currentHighlighterWidth ?? 20
            optionsVC = ToolOptionsViewController(color: color, width: width, minWidth: 10, maxWidth: 50)
            setEditingTool(.highlighter)
        }
        
        optionsVC.view.tag = isPen ? 0 : 1
        optionsVC.delegate = self
        if let sheet = optionsVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        if let parentVC = self.findViewController() {
            parentVC.present(optionsVC, animated: true)
        }
    }
    
    func setEditingTool(_ type: ToolbarManager.ToolType) {
        self.editingToolType = type
    }
    
    // MARK: - Public Updates
    
    func updateUndoRedoState(canUndo: Bool, canRedo: Bool) {
        undoButton.isEnabled = canUndo
        undoButton.tintColor = canUndo ? .systemBlue : .lightGray
        
        redoButton.isEnabled = canRedo
        redoButton.tintColor = canRedo ? .systemBlue : .lightGray
    }
    
    func deselectAll() {
        updateSelectionUI(nil)
    }
    
    // MARK: - Private
    
    private func updateSelectionUI(_ selected: UIButton?) {
        selectedButton = selected
        
        toolButtons.forEach {
            $0.backgroundColor = .clear
            $0.tintColor = .darkGray
        }
        
        if let selected = selected {
            selected.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            selected.tintColor = .systemBlue
        }
    }
    
    private func updateFromManager() {
        guard let manager = manager else { return }
        self.currentPenColor = manager.currentPenColor
        self.currentPenWidth = manager.currentPenWidth
        self.currentHighlighterColor = manager.currentHighlighterColor
        self.currentHighlighterWidth = manager.currentHighlighterWidth
    }
    
    private func findViewController() -> UIViewController? {
        var nextResponder: UIResponder? = self
        while let responder = nextResponder {
            if let vc = responder as? UIViewController {
                return vc
            }
            nextResponder = responder.next
        }
        return nil
    }
    
    // MARK: - ToolOptionsDelegate
    
    func toolOptionsDidChangeColor(_ color: UIColor) {
        if editingToolType == .pen {
            currentPenColor = color
        } else if editingToolType == .highlighter {
            currentHighlighterColor = color
        }
        
        let width = (editingToolType == .pen) ? currentPenWidth : currentHighlighterWidth
        delegate?.toolbarView(self, didUpdateToolSettings: editingToolType, color: color, width: width)
    }
    
    func toolOptionsDidChangeWidth(_ width: CGFloat) {
        if editingToolType == .pen {
            currentPenWidth = width
        } else if editingToolType == .highlighter {
            currentHighlighterWidth = width
        }
        
        let color = (editingToolType == .pen) ? currentPenColor : currentHighlighterColor
        delegate?.toolbarView(self, didUpdateToolSettings: editingToolType, color: color, width: width)
    }
}
