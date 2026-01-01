//
//  ToolbarManager.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//

import PencilKit
import UIKit

protocol ToolbarManagerDelegate: AnyObject {
    func didChangeTool(_ tool: PKInkingTool)
    func didSelectEraser()
    func didTapUndo()
    func didTapRedo()
    func didToggleDrawing(enabled: Bool)
    // Optional: Methods to notify UI to update if the change came from elsewhere
    func didUpdateUndoRedoState(canUndo: Bool, canRedo: Bool)
}

class ToolbarManager: NSObject {
    
    enum ToolType {
        case pen
        case highlighter
        case eraser
    }
    
    weak var delegate: ToolbarManagerDelegate?
    
    // State
    // Made public so UI can read initial state or persist it
    var currentPenColor: UIColor = .black
    var currentPenWidth: CGFloat = 5
    var currentHighlighterColor: UIColor = .yellow
    var currentHighlighterWidth: CGFloat = 20
    var currentEraserWidth: CGFloat = 25 // Default width for eraser
    
    public private(set) var activeToolType: ToolType = .pen
    
    // Undo/Redo State
    private(set) var canUndo: Bool = false
    private(set) var canRedo: Bool = false
    
    // MARK: - Public API
    
    func selectTool(_ type: ToolType) {
        activeToolType = type
        
        switch type {
        case .pen:
            notifyToolChange(type: .pen)
             delegate?.didToggleDrawing(enabled: true)
        case .highlighter:
            notifyToolChange(type: .highlighter)
             delegate?.didToggleDrawing(enabled: true)
        case .eraser:
            delegate?.didSelectEraser()
             delegate?.didToggleDrawing(enabled: true)
        }
    }
    
    func deselectTools() {
        delegate?.didToggleDrawing(enabled: false)
    }

    public func getCurrentTool() -> PKTool {
        switch activeToolType {
        case .pen:
            return PKInkingTool(.pen, color: currentPenColor, width: currentPenWidth)
        case .highlighter:
            return PKInkingTool(.marker, color: currentHighlighterColor.withAlphaComponent(0.4), width: currentHighlighterWidth)
        case .eraser:
            if #available(iOS 16.4, *) {
                return PKEraserTool(.bitmap, width: currentEraserWidth)
            } else {
                // Fallback on earlier versions
                return PKEraserTool(.bitmap)
            }
        }
    }
    
    func updateToolSettings(type: ToolType, color: UIColor, width: CGFloat) {
        if type == .pen {
            currentPenColor = color
            currentPenWidth = width
        } else if type == .highlighter {
            currentHighlighterColor = color
            currentHighlighterWidth = width
        }
        
        // If the updated tool is ensuring the currently active one, re-notify
        if type == activeToolType {
            notifyToolChange(type: type)
        }
    }
    
    func performUndo() {
        delegate?.didTapUndo()
    }
    
    func performRedo() {
        delegate?.didTapRedo()
    }
    
    func setUndoRedoState(canUndo: Bool, canRedo: Bool) {
        self.canUndo = canUndo
        self.canRedo = canRedo
        delegate?.didUpdateUndoRedoState(canUndo: canUndo, canRedo: canRedo)
    }
    
    // MARK: - Private
    
    private func notifyToolChange(type: ToolType) {
        let tool: PKInkingTool
        if type == .pen {
            tool = PKInkingTool(.pen, color: currentPenColor, width: currentPenWidth)
        } else if type == .highlighter {
            tool = PKInkingTool(.marker, color: currentHighlighterColor.withAlphaComponent(0.5), width: currentHighlighterWidth)
        } else {
            return
        }
        delegate?.didChangeTool(tool)
    }
}
