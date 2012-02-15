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

@protocol DSMRTimelineViewDelegate

- (NSArray *)timelineMarkers;

@end

#pragma mark -

@interface DSMRTimelineView : UIView <UIScrollViewDelegate>

@property (nonatomic, weak) id <DSMRTimelineViewDelegate>delegate;
@property (nonatomic, assign, getter=isExporting) BOOL exporting;

- (void)togglePlay;
- (void)redrawMarkers;
- (void)rewindToBeginning;

@end