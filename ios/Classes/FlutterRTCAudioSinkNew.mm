#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "FlutterRTCAudioSinkNew.h"
#include <syslog.h>

@implementation FlutterRTCAudioSinkNew

- (void) OnData:(const void*) audio_data
  bits_per_sample:(int)bits_per_sample
  sample_rate:(int)sample_rate
  number_of_channels:(size_t)number_of_channels
  number_of_frames:(size_t)number_of_frames {
    syslog(LOG_ERR, "!!!!!!!!!!!!!!!! IN THE PLUGIN ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^!");

    AudioBufferList audioBufferList;
    AudioBuffer audioBuffer;
    audioBuffer.mData = (void*) audio_data;
    audioBuffer.mDataByteSize = bits_per_sample / 8 * number_of_channels * number_of_frames;
    audioBuffer.mNumberChannels = number_of_channels;
    audioBufferList.mNumberBuffers = 1;
    audioBufferList.mBuffers[0] = audioBuffer;
    AudioStreamBasicDescription audioDescription;
    audioDescription.mBytesPerFrame = bits_per_sample / 8 * number_of_channels;
    audioDescription.mBitsPerChannel = bits_per_sample;
    audioDescription.mBytesPerPacket = bits_per_sample / 8 * number_of_channels;
    audioDescription.mChannelsPerFrame = number_of_channels;
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    audioDescription.mFramesPerPacket = 1;
    audioDescription.mReserved = 0;
    audioDescription.mSampleRate = sample_rate;
    CMAudioFormatDescriptionRef formatDesc;
    CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &audioDescription, 0, nil, 0, nil, nil, &formatDesc);
    CMSampleBufferRef buffer;
    CMSampleTimingInfo timing;
    timing.decodeTimeStamp = kCMTimeInvalid;
    timing.presentationTimeStamp = CMTimeMake(0, sample_rate);
    timing.duration = CMTimeMake(1, sample_rate);
    CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, formatDesc, number_of_frames * number_of_channels, 1, &timing, 0, nil, &buffer);
    CMSampleBufferSetDataBufferFromAudioBufferList(buffer, kCFAllocatorDefault, kCFAllocatorDefault, 0, &audioBufferList);

    @autoreleasepool {
        _format = formatDesc;
        if (_bufferCallback != nil) {
            _bufferCallback(buffer);
        } else {
            NSLog(@"################### Buffer callback is nil");
        }
    }
  }

@end
