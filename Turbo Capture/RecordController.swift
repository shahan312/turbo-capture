//
//  RecordController.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

import UIKit
import MediaPlayer
import AssetsLibrary

class RecordController: UIViewController, TurboCaptureDelegate {
	// MARK: Properties
	var videoCapture :TurboCapture? = nil
	var previewLayer :TurboCapturePreviewLayer? = nil
	var duration :Double = 20
	
	// MARK: IBOutlets
	@IBOutlet weak var previewView: UIView!
	@IBOutlet weak var progressView: UIProgressView!
	
	// MARK: - Switch Camera
	@IBAction func switchCamera(sender: AnyObject) {
		videoCapture?.switchCamera()
	}
	
	// MARK: - Handle Record Button
	@IBAction func startRecording(sender: AnyObject) {		
		if videoCapture != nil && videoCapture!.ready {
			videoCapture?.record()
		}
	}
	
	@IBAction func stopRecording(sender: AnyObject) {
		videoCapture?.pause()
	}
	
	// MARK: - Video Capture Delegate
	func turboCaptureError(message :String) {
		UIAlertView(title: "Error", message: "Could not activate the camera or microphone.", delegate: nil, cancelButtonTitle: "Dismiss").show()
		NSLog("TurboCaptureError: \(message)")
	}
	
	func turboCaptureCameraDenied() {
		UIAlertView(title: "This app does not have access to your camera.", message: "You can enable access in Privacy Settings.", delegate: nil, cancelButtonTitle: "Dismiss").show()
	}
	
	func turboCaptureMicrophoneDenied() {
		UIAlertView(title: "This app does not have access to your microphone.", message: "You can enable access in Privacy Settings.", delegate: nil, cancelButtonTitle: "Dismiss").show()
	}
	
	func turboCaptureFinished(url :NSURL, thumbnail: UIImage?, duration: Double) {
		// write to photos library
		let library = ALAssetsLibrary()
		library.writeVideoAtPathToSavedPhotosAlbum(url, completionBlock: nil)
				
		// load PlaybackController
		let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("playback") as! PlaybackController
		controller.url = url
		self.presentViewController(controller, animated: true, completion: nil)
	}
	
	func turboCaptureElapsed(seconds: Double) {
		let value = seconds/duration
		progressView.setProgress(Float(value), animated: false)

		if value >= 1 {
			videoCapture?.stop()
			return
		}
	}

	// MARK: - View Controller Lifecycle
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		// setup the preview layer
		previewLayer = TurboCapturePreviewLayer(view: previewView)
		previewLayer?.aspectFill()
	
		// setup video capture + preview
		videoCapture = TurboCapture(previewLayer: previewLayer!, resolution: .VGA, quality: .High, type: .MOV, delegate: self)
	}
	
	override func prefersStatusBarHidden() -> Bool {
		return true
	}
}

