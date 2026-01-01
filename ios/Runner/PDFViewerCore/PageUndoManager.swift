//
//  PageUndoManager.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//
import Foundation
import PencilKit

class PageUndoManager {
    private var undoStack: [DrawingState] = []
    private var redoStack: [DrawingState] = []
    private var currentState: DrawingState
    
    // Limit stack size to prevent memory issues
    private let maxStackSize = 50
    
    init(initialDrawing: PKDrawing, canvasBounds: CGRect) {
        self.currentState = DrawingState(drawing: initialDrawing, canvasBounds: canvasBounds)
        // Don't add to undo stack on init - undo should only be enabled after actual changes
    }
    
    // Backward compatibility initializer
    init(initialDrawing: PKDrawing) {
        self.currentState = DrawingState(drawing: initialDrawing, canvasBounds: .zero)
    }
    
    // Check if this is truly a new state (not just a mode switch reload)
    private func isSignificantChange(from old: PKDrawing, to new: PKDrawing) -> Bool {
        let oldCount = old.strokes.count
        let newCount = new.strokes.count
        
        // If stroke count changed, it's definitely significant
        if oldCount != newCount {
            return true
        }
        
        // If counts are same, compare data to detect modifications
        let oldData = old.dataRepresentation()
        let newData = new.dataRepresentation()
        return oldData != newData
    }
    
    func drawingDidChange(_ newDrawing: PKDrawing, canvasBounds: CGRect) {
        // Check if this is a significant change
        if !isSignificantChange(from: currentState.drawing, to: newDrawing) {
            print("⏭️ PageUndoManager: No significant change detected, skipping")
            return
        }
        
        // Additional check: if undo stack already has this exact drawing, skip
        if let lastUndo = undoStack.last {
            if !isSignificantChange(from: lastUndo.drawing, to: newDrawing) {
                print("⏭️ PageUndoManager: Duplicate of last undo state, skipping")
                return
            }
        }
        
        // Push current state to undo stack BEFORE updating
        undoStack.append(currentState)
        
        // Clear redo stack because we branched off
        redoStack.removeAll()
        
        // Update current
        currentState = DrawingState(drawing: newDrawing, canvasBounds: canvasBounds)
        
        // Enforce limit
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        print("✏️ PageUndoManager: Added to undo stack")
        print("   Current: \(currentState.drawing.strokes.count) strokes, bounds: \(canvasBounds)")
        print("   Stack: [\(undoStack.map { "\($0.drawing.strokes.count)" }.joined(separator: ", "))]")
    }
    
    func undo() -> DrawingState? {
        guard canUndo else { return nil }
        
        // Push current to redo
        redoStack.append(currentState)
        
        // Pop from undo
        let previousState = undoStack.removeLast()
        currentState = previousState
        
        // Enforce redo limit
        if redoStack.count > maxStackSize {
            redoStack.removeFirst()
        }
        
        print("↩️ PageUndoManager: Undo (undo stack: \(undoStack.count), redo stack: \(redoStack.count))")
        
        return currentState
    }
    
    func redo() -> DrawingState? {
        guard canRedo else { return nil }
        
        // Push current to undo
        undoStack.append(currentState)
        
        // Pop from redo
        let nextState = redoStack.removeLast()
        currentState = nextState
        
        // Enforce undo limit
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        print("↪️ PageUndoManager: Redo (undo stack: \(undoStack.count), redo stack: \(redoStack.count))")
        
        return currentState
    }
    
    var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        return !redoStack.isEmpty
    }
    
    // Get the current drawing state without modifying stacks
    func getCurrentDrawing() -> PKDrawing {
        return currentState.drawing
    }
    
    // Get the current complete state (drawing + bounds)
    func getCurrentState() -> DrawingState {
        return currentState
    }
    
    // Update current drawing to match what's saved (used when saving from canvas)
    func syncCurrentState(_ drawing: PKDrawing, canvasBounds: CGRect) {
        // Only sync if it's actually different to avoid confusion
        if !isSignificantChange(from: currentState.drawing, to: drawing) {
            print("💾 PageUndoManager: No change to sync")
            return
        }
        
        // Only update currentState reference, don't touch stacks
        currentState = DrawingState(drawing: drawing, canvasBounds: canvasBounds)
        print("💾 PageUndoManager: Synced current state (\(drawing.strokes.count) strokes, bounds: \(canvasBounds))")
    }
    
    // Backward compatibility for syncCurrentState
    func syncCurrentState(_ drawing: PKDrawing) {
        syncCurrentState(drawing, canvasBounds: currentState.canvasBounds)
    }
    
    // Helper to reset if needed (e.g. clearing page)
    func reset(to drawing: PKDrawing, canvasBounds: CGRect) {
        undoStack.removeAll()
        redoStack.removeAll()
        currentState = DrawingState(drawing: drawing, canvasBounds: canvasBounds)
        print("🔄 PageUndoManager: Reset to drawing with \(drawing.strokes.count) strokes, bounds: \(canvasBounds)")
    }
    
    // Backward compatibility for reset
    func reset(to drawing: PKDrawing) {
        reset(to: drawing, canvasBounds: .zero)
    }
}
