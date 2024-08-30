//
//  SemanticSegmentView.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 29/8/24.
//

import SwiftUI
import ARKit

import CoreML
import Vision

import CoreImage
import CoreImage.CIFilterBuiltins


struct SemanticSegmentView: View {
	
    var body: some View {
		ZStack {
			ARSSViewContainer()
				.ignoresSafeArea()
		}
		
    }
}

struct ARSSViewContainer: UIViewRepresentable {
	// preview view for semantic segmentation
	var previewView = UIImageView()
	
	func makeCoordinator() -> Coordinator {
		return Coordinator()
	}

	func makeUIView(context: Context) -> some UIView {
		
		let arView = ARSCNView(frame: .zero)
		let configuration = ARWorldTrackingConfiguration()
		
		// Enable Horizontal plane detection
		configuration.planeDetection = .horizontal
		arView.session.run(configuration)

		// link coordinator delegates
		arView.delegate = context.coordinator
		arView.session.delegate = context.coordinator
		// attach preview to coordinator
		context.coordinator.view = arView
		context.coordinator.previewView = previewView

		// Attach preview to arView to bottom right
		arView.addSubview(previewView)
		
		// fit to view size
		previewView.translatesAutoresizingMaskIntoConstraints = false
		previewView.bottomAnchor.constraint(equalTo: arView.bottomAnchor).isActive = true
		previewView.trailingAnchor.constraint(equalTo: arView.trailingAnchor).isActive = true
		
		previewView.topAnchor.constraint(equalTo: arView.topAnchor).isActive = true
		previewView.leadingAnchor.constraint(equalTo: arView.leadingAnchor).isActive = true
		
		// for testing: add a border to previewView for better vibility
		previewView.layer.borderColor = UIColor.white.cgColor
		previewView.layer.borderWidth = 2
		
		return arView
	}
	
	func updateUIView(_ uiView: UIViewType, context: Context) {
		//
	}
}

class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
	
	var view: ARSCNView?
	
	// our ImageView with the hands
	var previewView:UIImageView?
	
	// input
	var currentBuffer: CVPixelBuffer?
	var currentFrame: ARFrame?
	
	var handDetection = HandDetectorManager()
	

	private func startDetection() {
		// To avoid force unwrap in VNImageRequestHandler
		guard let buffer = currentBuffer else { return }

		handDetection.performDetection(inputBuffer: buffer) { [self] outputBuffer, _ in
			// Here we are on a background thread
			var previewImage: UIImage?
			
			defer { // do this in the end of function
				DispatchQueue.main.async {
					print("adding image to view")
					self.previewView!.image = previewImage
					// Release currentBuffer when finished to allow processing next frame
					self.currentBuffer = nil
				}
			}
			
			// output size from ml model: is 112x112
			guard let outBuffer = outputBuffer else {
				return
			}
			
			// Goals
				// 1. Scale size of output to fit to screen size
				// 2. Remove background, and mask only hands
			

			// Get input buffer size
			let inputImageSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
			
			// Perform scale transformation
			let scaleTransform = CGAffineTransform(scaleX: inputImageSize.width / 112.0, y: inputImageSize.height / 112.0)
			let outputImage = CIImage(cvPixelBuffer: outBuffer)
			
			// Scale output to input size
			let scaledOutputImage = outputImage.transformed(by: scaleTransform)
			let context = CIContext()
			
			// Convert scaled CIImage to UIImage
//			if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
//				previewImage = UIImage(cgImage: cgImage)
//			}
			
			// Now, remove background and mask only hands
			if let cgImage = context.createCGImage(scaledOutputImage, from: scaledOutputImage.extent) {
				let uiImage = UIImage(cgImage: cgImage)
				// Apply threshold to remove background
				if let thresholdedMask = self.applyThreshold(to: uiImage) {
					//maskImage = thresholdedMask
					previewImage = thresholdedMask
				}
			}

		}

	}
	
	// MARK: - Public functions
	
	
	func applyThreshold(to image: UIImage) -> UIImage? {
			// Convert the image to grayscale and apply a threshold filter
			guard let inputImage = CIImage(image: image) else { return nil }
			let filter = CIFilter.colorControls()
			filter.inputImage = inputImage
			filter.contrast = 4.0 // Increase contrast to highlight the hand
			guard let outputImage = filter.outputImage else { return nil }
			
			let filter2 = CIFilter.colorMatrix()
			filter2.inputImage = outputImage
			filter2.setDefaults()
			
			// Adjust the intensity of the mask
			filter2.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
			filter2.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
			filter2.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
			filter2.aVector = CIVector(x: 1, y: 1, z: 1, w: 0)
			
			guard let finalImage = filter2.outputImage else { return nil }
			let context = CIContext(options: nil)
			
			if let cgImage = context.createCGImage(finalImage, from: finalImage.extent) {
				return UIImage(cgImage: cgImage)
			}
			
			return nil
		}
	
	
	// MARK: - ARSessionDelegate
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		// We return early if currentBuffer is not nil or the tracking state of camera is not normal
			guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
				return
			}

			// Retain the image buffer for Vision processing.
			currentBuffer = frame.capturedImage
			self.currentFrame = frame

		
			// start detection of hand
			startDetection()
	}
	
	
	// MARK: - ARSCNViewDelegate
	func renderer(_: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
		guard let _ = anchor as? ARPlaneAnchor else { return nil }

		// We return a special type of SCNNode for ARPlaneAnchors
		return PlaneNode()
	}

	func renderer(_: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		guard let planeAnchor = anchor as? ARPlaneAnchor,
			let planeNode = node as? PlaneNode else {
			return
		}
		planeNode.update(from: planeAnchor)
	}

	func renderer(_: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
		guard let planeAnchor = anchor as? ARPlaneAnchor,
			let planeNode = node as? PlaneNode else {
			return
		}
		planeNode.update(from: planeAnchor)
	}
	
}

public class PlaneNode: SCNNode {
	
	// MARK: - Public functions
	
	public func update(from planeAnchor: ARPlaneAnchor) {
		// We need to create a new geometry each time because it does not seem to update correctly for physics
		guard let device = MTLCreateSystemDefaultDevice(),
			  let geom = ARSCNPlaneGeometry(device: device) else {
			fatalError()
		}
		
		geom.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.3)
		geom.update(from: planeAnchor.geometry)
		
		// We modify our plane geometry each time ARKit updates the shape of an existing plane
		geometry = geom
	}
}


//#Preview {
//    SemanticSegmentView()
//}
