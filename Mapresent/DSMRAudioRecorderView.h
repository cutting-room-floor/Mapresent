//
//  DSMRAudioRecorderView.h
//  Mapresent
//
//  Created by Justin Miller on 2/15/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface DSMRAudioRecorderView : UIView

- (id)initWithAudioRecorder:(AVAudioRecorder *)inRecorder target:(id)target action:(SEL)action;

@end