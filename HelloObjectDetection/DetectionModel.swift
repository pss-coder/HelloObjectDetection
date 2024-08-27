//
//  DetectionModel.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 27/8/24.
//

import Foundation
import CoreGraphics
import Vision

class DetectionModel: ObservableObject {
	
	private let cameraManager = CameraManager()
	
	private let visionManager = VisionManager()
	
	@Published var currentFrame: CGImage?
	@Published var isCameraRunning: Bool = true
	
	@Published var observations: [VNRecognizedObjectObservation] = []
	
	init() {
		Task {
			await handleCameraPreviews()
		}
		
		Task {
			await handleVisionObservations()
		}
	}
	
	// handle updates of asyncStream and move updates to mainactor, updating uI
	func handleCameraPreviews() async {
		for await image in cameraManager.previewStream {
			Task { @MainActor in
				currentFrame = image
				
				if isCameraRunning {
					visionManager.detectLiveObject(image: image)
				}
			}
		}
	}
	
	
	
	func stopCamera() {
		cameraManager.stopSession()
		isCameraRunning = false
		
		// clean up observations
		self.observations.removeAll()
	}
	
	func startCamara() async {
		await cameraManager.startSession()
		isCameraRunning = true
	}
	
	
//	Handle Observations
	private func handleVisionObservations() async {
			for await observations in visionManager.observationStream {
				Task { @MainActor in
					if isCameraRunning {
						self.observations = observations
					}
				}
			}
		}
	
	
	/// Process Observations
	func processObservation(_ observation: VNRecognizedObjectObservation, for imageSize: CGSize) -> (text: String, confidence: Float, size: CGSize, position: CGPoint) {
		
		let objectBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageSize.width), Int(imageSize.height))
		
		let topLabelObservation = observation.labels[0]
		
		let text = topLabelObservation.identifier
		let confidence = topLabelObservation.confidence
		
		// create bound box
		let boundingBox = objectBounds
		let position = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
		
		// display
		print("\(text) \(confidence)%")
		
		return (text, confidence, boundingBox.size, position)
	}

}
