//
//  CameraManager.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 27/8/24.
//

import SwiftUI
import AVFoundation

class CameraManager: NSObject {
	
	// 1.performs real-time capture
	private let captureSession = AVCaptureSession()
	// 2. describes media input from capture device
	private var deviceInput: AVCaptureDeviceInput?
	// 3. object used to have access to video frames for processing
	private var videoOutput: AVCaptureVideoDataOutput?
	// 4. type of media to request capture
	private let systemPreferredCamera = AVCaptureDevice.default(for: .video)
	// 5. queue on which callback should be invoked, must have a unique label;for debugging
	private var sessionQueue = DispatchQueue(label: "video.preview.session")
	
	
	// manage the continuous stream of data that is coming from camera
	private var addToPreviewStream: ((CGImage) -> Void)?
		
		lazy var previewStream: AsyncStream<CGImage> = {
			AsyncStream { continuation in
				addToPreviewStream = { cgImage in
					continuation.yield(cgImage)
				}
			}
		}()
	
	private var isAuthorized: Bool {
		get async {
			let status = AVCaptureDevice.authorizationStatus(for: .video)
			
			// Determine if the user previously authorized camera access.
			var isAuthorized = status == .authorized
			
			// If the system hasn't determined the user's authorization status,
			// explicitly prompt them for approval.
			if status == .notDetermined {
				isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
			}
			
			return isAuthorized			
		}
	}
	
	
	override init() {
			super.init()
			
			Task {
				await configureSession()
				await startSession()
			}
		}
		
		// 2. initializing all our properties and defining the buffer delegate
		private func configureSession() async {
			// check
			guard await isAuthorized,
				  let systemPreferredCamera,
				  let deviceInput = try? AVCaptureDeviceInput(device: systemPreferredCamera)
			else {return}
			
			// start config
			captureSession.beginConfiguration()
			
			// at end of execution of method commits config to running sessoin
			defer {
				self.captureSession.commitConfiguration()
			}
			
			// set buffer delete and queue for invoking callbacks
			let videoOutput = AVCaptureVideoDataOutput()
			videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
			
			// check if input/output can be added to session
			guard captureSession.canAddInput(deviceInput) else {
				print("Unable to add device input to capture session.")
				return
			}
			
			guard captureSession.canAddOutput(videoOutput) else {
				print("Unable to add device output to capture session.")
				return
			}
			
			// add input/output
			captureSession.addInput(deviceInput)
			captureSession.addOutput(videoOutput)

		}
		
		// 3.
	func startSession() async {
			   // check auth
			guard await isAuthorized else {return}
			
			//start capture
			captureSession.startRunning()
		}
	
	func stopSession() {
		if captureSession.isRunning {
			captureSession.stopRunning()
		}
	}
	
	
}


// to receive the various buffer frames from the camera
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
	
	// called whenever the camera captures a new video frame
	func captureOutput(_ output: AVCaptureOutput,
					   didOutput sampleBuffer: CMSampleBuffer,
					   from connection: AVCaptureConnection) {
		guard let currentFrame = sampleBuffer.cgImage else { return }
		
		// portrait angle
		connection.videoRotationAngle = RotationAngle.portrait.rawValue
		addToPreviewStream?(currentFrame)
		
		//Vision Handler
		
		
		//CAN DO BETTER?
		// call vision handler
		//self.onVisionHandler!(currentFrame, bufferSize , rootLayer)
	}
	
}

private enum RotationAngle: CGFloat {
	case portrait = 90
	case portraitUpsideDown = 270
	case landscapeRight = 180
	case landscapeLeft = 0
}
