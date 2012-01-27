//
//  DSMRTimelineView.h
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString *DSMRTimelineViewPlayToggled     = @"DSMRTimelineViewPlayToggled";
static NSString *DSMRTimelineViewPlayProgressed  = @"DSMRTimelineViewPlayProgressed";

@interface DSMRTimelineView : UIView <UIScrollViewDelegate>

- (void)togglePlay;

@end