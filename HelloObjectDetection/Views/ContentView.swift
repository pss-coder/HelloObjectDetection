//
//  ContentView.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 27/8/24.
//

import SwiftUI


//#if targetEnvironment(simulator)
//#error("ARKit is not supported in iOS Simulator. Connect a physical iOS device and select it as your Xcode run destination, or select Generic iOS Device as a build-only destination.")
//#else

struct ContentView: View {
	
	@StateObject private var detectionModel = DetectionModel()
	
	@State private var imageSize: CGSize = .zero

	
    var body: some View {
        VStack {
            // Camera
			if let image = detectionModel.currentFrame {
				Image(decorative: image, scale: 1)
					.resizable()
					.scaledToFit()
					.overlay(content: {
						// getting size of image
						GeometryReader { geometry in
							DispatchQueue.main.async {
								self.imageSize = geometry.size
							}
							return Color.clear
						}
					})
					.overlay {
						// for when multiple observations made
						ForEach(0..<detectionModel.observations.count, id:\.self ) { index in
							
							let observation = detectionModel.observations[index]
							
							// get borders
							let (text, confidence, boxSize, boxPosition) = detectionModel.processObservation(observation, for: imageSize)
							
							// draw border around detected item
							RoundedRectangle(cornerRadius: 8)
								.stroke(.black, style: .init(lineWidth: 4.0))
								.overlay(alignment: .topLeading, content: {
									Text("\(text): \(confidence)")
										.background(.white)
										.foregroundColor(.blue)
										.offset(y: -28)
								})
//														.background(.white)
								.frame(width: boxSize.width, height: boxSize.height)
								.position(boxPosition)
						} // end ForEach
					}
			} else {
				Text("No Camera Feed")
			}
			
			Spacer()
			
			// Start/Stop Button
			Button(action: {
				if detectionModel.isCameraRunning {
					detectionModel.stopCamera()
				} else {
					Task {
						await detectionModel.startCamara()
					}
				}
			}, label: {
				Text(detectionModel.isCameraRunning ? "Stop Camera" : "Resume Camera")
			})
			
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
