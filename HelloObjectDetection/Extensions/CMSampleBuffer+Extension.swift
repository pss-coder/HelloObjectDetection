//
//  CMSampleBuffer+Extension.swift
//  HelloObjectDetection
//
//  Created by Pawandeep Singh Sekhon on 27/8/24.
//

import AVFoundation
import CoreImage

extension CMSampleBuffer {
	
	/// get cgImage from pixel buffer
	var cgImage: CGImage? {
		let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(self)
		
		guard let imagePixelBuffer = pixelBuffer else {
			return nil
		}
		
		return CIImage(cvPixelBuffer: imagePixelBuffer).cgImage
	}
	
}
