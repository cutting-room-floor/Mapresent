//
//  DSMRTimelineInspectorViewController.m
//  Mapresent
//
//  Created by Justin Miller on 2/28/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineInspectorViewController.h"

#import "DSMRTimelineMarker.h"

@interface DSMRTimelineInspectorViewController ()

- (IBAction)tappedDeleteButton:(id)sender;

@property (nonatomic, strong) DSMRTimelineMarker *marker;

@end

#pragma mark -

@implementation DSMRTimelineInspectorViewController

@synthesize delegate;
@synthesize marker=_marker;

- (id)initWithMarker:(DSMRTimelineMarker *)marker
{
    self = [super initWithNibName:nil bundle:nil];
    
    if (self)
        _marker = marker;
    
    return self;
}

#pragma mark -

- (IBAction)tappedDeleteButton:(id)sender
{
    [self.delegate timelineInspector:self wantsToDeleteMarker:self.marker];
}

@end