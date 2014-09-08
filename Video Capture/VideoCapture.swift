//
//  VideoCapture.swift
//  Video Capture
//
//  Created by Shahan Khan on 9/4/14.
//  Copyright (c) 2014 Shahan Khan. All rights reserved.
//

import Foundation
import CoreMedia
import AVFoundation
import AssetsLibrary
import UIKit

enum VideoCaptureQuality {
	case Normal
}

enum VideoCaptureCamera {
	case Front
	case Back
}

// MARK: - Video Capture Delegate Protocol
protocol VideoCaptureDelegate {
	func videoCaptureError(message :String)
	func videoCaptureMicrophoneDenied()
	func videoCaptureCameraDenied()
	func videoCaptureFinished(url :NSURL)
	func videoCaptureElapsed(seconds: Double)
}

// MARK: - Video Capture Class
class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
	// MARK: Private Properties
	private var delegate :VideoCaptureDelegate?
	private var previewLayer :VideoCapturePreviewLayer?
	
	private var session :AVCaptureSession?
	private var outputUrl :NSURL?
	private var captureQueue :dispatch_queue_t?
	private var serialQueue :dispatch_queue_t?
	
	private var currentCamera :VideoCaptureCamera = VideoCaptureCamera.Front
	private var videoDevice :AVCaptureDevice?
	private var videoInput :AVCaptureDeviceInput?
	private var videoOutput :AVCaptureVideoDataOutput?

	private var audioInput :AVCaptureDeviceInput?
	private var audioDevice :AVCaptureDevice?
	private var audioOutput :AVCaptureAudioDataOutput?

	private var errorOccurred = false
	private var recording = false
	private var elapsed = 0.0
	
	// MARK: - Computed / Public Properties
	// number of seconds
	var duration = 10.0
	
	var ready: Bool {
		return !errorOccurred && session != nil && videoDevice != nil && audioDevice != nil && videoInput != nil && audioInput != nil && videoOutput != nil && audioOutput != nil && outputUrl != nil
	}
	
	// quality is only set when start is called
	var quality :VideoCaptureQuality = VideoCaptureQuality.Normal
	
	// the camera. defaults to front
	var camera :VideoCaptureCamera {
		set(camera) {
			// cannot change camera while recording
			if recording {
				return
			}
			
			currentCamera = camera
			
			// update preview
			if ready {
				session?.beginConfiguration()
				
				var newVideoDevice = cameraDevice(currentCamera)
				var error = NSErrorPointer()
				var newVideoInput = AVCaptureDeviceInput(device: newVideoDevice, error: error)
				
				if error == nil {
					session?.removeInput(videoInput)
					videoInput = newVideoInput
					videoDevice = newVideoDevice
					
					if session!.canAddInput(videoInput) {
						session?.addInput(videoInput)
					}
				}
				
				session?.commitConfiguration()
			}
		}
		get {
			return currentCamera
		}
	}
	
	// MARK: - Init Function
	// duration is number of seconds
	init(previewLayer :VideoCapturePreviewLayer?, delegate :VideoCaptureDelegate?) {
		self.delegate = delegate
		self.previewLayer = previewLayer
	}
	
	// MARK: - Video / Audio Capture Data Output Delegate
	func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
		if ready && recording {
			dispatch_sync(serialQueue, {
				if captureOutput.connectionWithMediaType(AVMediaTypeAudio) == connection {
					NSLog("audio output!")
				} else {
					NSLog("video output!")
				}
			})
		}
	}

	// MARK: - Recording Lifecycle
	// starts the preview
	func start() {
		// check if already setup
		if ready {
			return
		}
		
		// Check for Camera Permissions
		var videoStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
		
		if videoStatus == AVAuthorizationStatus.Denied {
			delegate?.videoCaptureCameraDenied()
			return
		}
		
		// Check for Microphone Permissions
		var audioStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
		
		if audioStatus == AVAuthorizationStatus.Denied {
			delegate?.videoCaptureMicrophoneDenied()
			return
		}
		
		// setup video capturing session
		session = AVCaptureSession()
		
		// setup video device
		videoDevice = cameraDevice(currentCamera)
		
		if videoDevice == nil {
			error("Could not setup a video capture device")
			return
		}
		
		// setup video input
		var err = NSErrorPointer()
		videoInput = AVCaptureDeviceInput.deviceInputWithDevice(videoDevice, error: err) as? AVCaptureDeviceInput
		
		if err == nil {
			if (session?.canAddInput(videoInput) != nil) {
				session?.addInput(videoInput)
			} else {
				error("Could not add video device input to session")
				return
			}
		} else {
			error("Could not create a video device input")
			return
		}
		
		// setup audio input
		audioDevice	= AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
		
		if audioDevice == nil {
			error("Could not setup an audio capture device")
			return
		}
		
		// setup audio device
		err = NSErrorPointer()
		audioInput = AVCaptureDeviceInput.deviceInputWithDevice(audioDevice, error: err) as? AVCaptureDeviceInput
		
		if err == nil {
			if (session?.canAddInput(audioInput) != nil) {
				session?.addInput(audioInput)
			} else {
				error("Could not add audio device input to session")
				return
			}
		} else {
			error("Could not create an audio device input")
			return
		}
		
		// setup video qualtity
		switch quality {
		default:
			if session? != nil && session!.canSetSessionPreset(AVCaptureSessionPreset640x480) {
				session?.sessionPreset = AVCaptureSessionPreset640x480
			}
		}
		
		// setup preview layer
		previewLayer?.session = session
		
		// setup capture queue
		captureQueue = dispatch_queue_create("com.videocapture.capturequeue", DISPATCH_QUEUE_SERIAL)
		
		// setup video output
		videoOutput = AVCaptureVideoDataOutput()
		videoOutput?.setSampleBufferDelegate(self, queue: captureQueue)
		session?.addOutput(videoOutput)
		
		// setup audio output
		audioOutput = AVCaptureAudioDataOutput()
		audioOutput?.setSampleBufferDelegate(self, queue: captureQueue)
		session?.addOutput(audioOutput)

		// setup assetwrite
		serialQueue = dispatch_queue_create("com.videocapture.serialqueue", nil)
		
		// get a temporary file for output
		var path = "\(NSTemporaryDirectory())output.mov"
		outputUrl = NSURL(fileURLWithPath: path)
		
		// start running the session
		session?.startRunning()
	}
	
	// stops recording and video capture
	func stop() {
		if recording {
			pause()
		}
		
		session?.stopRunning()
		errorOccurred = false
		session = nil
		videoDevice = nil
		videoInput = nil
		videoOutput = nil
		audioDevice = nil
		audioInput = nil
		audioOutput = nil
		captureQueue = nil
		serialQueue = nil
		outputUrl = nil
		elapsed = 0
	}
	
	// start video recording
	func record() {
		if !ready {
			throw("Need to check if ready before trying to record")
			return
		}
		
		recording = true
	}
	
	// pause video recording
	func pause() {
		recording = false
	}
	
	// MARK: - Multiple Cameras
	func cameraDevice(type: VideoCaptureCamera) -> AVCaptureDevice {
		var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
		
		for device in devices as [AVCaptureDevice] {
			if type == VideoCaptureCamera.Back && device.position == AVCaptureDevicePosition.Back {
				return device
			}
			
			if type == VideoCaptureCamera.Front && device.position == AVCaptureDevicePosition.Front {
				return device
			}
		}
		
		return devices[0] as AVCaptureDevice
	}
	
	func availableCameras() -> [VideoCaptureCamera] {
		var cameras :[VideoCaptureCamera] = []
		
		// get cameras
		var devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
		
		for device in devices as [AVCaptureDevice] {
			if device.position == AVCaptureDevicePosition.Back {
				cameras.append(VideoCaptureCamera.Back)
			} else {
				cameras.append(VideoCaptureCamera.Front)
			}
		}
		
		return cameras
	}
	
	// MARK: - Error Handling
	private func throw(message :String) {
		errorOccurred = true
		NSException(name: "VideoCaptureException", reason: message, userInfo: nil).raise()
	}
	
	private func error(message :String) {
		errorOccurred = true
		delegate?.videoCaptureError(message)
	}
}