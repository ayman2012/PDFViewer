//
//  DrawingState.swift
//  SignatureAppDemo
//
//  Created by ahmed on 03/12/2025.
//

import Foundation
import PencilKit

// MARK: - Drawing State for Undo/Redo
struct DrawingState {
    let drawing: PKDrawing
    let canvasBounds: CGRect
    
    init(drawing: PKDrawing, canvasBounds: CGRect) {
        self.drawing = drawing
        self.canvasBounds = canvasBounds
    }
}
