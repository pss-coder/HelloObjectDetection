//
//  VisionManager.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 27/8/24.
//

import SwiftUI
import Vision
import CoreML

class VisionManager {

	
	// CONNECT CORE ML to Vision to reference from
	var visionModel: VNCoreMLModel = {
		do {
			let model = try YOLOv3_model(configuration: .init()).model
			return try VNCoreMLModel(for: model)
		}
		catch {
			fatalError("Failed to create VNCoreMLModel: \(error)")
		}
	}()
	

	
	
	// Store observations from Vision
	private var addToObservationStream: (([VNRecognizedObjectObservation]) -> Void)?
		
	lazy var observationStream: AsyncStream<[ VNRecognizedObjectObservation]> = {
			AsyncStream { continuation in
				addToObservationStream = { observations in
					continuation.yield(observations)
				}
			}
		}()
	
	
	// requests
	private var requests = [VNRequest]()
	
	// to conserve memory
	private var isProcessing: Bool = false

	
	init() {
		// from coreml
		setUpImageAnalysisRequest()
	}

// create image analysis request that uses core mL to process images
	func setUpImageAnalysisRequest() {
		
		//var newObservations: [VNRecognizedObjectObservation] = []
		// completition handler for analysis request
		let requestCompletionHandler: VNRequestCompletionHandler = {
			request, error in
			if let results = request.results as? [VNRecognizedObjectObservation] {
				// here we do something with the request results
				//print("results here")
				//self.drawVisionOverlay(results)
				//self.ob
				//newObservations.append(contentsOf: results)
//				self.drawVisionOverlay(results) // display
				
				self.addToObservationStream?(results)
				
			} else {
				print("Error while getting request results")
			}
		}
		
		// create request with the model container and completion handler
		let request = VNCoreMLRequest(model: visionModel, completionHandler: requestCompletionHandler)
		
		// inform vision algo how to scale input image
		//request.imageCropAndScaleOption = .scaleFill
		
		//return request
		self.requests = [request]
	}
	
//	func drawVisionOverlay(_ results: [Any]) {
//		//detectionOverlay.sublayers = nil // remove all the old recognized objects
//		
//		for observation in results where observation is VNRecognizedObjectObservation {
//			guard let objectObservation = observation as? VNRecognizedObjectObservation else {
//				continue
//			}
//			// Select only the label with the highest confidence.
//			let topLabelObservation = objectObservation.labels[0]
//			//let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
//			
////			print("\(topLabelObservation.identifier) \(topLabelObservation.confidence)%")
//			
//			
////			let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
////			
////			let textLayer = self.createTextSubLayerInBounds(objectBounds,
////															identifier: topLabelObservation.identifier,
////															confidence: topLabelObservation.confidence)
////			shapeLayer.addSublayer(textLayer)
////			detectionOverlay.addSublayer(shapeLayer)
//		}
////		self.updateLayerGeometry()
//	}
	
	/// Start detection of live objects
	func detectLiveObject(image: CGImage) {
		if isProcessing { return }
		isProcessing = true
		
		
		// pass image pixel inside to detect objects
		Task {
			let handler = VNImageRequestHandler(cgImage: image)
			
			do {
				// start performing
					// passes data to request completion function found in setUpImageAnalysisRequest
				try handler.perform(self.requests)
				isProcessing = false

			} catch {
				print("Error at detecting object")
				isProcessing = false
			}
		}
	}
}
