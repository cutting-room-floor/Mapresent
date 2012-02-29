//
//  DSMRTimelineInspectorViewController.h
//  Mapresent
//
//  Created by Justin Miller on 2/28/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSMRTimelineInspectorViewController;
@class DSMRTimelineMarker;

@protocol DSMRTimelineInspectorDelegate <NSObject>

- (void)timelineInspector:(DSMRTimelineInspectorViewController *)timelineInspector wantsToDeleteMarker:(DSMRTimelineMarker *)marker;

@end

#pragma mark -

@interface DSMRTimelineInspectorViewController : UIViewController

@property (nonatomic, weak) id <DSMRTimelineInspectorDelegate>delegate;

- (id)initWithMarker:(DSMRTimelineMarker *)marker;

@end