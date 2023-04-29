//
//  ViewController.swift
//  Cat VS Dog
//
//  Created by Dimas Wisodewo on 29/04/23.
//

import UIKit
import CoreML
import Vision

class ViewController: UIViewController {

    private var model: VNCoreMLModel? = nil
    private var Model: VNCoreMLModel {
        get {
            guard let unwrappedModel = model else {
                fatalError("model is nil!")
            }
            return unwrappedModel
        }
    }
    
    private let imagePicker = UIImagePickerController()
    
    private let cameraBarButton = UIBarButtonItem(barButtonSystemItem: .camera, target: nil, action: nil)
    
    private let imagePreview: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .systemBackground
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let labelPreview: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .label
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.text = "Press the camera button to take a picture!"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let labelResultContainer: UIView = {
        let uiView = UIView()
        uiView.backgroundColor = .blue.withAlphaComponent(0.5)
        uiView.layer.cornerRadius = 16
        uiView.translatesAutoresizingMaskIntoConstraints = false
        return uiView
    }()
    
    private let labelResult: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .left
        label.text = ""
        label.lineBreakMode = .byCharWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let padding = CGFloat(10)
    
    private let wikipediaUrl = "https://en.wikipedia.org/w/api.php"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load machine learning model
        guard let importedModel = try? VNCoreMLModel(for: CatVSDogClassifier().model) else {
            fatalError("Cannot import model!")
        }
        
        model = importedModel
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = .camera
        
        view.backgroundColor = .systemBackground
        
        configureNavigationItem()
        configureBarButtons()
        
        view.addSubview(imagePreview)
        view.addSubview(labelPreview)
        view.addSubview(labelResultContainer)
        
        labelResultContainer.addSubview(labelResult)
    }
    
    override func viewDidLayoutSubviews() {
        
        let insets = self.view.safeAreaInsets
        
        imagePreview.topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top).isActive = true
        imagePreview.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -insets.top-insets.bottom).isActive = true
        imagePreview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left).isActive = true
        imagePreview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -insets.right).isActive = true
        
        labelPreview.topAnchor.constraint(equalTo: imagePreview.topAnchor).isActive = true
        labelPreview.bottomAnchor.constraint(equalTo: imagePreview.bottomAnchor).isActive = true
        labelPreview.leftAnchor.constraint(equalTo: imagePreview.leftAnchor).isActive = true
        labelPreview.rightAnchor.constraint(equalTo: imagePreview.rightAnchor).isActive = true
        
        labelResultContainer.leftAnchor.constraint(equalTo: view.leftAnchor, constant: insets.left+padding).isActive = true
        labelResultContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding).isActive = true
        labelResultContainer.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -(view.bounds.width / 2)).isActive = true
        
        labelResult.topAnchor.constraint(equalTo: labelResultContainer.topAnchor, constant: padding).isActive = true
        labelResult.bottomAnchor.constraint(equalTo: labelResultContainer.bottomAnchor, constant: -padding).isActive = true
        labelResult.leftAnchor.constraint(equalTo: labelResultContainer.leftAnchor, constant: padding).isActive = true
        labelResult.rightAnchor.constraint(equalTo: labelResultContainer.rightAnchor, constant: -padding).isActive = true
        
        labelResultContainer.heightAnchor.constraint(equalTo: labelResult.heightAnchor, constant: padding * 2).isActive = true
        
        // Hide result label
        labelResultContainer.isHidden = true
    }
    
    private func configureNavigationItem() {
        navigationItem.title = "Cat VS Dog"
        navigationItem.setRightBarButtonItems([cameraBarButton], animated: true)
    }

    private func configureBarButtons() {
        cameraBarButton.target = self
        cameraBarButton.action = #selector(cameraButtonPressed)
    }
    
    // On camera button pressed
    @objc private func cameraButtonPressed() {
        present(imagePicker, animated: true)
    }
    
    private func setResultLabel(resultString: String) {
        print("Result string:\n\(resultString)")
        labelResult.text = resultString
        labelResultContainer.heightAnchor.constraint(equalTo: labelResult.heightAnchor, constant: padding * 2).isActive = true
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // Load captured photo
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        let pickedImage = info[.editedImage]
        
        guard let pickedImage = pickedImage as? UIImage else {
            fatalError("Failed to set picked image to preview!")
        }
        
        imagePreview.image = pickedImage
        labelPreview.isHidden = true
        
        // Convert into CIImage before passing the captured photo into machine learning model
        guard let convertedCIImage = CIImage(image: pickedImage) else {
            fatalError("Failed to convert UIImage into CIImage")
        }
        
        // Pass captured photo into machine learning model
        detectImage(image: convertedCIImage)
        
        imagePicker.dismiss(animated: true)
    }
    
    // Detect Cat or Dog with machine learning model
    private func detectImage(image: CIImage) {
        
        let request = VNCoreMLRequest(model: Model) { [weak self] (request, error) in
            
            guard let classificationResults = request.results as? [VNClassificationObservation] else { return }
            
            // Sort prediction results by its confidence
            let sortedResults = classificationResults.sorted { $0.confidence > $1.confidence}
            
            var resultString = ""
            
            // Sort the prediction results with highest confidence
            for i in 0...sortedResults.count-1 {
                resultString += "\(sortedResults[i].identifier.capitalized), confidence: \(sortedResults[i].confidence)\n"
            }
            
            // Show results label in the main thread
            DispatchQueue.main.async {
                self?.labelResultContainer.isHidden = false
            }
            
            self?.setResultLabel(resultString: resultString)
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        // Perform prediction
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }
}
