#import <Foundation/Foundation.h>
#import "WebRTC/RTCAudioTrack.h"
#import "WebRTC/RTCAudioSource.h"
#import "WebRTC/RTCAudioSink.h"

@interface FlutterRTCAudioSinkNew : RTCAudioSink

@property (nonatomic, copy) void (^bufferCallback)(CMSampleBufferRef);
@property (nonatomic) CMAudioFormatDescriptionRef format;

- (void) OnData:(const void*) audio_data
bits_per_sample:(int)bits_per_sample
sample_rate:(int)sample_rate
number_of_channels:(size_t)number_of_channels
number_of_frames:(size_t)number_of_frames;
/*@property (nonatomic, copy) void (^bufferCallback)(CMSampleBufferRef);
@property (nonatomic) CMAudioFormatDescriptionRef format;

- (instancetype) initWithAudioTrack:(RTCAudioTrack* )audio;

- (void) close;*/

@end
