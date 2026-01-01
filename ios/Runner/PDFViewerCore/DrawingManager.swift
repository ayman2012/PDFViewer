//
//  DrawingManager.swift
//  SignatureAppDemo
//
//  Created by ahmed on 03/12/2025.
//

import Foundation
import PencilKit

class DrawingManager {
    var drawingsByPage: [Int: DrawingModel] = [:]
    
    // Undo/Redo Management
    private var undoManagers: [Int: PageUndoManager] = [:]
    
    func undoManager(for pageIndex: Int, fallbackBounds: CGRect = .zero) -> PageUndoManager {
        if let manager = undoManagers[pageIndex] {
            return manager
        }
        // Create new manager with current saved drawing or empty
        let initialDrawing = drawingsByPage[pageIndex]?.drawing ?? PKDrawing()
        
        // Use saved bounds if available, otherwise use fallback (current canvas) bounds
        let savedBounds = drawingsByPage[pageIndex]?.canvasBoundsAtCreation ?? .zero
        let boundsToUse = (savedBounds == .zero) ? fallbackBounds : savedBounds
        
        let newManager = PageUndoManager(initialDrawing: initialDrawing, canvasBounds: boundsToUse)
        undoManagers[pageIndex] = newManager
        print("🆕 DrawingManager: Created undo manager for page \(pageIndex)")
        return newManager
    }
    
    func updateUndoStack(for pageIndex: Int, with drawing: PKDrawing, canvasBounds: CGRect) {
        let manager = undoManager(for: pageIndex, fallbackBounds: canvasBounds)
        manager.drawingDidChange(drawing, canvasBounds: canvasBounds)
    }
    
    func saveDrawing(from canvasView: PKCanvasView, at pageIndex: Int) {
        let currentDrawing = canvasView.drawing
        let currentBounds = canvasView.bounds
        
        print("💾💾 DrawingManager.saveDrawing called for page \(pageIndex)")
        print("   Current canvas bounds: \(currentBounds)")
        print("   Current drawing strokes: \(currentDrawing.strokes.count)")
        
        // Sync the undo manager's current state to match what's in the canvas
        let manager = undoManager(for: pageIndex)
        manager.syncCurrentState(currentDrawing, canvasBounds: currentBounds)
        
        if !currentDrawing.strokes.isEmpty {
            // Save drawing at CURRENT canvas bounds - no transformation!
            // Transformation will only happen during PDF export
            let model = DrawingModel(
                drawing: currentDrawing,
                canvasBoundsAtCreation: currentBounds,
                pageIndex: pageIndex
            )
            drawingsByPage[pageIndex] = model
            print("   ✅ Saved drawing at current bounds (no transformation)")
            print("   💾 DrawingManager: Saved page \(pageIndex) with \(currentDrawing.strokes.count) strokes at bounds \(currentBounds)")
        } else {
            drawingsByPage.removeValue(forKey: pageIndex)
            print("   💾 DrawingManager: Cleared page \(pageIndex) (no strokes)")
        }
    }
    
    // Load drawing and scale ONLY if canvas bounds changed (rotation)
    func loadDrawing(into canvasView: PKCanvasView, at pageIndex: Int) {
        print("📂 DrawingManager: Starting loadDrawing for page \(pageIndex)")
        let currentBounds = canvasView.bounds
        
        // Get the current state from the undo manager (source of truth for all edits)
        let manager = undoManager(for: pageIndex)
        let currentState = manager.getCurrentState()
        let currentDrawing = currentState.drawing
        
        // Get saved model's bounds (these are the bounds when last saved, not a "reference")
        // FIX: Always use the UndoManager's state as the source of truth for bounds.
        // The drawingsByPage model might be stale if we just rotated and haven't saved explicitly yet,
        // attempting to use it causes a mismatch between the drawing (from undo manager) and the bounds (from stale model).
        let savedBounds = currentState.canvasBounds
        
        print("   Drawing source: UndoManager state for page \(pageIndex)")
        print("   UndoManager's stored drawing has \(currentDrawing.strokes.count) strokes.")
        print("   UndoManager's stored canvas bounds: \(savedBounds)")
        print("   Current PKCanvasView bounds: \(currentBounds)")
        
        // Guard against invalid bounds
        print("   Checking bounds validity: savedBounds=\(savedBounds), currentBounds=\(currentBounds)")
        guard savedBounds.width > 0, savedBounds.height > 0,
              currentBounds.width > 0, currentBounds.height > 0 else {
            print("   ⚠️ Invalid bounds detected (width or height is zero/negative). Loading drawing without scaling.")
            canvasView.drawing = currentDrawing
            print("   DrawingManager: Finished loadDrawing for page \(pageIndex) (invalid bounds, no scaling).")
            return
        }
        
        // Calculate scale factors
        let scaleX = currentBounds.width / savedBounds.width
        let scaleY = currentBounds.height / savedBounds.height
        
        print("   Calculated scale factors: X=\(scaleX), Y=\(scaleY)")
        
        // Only scale if bounds actually changed (rotation occurred)
        let scaledDrawing: PKDrawing
        if abs(scaleX - 1.0) > 0.001 || abs(scaleY - 1.0) > 0.001 {
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            print("   Applying transformation: CGAffineTransform(scaleX: \(scaleX), y: \(scaleY))")
            scaledDrawing = currentDrawing.transformed(using: transform)
            print("   ✅ Drawing scaled for rotation. Original strokes: \(currentDrawing.strokes.count), Scaled strokes: \(scaledDrawing.strokes.count)")
        } else {
            scaledDrawing = currentDrawing
            print("   ✅ Drawing loaded (no scaling needed - current and saved bounds are effectively the same).")
        }
        
        canvasView.drawing = scaledDrawing
        print("   DrawingManager: Finished loadDrawing for page \(pageIndex). Drawing set to canvasView.")
    }
    
    // For undo/redo operations - uses the state's stored bounds
    func loadDrawing(into canvasView: PKCanvasView, currentState: DrawingState) {
        let currentBounds = canvasView.bounds
        let savedBounds = currentState.canvasBounds
        let savedDrawing = currentState.drawing
        
        print("📂 DrawingManager: Loading drawing from state (undo/redo)")
        print("   Saved drawing: \(savedDrawing.strokes.count) strokes")
        print("   State bounds: \(savedBounds)")
        print("   Current bounds: \(currentBounds)")
        
        // Guard against invalid bounds
        guard savedBounds.width > 0, savedBounds.height > 0,
              currentBounds.width > 0, currentBounds.height > 0 else {
            print("   ⚠️ Invalid bounds, loading without scaling")
            canvasView.drawing = savedDrawing
            return
        }
        
        // Calculate scale factors
        let scaleX = currentBounds.width / savedBounds.width
        let scaleY = currentBounds.height / savedBounds.height
        
        print("   Scale: X=\(scaleX), Y=\(scaleY)")
        
        // Only scale if bounds actually changed
        let scaledDrawing: PKDrawing
        if abs(scaleX - 1.0) > 0.001 || abs(scaleY - 1.0) > 0.001 {
            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
            scaledDrawing = savedDrawing.transformed(using: transform)
            print("   ✅ Drawing scaled and loaded")
        } else {
            // Create a fresh copy to prevent PencilKit caching issues where reusing the same drawing data
            // might cause the canvas to "remember" undone strokes if they share underlying storage.
            scaledDrawing = PKDrawing(strokes: savedDrawing.strokes)
        }
        
        canvasView.drawing = scaledDrawing
    }
    
    func reset() {
        drawingsByPage.removeAll()
        undoManagers.removeAll()
        print("🗑️ DrawingManager: All state reset")
    }
    
    func clearCanvas(_ canvasView: PKCanvasView) {
        canvasView.drawing = PKDrawing()
    }
}
