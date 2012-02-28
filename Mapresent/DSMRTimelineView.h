//
//  DSMRTimelineView.h
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSMRTimelineView;
@class DSMRTimelineMarkerView;

static NSString *DSMRTimelineViewPlayToggled     = @"DSMRTimelineViewPlayToggled";
static NSString *DSMRTimelineViewPlayProgressed  = @"DSMRTimelineViewPlayProgressed";

@protocol DSMRTimelineViewDelegate

@required

- (NSArray *)markersForTimelineView:(DSMRTimelineView *)timelineView;
- (void)timelineView:(DSMRTimelineView *)timelineView markerViewTapped:(DSMRTimelineMarkerView *)tappedMarkerView;
- (void)timelineView:(DSMRTimelineView *)timelineView markerViewDoubleTapped:(DSMRTimelineMarkerView *)tappedMarkerView;
- (void)timelineView:(DSMRTimelineView *)timelineView markersChanged:(NSArray *)changedMarkers;

@end

#pragma mark -

@interface DSMRTimelineView : UIView <UIScrollViewDelegate>

@property (nonatomic, weak) id <DSMRTimelineViewDelegate>delegate;
@property (nonatomic, readonly, assign, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly, strong) NSArray *markerPassthroughViews;

- (void)togglePlay;
- (void)redrawMarkers;
- (void)rewindToBeginning;

@end