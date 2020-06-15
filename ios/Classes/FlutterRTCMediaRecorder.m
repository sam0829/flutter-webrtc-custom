#import <AVFoundation/AVFoundation.h>
#import <WebRTC/WebRTC.h>
#import "FlutterRTCMediaRecorder.h"
#import "WebRTC/RTCVideoFrame.h"
#import "WebRTC/RTCCVPixelBuffer.h"
#import "WebRTC/RTCI420Buffer.h"
#import "WebRTC/RTCAudioTrack.h"
#import "FlutterRTCAudioSink.h"

#include "libyuv.h"

@implementation FlutterRTCMediaRecorder {
    int framesCount;
    bool isInitialized;
    CGSize _renderSize;
    RTCVideoRotation _rotation;
    FlutterRTCAudioSink* _audioSink;
    AVAssetWriterInput* _audioWriter;
}

- (instancetype)initWithVideoTrack:(RTCVideoTrack *)video audioTrack:(RTCAudioTrack *)audio outputFile:(NSURL *)out {
    self = [super init];
    _rotation  = -1;
    isInitialized = false;
    self.videoTrack = video;
    NSLog(@"💙💙💙out file is %@", out);
    self.output = out;
    [video addRenderer:self];
    framesCount = 0;
    /*if (audio != nil)
        _audioSink = [[FlutterRTCAudioSink alloc] initWithAudioTrack:audio];
    else
        NSLog(@"Audio track is nil");*/
    return self;
}

- (void)initialize:(CGSize)size {
    _renderSize = size;
    NSDictionary *videoSettings = @{
        AVVideoCompressionPropertiesKey: @{AVVideoAverageBitRateKey: @(6*1024*1024)},
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoHeightKey: @(size.height),
        AVVideoWidthKey: @(size.width),
    };
    self.writerInput = [[AVAssetWriterInput alloc]
            initWithMediaType:AVMediaTypeVideo
               outputSettings:videoSettings];
    self.writerInput.expectsMediaDataInRealTime = true;
    self.writerInput.mediaTimeScale = 30;

    if (_audioSink != nil) {
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
        NSDictionary*  audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                              [ NSNumber numberWithInt: 1 ], AVNumberOfChannelsKey,
                                              [ NSNumber numberWithFloat: 44100.0 ], AVSampleRateKey,
                                              [ NSData dataWithBytes: &acl length: sizeof( AudioChannelLayout ) ], AVChannelLayoutKey,
                                              [ NSNumber numberWithInt: 64000 ], AVEncoderBitRateKey,
                                              nil];
        _audioWriter = [[AVAssetWriterInput alloc]
                        initWithMediaType:AVMediaTypeAudio
                            outputSettings:audioOutputSettings
                        sourceFormatHint:_audioSink.format];
        _audioWriter.expectsMediaDataInRealTime = true;
    }

    NSError *error;
    self.assetWriter = [[AVAssetWriter alloc]
            initWithURL:self.output
               fileType:AVFileTypeMPEG4
                  error:&error];
    if (error != nil)
        NSLog(@"%@",[error localizedDescription]);
    self.assetWriter.shouldOptimizeForNetworkUse = true;
    [self.assetWriter addInput:self.writerInput];
    if (_audioWriter != nil && _audioSink != nil) {
        [self.assetWriter addInput:_audioWriter];
        _audioSink.bufferCallback = ^(CMSampleBufferRef buffer){
            if (self->_audioWriter.readyForMoreMediaData) {
                if (![self->_audioWriter appendSampleBuffer:buffer])
                    NSLog(@"Audioframe not appended %@", self.assetWriter.error);
            }
        };
    }
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];

    isInitialized = true;
}

- (void)setSize:(CGSize)size {
}

- (void)renderFrame:(nullable RTCVideoFrame *)frame {
    if (frame == nil) {
        return;
    }
    if (!isInitialized)
        [self initialize:CGSizeMake((CGFloat) frame.width, (CGFloat) frame.height)];
    if (!self.writerInput.readyForMoreMediaData) {
        NSLog(@"Drop frame, not ready");
        return;
    }
    id <RTCVideoFrameBuffer> buffer = frame.buffer;
    CVPixelBufferRef _pixelBufferRef = ((RTCCVPixelBuffer *) buffer).pixelBuffer;

    if (_pixelBufferRef == nil) {
        NSLog(@"Pixel buffer ref is nil");
        return;
    }

    CMVideoFormatDescriptionRef formatDescription;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, _pixelBufferRef, &formatDescription);

    CMSampleTimingInfo timingInfo;
    timingInfo.decodeTimeStamp = kCMTimeInvalid;
    //FIXME
    timingInfo.duration = CMTimeMake(1, 24);
    timingInfo.presentationTimeStamp = CMTimeMake(framesCount++, 24);

    CMSampleBufferRef outBuffer;

    status = CMSampleBufferCreateReadyWithImageBuffer(
            kCFAllocatorDefault,
            _pixelBufferRef,
            formatDescription,
            &timingInfo,
            &outBuffer);

    if (![self.writerInput appendSampleBuffer:outBuffer])
        NSLog(@"Frame not appended %@", self.assetWriter.error);
    CVPixelBufferRelease(_pixelBufferRef);
}

- (void)stop {
    if (_audioSink != nil) {
        _audioSink.bufferCallback = nil;
        [_audioSink close];
    }
    [self.videoTrack removeRenderer:self];
    [self.writerInput markAsFinished];
    if (_audioWriter != nil) {
        [_audioWriter markAsFinished];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
       [self.assetWriter finishWritingWithCompletionHandler:^{
           NSLog(@"Finished writing to file: %@", self.output);
           if (self.assetWriter.error != nil)
               NSLog(@"with error: %@", self.assetWriter.error);
       }];
    });
}

@end