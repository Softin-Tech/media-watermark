//
//  MediaItemVideo.swift
//  MediaWatermark
//
//  Created by Sergei on 03/05/2017.
//  Copyright © 2017 rubygarage. All rights reserved.
//

import UIKit
import AVFoundation

let kMediaContentDefaultScale: CGFloat = 1
let kProcessedTemporaryVideoFileName = "/processed.mov"
let kMediaContentTimeValue: Int64 = 1
let kMediaContentTimeScale: Int32 = 30

extension MediaProcessor {
    func processVideoWithElements(item: MediaItem, progressHandler: ProcessProgressHandler? = nil, completion: @escaping ProcessCompletionHandler) {
        let mixComposition = AVMutableComposition()
        let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let clipVideoTrack = item.sourceAsset.tracks(withMediaType: AVMediaType.video).first
        let clipAudioTrack = item.sourceAsset.tracks(withMediaType: AVMediaType.audio).first
        
        do {
            try compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, item.sourceAsset.duration), of: clipVideoTrack!, at: kCMTimeZero)
        } catch {
            completion(MediaProcessResult(processedUrl: nil, image: nil), error)
        }
        
        if (clipAudioTrack != nil) {
            let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)

            do {
                try compositionAudioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, item.sourceAsset.duration), of: clipAudioTrack!, at: kCMTimeZero)
            } catch {
                completion(MediaProcessResult(processedUrl: nil, image: nil), error)
            }
        }
       
        compositionVideoTrack?.preferredTransform = (item.sourceAsset.tracks(withMediaType: AVMediaType.video).first?.preferredTransform)!
        
        let sizeOfVideo = item.size
        
        let optionalLayer = CALayer()
        processAndAddElements(item: item, layer: optionalLayer)
        optionalLayer.frame = CGRect(x: 0, y: 0, width: sizeOfVideo.width, height: sizeOfVideo.height)
        optionalLayer.masksToBounds = true
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: sizeOfVideo.width, height: sizeOfVideo.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: sizeOfVideo.width, height: sizeOfVideo.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(optionalLayer)
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(kMediaContentTimeValue, kMediaContentTimeScale)
        videoComposition.renderSize = sizeOfVideo
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, mixComposition.duration)
        
        let videoTrack = mixComposition.tracks(withMediaType: AVMediaType.video).first
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack!)
        layerInstruction.setTransform(transform(avAsset: item.sourceAsset, scaleFactor: kMediaContentDefaultScale), at: kCMTimeZero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        let processedUrl = processedMoviePath()
        clearTemporaryData(url: processedUrl, completion: completion)
        
        let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.videoComposition = videoComposition
        exportSession?.outputURL = processedUrl
        exportSession?.outputFileType = AVFileType.mp4
        
        exportSession?.exportAsynchronously(completionHandler: {
            if exportSession?.status == AVAssetExportSessionStatus.completed {
                DispatchQueue.main.async {
                    progressHandler?(1.0)
                    completion(MediaProcessResult(processedUrl: processedUrl, image: nil), nil)
                }
            } else {
                DispatchQueue.main.async {
                    completion(MediaProcessResult(processedUrl: nil, image: nil), exportSession?.error)
                }
            }
        })
        
        if let exportSession = exportSession, let progressHandler = progressHandler {
            self.callbackProgress(for: exportSession, progressHandler: progressHandler)
        }
    }
    
    // MARK: - private
    private func callbackProgress(for exportSession: AVAssetExportSession, progressHandler: @escaping ProcessProgressHandler) {
        if [.exporting, .waiting].contains(exportSession.status)  {
            progressHandler(exportSession.progress)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.callbackProgress(for: exportSession, progressHandler: progressHandler)
            }
        }
    }
    
    private func processAndAddElements(item: MediaItem, layer: CALayer) {
        for element in item.mediaElements {
            var elementLayer: CALayer! = nil
    
            if element.type == .view {
                elementLayer = CALayer()
                elementLayer.contents = UIImage(view: element.contentView).cgImage
            } else if element.type == .image {
                elementLayer = CALayer()
                elementLayer.contents = element.contentImage.cgImage
            } else if element.type == .text {
                elementLayer = CATextLayer()
                (elementLayer as! CATextLayer).string = element.contentText
            }

            elementLayer.frame = element.frame
            layer.addSublayer(elementLayer)
        }
    }
    
    private func processedMoviePath() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + kProcessedTemporaryVideoFileName
        return URL(fileURLWithPath: documentsPath)
    }
    
    private func clearTemporaryData(url: URL, completion: ProcessCompletionHandler!) {
        if (FileManager.default.fileExists(atPath: url.path)) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                completion(MediaProcessResult(processedUrl: nil, image: nil), error)
            }
        }
    }
    
    private func transform(avAsset: AVAsset, scaleFactor: CGFloat) -> CGAffineTransform {
        var offset = CGPoint.zero
        var angle: Double = 0
        
        switch avAsset.contentOrientation {
        case .left:
            offset = CGPoint(x: avAsset.contentCorrectSize.height, y: avAsset.contentCorrectSize.width)
            angle = Double.pi
        case .right:
            offset = CGPoint.zero
            angle = 0
        case .down:
            offset = CGPoint(x: 0, y: avAsset.contentCorrectSize.width)
            angle = -(Double.pi / 2)
        default:
            offset = CGPoint(x: avAsset.contentCorrectSize.height, y: 0)
            angle = Double.pi / 2
        }
        
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        let translation = scale.translatedBy(x: offset.x, y: offset.y)
        let rotation = translation.rotated(by: CGFloat(angle))
        
        return rotation
    }
}
