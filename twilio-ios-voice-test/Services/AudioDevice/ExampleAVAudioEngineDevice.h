//
//  ExampleAVAudioEngineDevice.h
//  AudioDeviceExample
//
//  Copyright © 2018-2020 Twilio Inc. All rights reserved.
//

@import Foundation;
@import TwilioVoice;

NS_CLASS_AVAILABLE(NA, 11_0)
@interface ExampleAVAudioEngineDevice : NSObject <TVOAudioDevice>

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

- (void)playSignalSoundWithID:(NSInteger)soundID;

@end
