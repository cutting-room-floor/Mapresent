//
//  DSMRTimelineManager.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineManager.h"

@interface DSMRTimelineManager ()

@property (nonatomic, strong) NSArray *events;

@end

#pragma mark -

@implementation DSMRTimelineManager

@synthesize events;

- (id)init
{
    self = [super init];
    
    if (self)
        events = [NSArray array];
    
    return self;
}

- (void)addTimelineEvent:(id)event atOffset:(NSTimeInterval)offset
{
}

@end