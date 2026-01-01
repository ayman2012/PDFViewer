//
//  SignatureModel.swift
//  SignatureAppDemo
//
//  Created by ahmed on 18/11/2025.
//
import Foundation
import CoreGraphics
import UIKit

struct SignatureModel {
    let imageName: String // Kept for backward compatibility
    let imageData: Data? // NEW: Store actual image data
    let frameInPDFCoordinates: CGRect
    let transform: CGAffineTransform
    let pageIndex: Int
    let originalViewFrameSize: CGSize
    
    init(imageName: String = "signature",
         imageData: Data?,
         frameInPDFCoordinates: CGRect,
         transform: CGAffineTransform,
         pageIndex: Int,
         originalViewFrameSize: CGSize) {
        self.imageName = imageName
        self.imageData = imageData
        self.frameInPDFCoordinates = frameInPDFCoordinates
        self.transform = transform
        self.pageIndex = pageIndex
        self.originalViewFrameSize = originalViewFrameSize
    }
    
    // Legacy initializer for backward compatibility
    init(imageName: String = "signature",
         imageData: Data?,
         frameInPDFCoordinates: CGRect,
         transform: CGAffineTransform,
         pageIndex: Int) {
        self.imageName = imageName
        self.imageData = imageData
        self.frameInPDFCoordinates = frameInPDFCoordinates
        self.transform = transform
        self.pageIndex = pageIndex
        self.originalViewFrameSize = frameInPDFCoordinates.size
    }
}
