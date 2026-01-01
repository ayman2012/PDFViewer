//
//  ToolOptionsViewController.swift
//  SignatureAppDemo
//
//  Created by ahmed on 12/11/2025.
//

import UIKit

// MARK: - Delegate Protocol
protocol ToolOptionsDelegate: AnyObject {
    func toolOptionsDidChangeColor(_ color: UIColor)
    func toolOptionsDidChangeWidth(_ width: CGFloat)
}


class ToolOptionsViewController: UIViewController, UIColorPickerViewControllerDelegate {

    // MARK: - Properties
    weak var delegate: ToolOptionsDelegate?

    private let colorPicker = UIColorPickerViewController()
    private let widthSlider = UISlider()
    private let widthLabel = UILabel()

    // Configuration properties set by the parent
    private let initialColor: UIColor
    private let initialWidth: CGFloat
    private let minWidth: CGFloat
    private let maxWidth: CGFloat

    // MARK: - Initializer
    init(color: UIColor, width: CGFloat, minWidth: CGFloat, maxWidth: CGFloat) {
        self.initialColor = color
        self.initialWidth = width
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupColorPicker()
        setupWidthSlider()
    }
    
    // MARK: - UI Setup
    private func setupColorPicker() {
        colorPicker.delegate = self
        colorPicker.selectedColor = initialColor
        
        addChild(colorPicker)
        view.addSubview(colorPicker.view)
        colorPicker.didMove(toParent: self)
        
        colorPicker.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            colorPicker.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            colorPicker.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            colorPicker.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            colorPicker.view.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6) // Give it a fixed portion of the height
        ])
    }

    private func setupWidthSlider() {
        widthLabel.font = .systemFont(ofSize: 16, weight: .medium)
        widthLabel.textAlignment = .center
        
        widthSlider.minimumValue = Float(minWidth)
        widthSlider.maximumValue = Float(maxWidth)
        widthSlider.addTarget(self, action: #selector(sliderDidChangeValue), for: .valueChanged)

        widthSlider.value = Float(initialWidth)
        updateWidthLabel(with: initialWidth)
        
        let stackView = UIStackView(arrangedSubviews: [widthLabel, widthSlider])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: colorPicker.view.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Actions & Delegate Calls
    @objc private func sliderDidChangeValue() {
        let newWidth = CGFloat(widthSlider.value)
        updateWidthLabel(with: newWidth)
        delegate?.toolOptionsDidChangeWidth(newWidth)
    }
    
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        delegate?.toolOptionsDidChangeColor(viewController.selectedColor)
    }

    private func updateWidthLabel(with width: CGFloat) {
        widthLabel.text = String(format: "Width: %.1f", width)
    }
}
