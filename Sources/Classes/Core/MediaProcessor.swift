//
//  MediaProcessor.swift
//  MediaWatermark
//
//  Created by Sergei on 23/05/2017.
//  Copyright © 2017 rubygarage. All rights reserved.
//

import Foundation
import AVFoundation

public typealias ProcessProgressHandler = ((_ progress: Float) -> ())
public typealias ProcessCompletionHandler = ((_ result: MediaProcessResult, _ error: Error?) -> ())

public class MediaProcessor {
    public var filterProcessor: FilterProcessor! = nil
    
    public init() {}
    
    public func processElements(item: MediaItem, videoProgressHandler: ProcessProgressHandler? = nil, completion: @escaping ProcessCompletionHandler) {
        item.type == .video ? processVideoWithElements(item: item, progressHandler: videoProgressHandler, completion: completion) : processImageWithElements(item: item, completion: completion)
    }
    
    public func cancelVideoExporting() {
        self.videoExportSession?.cancelExport()
    }
    
    internal var videoExportSession: AVAssetExportSession?
}
