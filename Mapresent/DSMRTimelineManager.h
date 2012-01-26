//
//  DSMRTimelineManager.h
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DSMRTimelineManager : NSObject

@property (nonatomic, strong, readonly) NSArray *events;

- (void)addTimelineEvent:(id)event atOffset:(NSTimeInterval)offset;

@end