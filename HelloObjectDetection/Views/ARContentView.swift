//
//  ARContentView.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 28/8/24.
//

import SwiftUI

import RealityKit
import ARKit
import SceneKit



struct ARContentView: View {
	
	//@State var VNRequest: VNCoreMLRequest?
	
	@State var text = Text("")
	
	@State var measurementText = "not yet"
	
    var body: some View {
			ARViewContainer()
//				.ignoresSafeArea(.all)
		
		
    }
}

struct ARViewContainer: UIViewRepresentable {
	
//	@Binding var text: String
	
	var vnRequest: VNCoreMLRequest?
	
	// rectangle view
	var classLabel = UILabel()
	
	var nodeManager: NodeManager?
	
	init() {
		
		self.nodeManager = NodeManager()
		
		// Link CoreML model to Vision
		do {
			let model = try YOLOv3_model(configuration: .init()).model
			let vnModel = try VNCoreMLModel(for: model)
			
			self.vnRequest = VNCoreMLRequest(model: vnModel)
//			self.vnRequest?.imageCropAndScaleOption = .scaleFit
		}
		catch {
			fatalError("Failed to create VNCoreMLModel: \(error)")
		}
		
	}
	
	func makeCoordinator() -> Coordinator {
		return Coordinator()
	}
	
	func updateUIView(_ uiView: UIViewType, context: Context) {
		// update here??
	}
	
	func makeUIView(context: Context) -> some ARSCNView {
		let arView = ARSCNView(frame: .zero)
		
		// set up the nodes
		arView.scene.rootNode.addChildNode(nodeManager!.baseNode)
			
		// Adding corner nodes
		
		
		// set up configurations - horizontal
		let config = ARWorldTrackingConfiguration()
		config.planeDetection = [.vertical]
		arView.session.run(config)
		
		//Link view delegates to Coordinator
		context.coordinator.arView = arView
		context.coordinator.vnRequest = self.vnRequest
		context.coordinator.classLabel = self.classLabel
		context.coordinator.nodeManager = self.nodeManager
		arView.session.delegate = context.coordinator
		//UIApplication.shared.isIdleTimerDisabled = true

		//context.coordinator.arView?.session.delegate = context.coordinator
		arView.showsStatistics = true // show stats info
		
		return arView
	}
}

class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
	
	// nodes
	var nodeManager: NodeManager! = nil
	
	var arView: ARSCNView?
	var vnRequest: VNCoreMLRequest?
	
	// distance between camera and object
	var hitObjectDistanceFromCamera:Float?
	
	// rectangle view
	var classLabel: UILabel?
	
	func detectObject(pixelBuffer:CVPixelBuffer, frame:ARFrame) {
		
		guard let sceneView = arView else { print("scene view not found"); return }
		guard let vnRequest = vnRequest else { print("issue with vnRequest in detectObject(,) "); return}
		
		let frameRect:CGRect? = sceneView.bounds
		
		var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
		if UIDevice.current.orientation.isPortrait {
			ciImage = ciImage.oriented(.right)
		}
		
		// cropping an image based on the current orientation of the device
		var cropped:CIImage
		if UIDevice.current.orientation.isPortrait {
			let aspect =  frameRect!.width / frameRect!.height
			let estimateWidth = ciImage.extent.height * aspect
			
			cropped = ciImage.cropped(to: CGRect(
				x: ciImage.extent.width / 2 - estimateWidth / 2,
				y: 0,
				width: estimateWidth,
				height: ciImage.extent.height)
			)
		} else {
			let aspect =  frameRect!.height / frameRect!.width
			let estimateHeight = ciImage.extent.width * aspect
			cropped = ciImage.cropped(to: CGRect(
				x: 0,
				y: ciImage.extent.height / 2 - estimateHeight / 2,
				width: ciImage.extent.width,
				height: estimateHeight)
			)
		}
		
		// perform request to Vision
		let handler = VNImageRequestHandler(ciImage: cropped, options: [:])
		do {
			
			try handler.perform([vnRequest])
			
			guard let result = vnRequest.results?.first as? VNRecognizedObjectObservation else {
				DispatchQueue.main.async {
					self.classLabel!.isHidden = true
				}
				return
			}
			
			print(result.labels[0].identifier)
			
			// denormalise bounding box of object
			let boundingBoxPoints = calculateBoundingBoxPoints(from: result.boundingBox, in: frameRect!)
			

			//get 3d coordinate
			guard let surfaceCenter = getPointOnSurface(cgPoint: sceneView.center) else {
				hitObjectDistanceFromCamera = nil // otherwise nil
				return
			}
			
			// get screen Position of the different nodes
			
			let transform = frame.camera.transform.columns.3
			let devicePosition = simd_float3(x: transform.x, y: transform.y, z: transform.z)
			let distanceToSurface = distance(devicePosition,surfaceCenter)
			hitObjectDistanceFromCamera = -distanceToSurface
			
			// distance of object infront of camera
			let infrontOfCamera = SCNVector3(x: 0, y: 0, z: -distanceToSurface)
			guard let cameraNode = sceneView.pointOfView else { return }
			
			// update nodes points
			let deNormalizedPositions = [
				(x: boundingBoxPoints.topLeft.x, y: boundingBoxPoints.topLeft.y),
				(x: boundingBoxPoints.topRight.x, y: boundingBoxPoints.topRight.y),
				(x: boundingBoxPoints.bottomLeft.x, y: boundingBoxPoints.bottomLeft.y),
				(x: boundingBoxPoints.bottomRight.x, y: boundingBoxPoints.bottomRight.y)
			]
			
			// add nodes to display
			nodeManager.updateNodePositions(sceneView: sceneView, cameraNode: cameraNode, inFrontOfCamera: infrontOfCamera, deNormalizedPositions: deNormalizedPositions)
			
			// add lines between 2 notes to visualise the bounding box in 3D Space
			nodeManager.createAndAddLines(to: sceneView.scene)
			
			
			//DispatchQueue.main.async {
				// add bounding overlay rectangle to view
				print("displaying item")
				
				self.classLabel!.isHidden = false
				self.classLabel!.frame = CGRect(
					x: boundingBoxPoints.topLeft.x,
					y: boundingBoxPoints.topLeft.y,
					width: boundingBoxPoints.topRight.x - boundingBoxPoints.topLeft.x,
					height: boundingBoxPoints.bottomLeft.y - boundingBoxPoints.topLeft.y
				)
				
				//measure distance between points
				let LRcmDistance = floor(distance(self.nodeManager.LCNode.simdWorldPosition, self.nodeManager.RCNode.simdWorldPosition) * 1000) / 10
				let TBcmDistance = floor(distance(self.nodeManager.TCNode.simdWorldPosition, self.nodeManager.BCNode.simdWorldPosition) * 1000) / 10
				
				print("\(result.labels.first!.identifier)\nw: \(LRcmDistance) cm\nh: \(TBcmDistance) cm")
				
				self.classLabel!.text = "\(result.labels.first!.identifier)\nw: \(LRcmDistance) cm\nh: \(TBcmDistance) cm"
				
			//}

		} catch let error {
			DispatchQueue.main.async {
				self.classLabel!.isHidden = true
			}
			print(error)
		}
		
	}
	
	

	// MARK: - ARSCNViewDelegate - For Anchor related content
	
	func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
		// tells render to make changes before animation appears
		guard let hitObjectDistanceFromCamera = hitObjectDistanceFromCamera else {
			nodeManager.bgNode.isHidden = true
			return
		}
		nodeManager.bgNode.isHidden = false
		
		// Node position is left and right: 0m, top and bottom: 0m, 50cm deep
		let position = SCNVector3(x: 0, y: 0, z: hitObjectDistanceFromCamera)
		
		if let camera = arView!.pointOfView {
			// Position determined by deviation from camera position
			nodeManager.bgNode.position = camera.convertPosition(position, to: nil)
			
			// Make it the same as the Euler angle of the camera
			nodeManager.bgNode.eulerAngles = camera.eulerAngles
			print(nodeManager.bgNode.simdTransform)
		}

	}
	
	func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		// when an anchor has been added to sceneKit
		
		//TODO: add plane anchor for display of plane
		
		// Place content only for anchors found by plane detection.
		guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
		
		// Create a custom object to visualize the plane geometry and extent.
		let plane = Plane(anchor: planeAnchor, in: arView!)
		
		// Add the visualization to the ARKit-managed node so that it tracks
		// changes in the plane anchor as plane estimation continues.
        //node.addChildNode(plane)
	}
	
	func renderer(_ renderer: any SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
		// Update only anchors and nodes set up by `renderer(_:didAdd:for:)
		
		//TODO: add plane anchor for display of plane
		guard let planeAnchor = anchor as? ARPlaneAnchor,
			let plane = node.childNodes.first as? Plane
			else { return }
		
		// Update ARSCNPlaneGeometry to the anchor's new estimated shape.
		if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
			planeGeometry.update(from: planeAnchor.geometry)
		}

		// Update extent visualization to the anchor's new bounding rectangle.
		if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
			extentGeometry.width = CGFloat(planeAnchor.extent.x)
			extentGeometry.height = CGFloat(planeAnchor.extent.z)
			plane.extentNode.simdPosition = planeAnchor.center
		}
		
		// Update the plane's classification and the text position
		if #available(iOS 12.0, *),
			let classificationNode = plane.classificationNode,
			let classificationGeometry = classificationNode.geometry as? SCNText {
			let currentClassification = planeAnchor.classification.description
			if let oldClassification = classificationGeometry.string as? String, oldClassification != currentClassification {
				classificationGeometry.string = currentClassification
				classificationNode.centerAlign()
			}
		}
	}
	
	
	// MARK: - ARSessionDelegate
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		// when frame updates are made
			// this is where we make calls to Vision
		guard let sceneView = arView else {return}
		
		guard let query = sceneView.raycastQuery(from:sceneView.center, allowing: .existingPlaneGeometry, alignment: .any) else {return}
		let hitTestReults = sceneView.session.raycast(query)
		guard let result = hitTestReults.first else {return}
		
		
		// get x,y,z pos of camera -> to get distance of object from camera
		let cameraPos = frame.camera.transform.columns.3
		let devicePos = simd_float3(x: cameraPos.x, y: cameraPos.y, z: cameraPos.z)
		
		let hitCoordinates = simd_float3(x: result.worldTransform.columns.3.x, y: result.worldTransform.columns.3.y, z: result.worldTransform.columns.3.z)
		
		let distance = distance(devicePos, hitCoordinates)
		print("Distance from Device: \(distance)")
		
		// get frame of camera image as pixel buffer
		let pixelBuffer = frame.capturedImage
		
		detectObject(pixelBuffer: pixelBuffer, frame: frame)
		
//		let camera = frame.camera
//		// center of screen
//		let screenPos = CGPoint(x: 0.5, y: 0.5)
//		let cameraTransform = camera.transform
//		
//		// Convert the position on the screen to the position in AR space
//		guard let worldPosition = camera.unprojectPoint(screenPos, ontoPlane: cameraTransform, orientation: .portrait, viewportSize: sceneView.bounds.size) else { return }
//
//		// Calculate the position of the plane
//		let translation = simd_float3(worldPosition.x, worldPosition.y, worldPosition.z)
//		
//		// The rotation of the plane is parallel to the camera, so the rotation matrix is ​​an identity matrix.
//		let rotation = simd_float4x4(diagonal: simd_float4(1.0, 1.0, 1.0, 1.0))
//		
//		// set the plane pose matrix
//		//Use planeTransform to do what you want
//		let planeTransform = simd_mul(simd_float4x4(translation: translation), rotation)
//		print(planeTransform)
//		
		
	}
	
	func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
		//
		guard let frame = session.currentFrame else { return }
	}
	
	func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
		//when achor is removed
		guard let frame = session.currentFrame else { return }

	}
	
	func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
		// change in camera tracking state
	}
	
	// MARK: - ARSessionObserver
	func sessionWasInterrupted(_ session: ARSession) {
		//
		print("session was interrupted")
	}
	
	func sessionInterruptionEnded(_ session: ARSession) {
		// when session resumes back after interruption
		print("session interruped ended")
		resetTracking();
	}
	
	func session(_ session: ARSession, didFailWithError error: any Error) {
		// when session fails to run
		print("session failed")
		print(error)
	}
	
	
	private func resetTracking() {
		let configuration = ARWorldTrackingConfiguration()
		configuration.planeDetection = [.horizontal, .vertical]
		arView!.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
	}
	
	private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
		// Update the UI to provide feedback on the state of the AR experience.
		let message: String

		switch trackingState {
		case .normal where frame.anchors.isEmpty:
			// No planes detected; provide instructions for this app's AR interactions.
			message = "Move the device around to detect horizontal and vertical surfaces."
			
		case .notAvailable:
			message = "Tracking unavailable."
			
		case .limited(.excessiveMotion):
			message = "Tracking limited - Move the device more slowly."
			
		case .limited(.insufficientFeatures):
			message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
			
		case .limited(.initializing):
			message = "Initializing AR session."
			
		default:
			// No feedback needed when tracking is normal and planes are visible.
			// (Nor when in unreachable limited-tracking states.)
			message = ""

		}

		print(message)
		//sessionInfoLabel.text = message
		//sessionInfoView.isHidden = message.isEmpty
	}

	
	// Helper functions
	//TODO: put under Utils
	
	// designed to find and return the 3D world coordinates of a point on a surface in an AR scene based on a 2D screen coordinate
	func getPointOnSurface(cgPoint: CGPoint) -> simd_float3? {
		guard let sceneView = arView else {return nil}
		
		let raycastQuery = sceneView.raycastQuery(from: cgPoint, allowing: .estimatedPlane, alignment: .any)
		if let unwrappedRaycastQuery = raycastQuery {
			let raycastResults = sceneView.session.raycast(unwrappedRaycastQuery)
			guard let result = raycastResults.first else { return nil }
			let worldCoordinates = simd_float3(
				x: result.worldTransform.columns.3.x,
				y: result.worldTransform.columns.3.y,
				z: result.worldTransform.columns.3.z
			)
			return worldCoordinates
		} else {
			return nil
		}
	}
	
	// Helper functions
	private func calculateBoundingBoxPoints(from boundingBox: CGRect, in frameRect: CGRect?) -> (topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
		// calculate coordinate of bounding box around dected object
		let topLeft = CGPoint(x: boundingBox.minX, y: 1 - boundingBox.maxY)
		let topRight = CGPoint(x: boundingBox.maxX, y: 1 - boundingBox.maxY)
		let bottomLeft = CGPoint(x: boundingBox.minX, y: 1 - boundingBox.minY)
		let bottomRight = CGPoint(x: boundingBox.maxX, y: 1 - boundingBox.minY)
		
		//return normalized coordinates to screen coordinates
		return (deNormalize(point: topLeft, frameRect: frameRect),
				deNormalize(point: topRight, frameRect: frameRect),
				deNormalize(point: bottomLeft, frameRect: frameRect),
				deNormalize(point: bottomRight, frameRect: frameRect))
	}
	
	private func deNormalize(point: CGPoint, frameRect: CGRect?) -> CGPoint {
		return VNImagePointForNormalizedPoint(point, Int(frameRect!.width), Int(frameRect!.height))
	}
}

// Stores info of detected item
struct DetectionContainer
{
	let box:CGRect
	let confidence:Float
	let label:String?
	let color:UIColor
}

// perform drawing of overlay of container
func drawOverlay(_ detections: [DetectionContainer], _ ciImage: CIImage) -> UIImage? {
	return nil
}

#Preview {
    ARContentView()
}

//TODO: put in different files
extension CGPoint {
	func toVector(image: CIImage) -> CIVector {
		return CIVector(x: x, y: image.extent.height-y)
	}
}
extension CIImage {
	func resize(as size: CGSize) -> CIImage {
		let selfSize = extent.size
		let transform = CGAffineTransform(scaleX: size.width / selfSize.width, y: size.height / selfSize.height)
		return transformed(by: transform)
	}
}

extension float4x4 {
	init(translation vector: SIMD3<Float>) {
		self.init(SIMD4<Float>(1, 0, 0, 0),
				  SIMD4<Float>(0, 1, 0, 0),
				  SIMD4<Float>(0, 0, 1, 0),
				  SIMD4<Float>(vector.x, vector.y, vector.z, 1))
	}
}

extension SCNNode {
	func centerAlign() {
		let (min, max) = boundingBox
		let extents = SIMD3<Float>(max) - SIMD3<Float>(min)
		simdPivot = float4x4(translation: ((extents / 2) + SIMD3<Float>(min)))
	}
}

@available(iOS 12.0, *)
extension ARPlaneAnchor.Classification {
	var description: String {
		switch self {
		case .wall:
			return "Wall"
		case .floor:
			return "Floor"
		case .ceiling:
			return "Ceiling"
		case .table:
			return "Table"
		case .seat:
			return "Seat"
		case .none(.unknown):
			return "Unknown"
		default:
			return ""
		}
	}
}
