//
//  CIImage+Extension.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 27/8/24.
//

import CoreImage
import SwiftUI

extension CIImage {
	
	var cgImage: CGImage? {
		let ciContext = CIContext()
		
		guard let cgImage = ciContext.createCGImage(self, from: self.extent) else {
			return nil
		}
		
		return cgImage
	}
	
	var image: Image? {
			let ciContext = CIContext()
			guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
			return Image(decorative: cgImage, scale: 1, orientation: .up)
	}
	
	
}
