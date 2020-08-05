#import <Foundation/Foundation.h>

#import "RTCMacros.h"

NS_ASSUME_NONNULL_BEGIN

RTC_OBJC_EXPORT
@interface RTC_OBJC_TYPE (RTCAudioSink) : NSObject

- (void) OnData:(const void*) audio_data
bits_per_sample:(int)bits_per_sample
sample_rate:(int)sample_rate
number_of_channels:(size_t)number_of_channels
number_of_frames:(size_t)number_of_frames;

@end

NS_ASSUME_NONNULL_END
