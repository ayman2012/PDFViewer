//
//  DrawingModel.swift
//  SignatureAppDemo
//
//  Created by ahmed on 25/11/2025.
//

import Foundation
import PencilKit


// MARK: - Drawing Model with Page Context
struct DrawingModel {
    var drawing: PKDrawing
    var canvasBoundsAtCreation: CGRect // Store the page bounds at time of drawing
    var pageIndex: Int
}
