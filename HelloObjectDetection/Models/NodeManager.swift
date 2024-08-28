//
//  NodeManager.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 28/8/24.
//

import Foundation
import SceneKit
import ARKit

// A class for managing the creation and properties of SCNNode
class NodeFactory {
	static func createNode(withColor color: UIColor, radius: CGFloat = 0.01, position: SCNVector3 = SCNVector3(x: 0, y: 10, z: 0)) -> SCNNode {
		let node = SCNNode(geometry: SCNSphere(radius: radius))
		node.worldPosition = position
		node.geometry?.materials.first?.diffuse.contents = color
		return node
	}
}

// Nodes managed by NodeFactory
class NodeManager {
	// Base node
	var baseNode = SCNNode()

	// Nodes
	var TLNode: SCNNode
	var TRNode: SCNNode
	var BLNode: SCNNode
	var BRNode: SCNNode
	var LCNode: SCNNode
	var RCNode: SCNNode
	var TCNode: SCNNode
	var BCNode: SCNNode

	// Line nodes
	var LRLineNode: SCNNode?
	var TBLineNode: SCNNode?

	// Background node
	var bgNode: SCNNode

	init() {
		let orangeColor = UIColor.orange
		TLNode = NodeFactory.createNode(withColor: orangeColor)
		TRNode = NodeFactory.createNode(withColor: orangeColor)
		BLNode = NodeFactory.createNode(withColor: orangeColor)
		BRNode = NodeFactory.createNode(withColor: orangeColor)
		LCNode = NodeFactory.createNode(withColor: orangeColor)
		RCNode = NodeFactory.createNode(withColor: orangeColor)
		TCNode = NodeFactory.createNode(withColor: orangeColor)
		BCNode = NodeFactory.createNode(withColor: orangeColor)

		//bgNode = NodeFactory.createNode(withColor: orangeColor.withAlphaComponent(0.3), radius: 50, position: xSCNVector3(x: 0, y: 10, z: 0))
		//bgNode.geometry = SCNPlane(width: 100, height: 100)
		bgNode = SCNNode(geometry: SCNPlane(width: 100, height: 100))
		bgNode.worldPosition = SCNVector3(x: 0, y: 10, z: 0)
		bgNode.geometry?.materials.first?.diffuse.contents = UIColor.orange.withAlphaComponent(0.3)
		
		baseNode.addChildNode(TLNode)
		baseNode.addChildNode(TRNode)
		baseNode.addChildNode(BLNode)
		baseNode.addChildNode(BRNode)
		
		baseNode.addChildNode(LCNode)
		baseNode.addChildNode(RCNode)
		baseNode.addChildNode(BCNode)
		baseNode.addChildNode(TCNode)
		
		//baseNode.addChildNode(bgNode)
	}
	
//	private var nodes: [String: SCNNode] = [:]
//
//	func addNode(named name: String, to parentNode: SCNNode) {
//		guard let node = nodes[name] else { return }
//		parentNode.addChildNode(node)
//	}

//	func setNodeVisibility(named name: String, isVisible: Bool) {
//		nodes[name]?.isHidden = !isVisible
//	}

//	// Initialize nodes
//	func createNode(named name: String, geometry: SCNGeometry, color: UIColor, position: SCNVector3) {
//		let node = SCNNode(geometry: geometry)
//		node.worldPosition = position
//		node.geometry?.materials.first?.diffuse.contents = color
//		nodes[name] = node
//	}
	
	func updateNodePositions(sceneView: ARSCNView, cameraNode: SCNNode, inFrontOfCamera: SCNVector3, deNormalizedPositions: [(x: CGFloat, y: CGFloat)]) {
		
			let pointInWorld = cameraNode.convertPosition(inFrontOfCamera, to: nil)

			var screenPos = sceneView.projectPoint(pointInWorld)

			let nodes = [TLNode, TRNode, BLNode, BRNode]
			for (index, node) in nodes.enumerated() {
				screenPos.x = Float(deNormalizedPositions[index].x)
				screenPos.y = Float(deNormalizedPositions[index].y)
				node.worldPosition = sceneView.unprojectPoint(screenPos)
			}

			updateCenterNodes()
		}

		private func updateCenterNodes() {
			LCNode.simdWorldPosition = calculateCenterPosition(nodes: [BLNode, TLNode])
			RCNode.simdWorldPosition = calculateCenterPosition(nodes: [BRNode, TRNode])
			TCNode.simdWorldPosition = calculateCenterPosition(nodes: [TLNode, TRNode])
			BCNode.simdWorldPosition = calculateCenterPosition(nodes: [BLNode, BRNode])
		}

		private func calculateCenterPosition(nodes: [SCNNode]) -> SIMD3<Float> {
			return SIMD3(
				x: (nodes[0].simdWorldPosition.x + nodes[1].simdWorldPosition.x) / 2,
				y: (nodes[0].simdWorldPosition.y + nodes[1].simdWorldPosition.y) / 2,
				z: (nodes[0].simdWorldPosition.z + nodes[1].simdWorldPosition.z) / 2
			)
		}

		func createAndAddLines(to scene: SCNScene) {
			if self.LRLineNode != nil {
				LRLineNode?.removeFromParentNode()
			}
			
			LRLineNode = lineBetweenNodes(positionA: LCNode.worldPosition, positionB: RCNode.worldPosition, inScene: scene)
			LRLineNode?.geometry?.materials.first?.readsFromDepthBuffer = false
			scene.rootNode.addChildNode(LRLineNode!)
			
			if self.TBLineNode != nil {
				self.TBLineNode?.removeFromParentNode()
			}
			TBLineNode = lineBetweenNodes(positionA: TCNode.worldPosition, positionB: BCNode.worldPosition, inScene: scene)
			TBLineNode?.geometry?.materials.first?.readsFromDepthBuffer = false
			scene.rootNode.addChildNode(TBLineNode!)
		}

		private func lineBetweenNodes(positionA: SCNVector3, positionB: SCNVector3, inScene scene: SCNScene) -> SCNNode {
			let vector = SCNVector3(positionA.x - positionB.x, positionA.y - positionB.y, positionA.z - positionB.z)
			let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
			let midPosition = SCNVector3 (x:(positionA.x + positionB.x) / 2, y:(positionA.y + positionB.y) / 2, z:(positionA.z + positionB.z) / 2)

			let lineGeometry = SCNCylinder()
			lineGeometry.radius = 0.005
			lineGeometry.height = CGFloat(distance)
			lineGeometry.radialSegmentCount = 5
			lineGeometry.firstMaterial!.diffuse.contents = UIColor.orange

			let lineNode = SCNNode(geometry: lineGeometry)
			lineNode.position = midPosition
			lineNode.look (at: positionB, up: scene.rootNode.worldUp, localFront: lineNode.worldUp)
		
			return lineNode
		}
}

extension SCNGeometry {
	class func lineFrom(vector vectorA: SCNVector3, toVector vectorB: SCNVector3) -> SCNGeometry {
		let indices: [Int32] = [0, 1]
		let source = SCNGeometrySource(vertices: [vectorA, vectorB])
		let element = SCNGeometryElement(indices: indices, primitiveType: .line)
		return SCNGeometry(sources: [source], elements: [element])
	}
}

// Example usage
//let nodeManager = NodeManager()
