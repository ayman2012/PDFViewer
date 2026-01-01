//
//  SignatureView.swift
//  SignatureAppDemo
//
//  Created by ahmed on 11/11/2025.
//
import UIKit
import UIKit

class SignatureView: UIView {

    
    private let resizeHandle = UIView()
    // Closure to fetch robust bounds from the source of truth (PDFView)
    var getPageBounds: (() -> CGRect)?
    
    // NEW: The "True Position" of this signature in PDF Page coordinates (points)
    // This allows us to re-calculate the frame on any layout change (zoom, scroll, resize)
    var pdfFrame: CGRect?
    var pageIndex: Int = 0 // Track which page this belongs to

    let imageView = UIImageView()
    private let deleteButton = UIButton(type:.system)
    private let saveButton = UIButton(type: .system) // NEW: Save button
    
    // The closure is now the only communication needed for deletion
    var onDelete: ((SignatureView) -> Void)?
    var onSave: ((SignatureView) -> Void)? // NEW: Save closure
    var onFrameChange: (() -> Void)? // NEW: Notify manager when frame changes interactively

    // The view's own state, which triggers UI updates
    private(set) var isSelected: Bool = false

    init(image: UIImage) {
        // Give it a slightly random starting position to avoid overlap
        let xPos = CGFloat.random(in: 50...150)
        let yPos = CGFloat.random(in: 100...200)
        let initialFrame = CGRect(x: xPos, y: yPos, width: 200, height: 100)
        super.init(frame: initialFrame)
        
        setupView(image: image)
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    // Public method for the controller to force deselection
    public func deselect() {
        isSelected = false
        updateAppearance()
    }
    
    // Public method to handle initial selection
    public func select() {
        selectThisViewAndDeselectOthers()
    }
    
    // MARK: - Core Logic (Self-Contained)

    private func selectThisViewAndDeselectOthers() {
        // 1. Find all other SignatureViews in the same superview and deselect them
        superview?.subviews.forEach { subview in
            if let sibling = subview as? SignatureView, sibling !== self {
                sibling.deselect()
            }
        }
        
        // 2. Select this view
        isSelected = true
        updateAppearance()
        
        // 3. Bring this view to the front
        superview?.bringSubviewToFront(self)
    }

    private func updateAppearance() {
        UIView.animate(withDuration: 0.2) {
            self.layer.borderWidth = self.isSelected ? 2.0 : 0.0
            self.deleteButton.alpha = self.isSelected ? 1.0 : 0.0
            self.saveButton.alpha = self.isSelected ? 1.0 : 0.0 // NEW
            self.resizeHandle.alpha = self.isSelected ? 1.0 : 0.0

        }
    }

    // MARK: - Setup
    
    private func setupView(image: UIImage) {
        self.layer.borderColor = UIColor.systemBlue.cgColor
        self.layer.borderWidth = 0
        self.clipsToBounds = false // CRITICAL: Allow buttons outside bounds to be tappable
        
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // ... (deleteButton setup is the same as before)
        let buttonImage = UIImage(systemName: "xmark.circle.fill")
        deleteButton.setImage(buttonImage, for: .normal)
        deleteButton.tintColor = .systemBlue
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 15
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(deleteButton)
        deleteButton.alpha = 0
        
        // NEW: Save Button Setup
        let saveImage = UIImage(systemName: "checkmark.circle.fill")
        saveButton.setImage(saveImage, for: .normal)
        saveButton.tintColor = .systemGreen
        saveButton.backgroundColor = .white
        saveButton.layer.cornerRadius = 15
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(saveButton)
        saveButton.alpha = 0

        // ... (constraints are the same as before)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            
            deleteButton.widthAnchor.constraint(equalToConstant: 30),
            deleteButton.heightAnchor.constraint(equalToConstant: 30),
            deleteButton.centerXAnchor.constraint(equalTo: self.leadingAnchor, constant: -10), // Moved to left
            deleteButton.centerYAnchor.constraint(equalTo: self.topAnchor, constant: -5),
            
            // NEW: Save Button Constraints (Top Right)
            saveButton.widthAnchor.constraint(equalToConstant: 30),
            saveButton.heightAnchor.constraint(equalToConstant: 30),
            saveButton.centerXAnchor.constraint(equalTo: self.trailingAnchor, constant: 10),
            saveButton.centerYAnchor.constraint(equalTo: self.topAnchor, constant: -5)
        ])
        resizeHandle.backgroundColor = .systemBlue
        resizeHandle.layer.cornerRadius = 15 // Make it a circle
        resizeHandle.layer.borderWidth = 2
        resizeHandle.layer.borderColor = UIColor.white.cgColor
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(resizeHandle)
        resizeHandle.alpha = 0 // NEW: Hidden by default
        NSLayoutConstraint.activate([
                // ... (imageView and deleteButton constraints are the same) ...

                // Add these new constraints for the resize handle
                resizeHandle.widthAnchor.constraint(equalToConstant: 30),
                resizeHandle.heightAnchor.constraint(equalToConstant: 30),
                resizeHandle.centerXAnchor.constraint(equalTo: self.leadingAnchor),
                resizeHandle.centerYAnchor.constraint(equalTo: self.bottomAnchor)
            ])
    }
    
    // MARK: - Gestures & Hit-Testing

    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        self.addGestureRecognizer(tapGesture)
        
        let resizePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleResize))
            resizeHandle.addGestureRecognizer(resizePanGesture)
    }

    @objc private func handleTap(gesture: UITapGestureRecognizer) {
        selectThisViewAndDeselectOthers()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        
        if gesture.state == .changed {
            var newCenter = CGPoint(
                x: center.x + translation.x,
                y: center.y + translation.y
            )
            
            // NEW: Constrain to bounds dynamically using the provider
            // Fallback to superview bounds if provider is missing (though provider is preferred)
            let validBounds = getPageBounds?() ?? superview?.bounds ?? bounds
            
            let halfWidth = bounds.width / 2
            let halfHeight = bounds.height / 2
            
            // Keep signature within the constrained bounds
            newCenter.x = max(validBounds.minX + halfWidth,
                            min(validBounds.maxX - halfWidth, newCenter.x))
            newCenter.y = max(validBounds.minY + halfHeight,
                            min(validBounds.maxY - halfHeight, newCenter.y))
            
            center = newCenter
            gesture.setTranslation(.zero, in: superview)
            
            // NEW: Notify that frame has changed
            onFrameChange?()
        }
    }
    // In SignatureView.swift, add this new method

    @objc private func handleResize(gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        // Calculate the new width and height
        var newWidth = self.bounds.width + translation.x
        var newHeight = self.bounds.height + translation.y
        
        // Enforce a minimum size to prevent the view from disappearing
        let minimumSize: CGFloat = 50.0
        newWidth = max(newWidth, minimumSize)
        newHeight = max(newHeight, minimumSize)
        
        // NEW: Ensure the resized view stays within constrained bounds
        let validBounds = getPageBounds?() ?? superview?.bounds ?? bounds
        
        // Calculate what the new frame would be
        let potentialFrame = CGRect(x: self.frame.minX, y: self.frame.minY, width: newWidth, height: newHeight)
        
        // Check if it would exceed the right boundary
        if potentialFrame.maxX > validBounds.maxX {
            newWidth = validBounds.maxX - self.frame.minX
        }
        
        // Check if it would exceed the bottom boundary  
        if potentialFrame.maxY > validBounds.maxY {
            newHeight = validBounds.maxY - self.frame.minY
        }
        
        // Update the frame of the SignatureView
        self.frame = CGRect(x: self.frame.minX, y: self.frame.minY, width: newWidth, height: newHeight)
        
        // Reset the gesture's translation
        gesture.setTranslation(.zero, in: self)
        
        // NEW: Notify that frame has changed
        onFrameChange?()
    }
    @objc private func deleteButtonTapped() {
        onDelete?(self)
    }
    
    @objc private func saveButtonTapped() {
        onSave?(self)
    }
    
    

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Check delete button first
        let deletePoint = deleteButton.convert(point, from: self)
        if deleteButton.bounds.contains(deletePoint) {
            return deleteButton
        }
        
        // Check save button
        let savePoint = saveButton.convert(point, from: self)
        if saveButton.bounds.contains(savePoint) {
            return saveButton
        }
        
        // Then check the resize handle
        let resizePoint = resizeHandle.convert(point, from: self)
        if resizeHandle.bounds.contains(resizePoint) {
            return resizeHandle
        }
        
        // Otherwise, perform default hit-testing
        return super.hitTest(point, with: event)
    }
}
