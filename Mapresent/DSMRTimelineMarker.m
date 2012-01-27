//
//  DSMRTimelineMarker.m
//  Mapresent
//
//  Created by Justin Miller on 1/27/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineMarker.h"

@implementation DSMRTimelineMarker

@synthesize southWest;
@synthesize northEast;
@synthesize center;
@synthesize timeOffset;
@synthesize sourceName;
@synthesize snapshot;
@synthesize recording;
@synthesize duration;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    if (self)
    {
        southWest  = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"swLat"],     [coder decodeDoubleForKey:@"swLon"]);
        northEast  = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"neLat"],     [coder decodeDoubleForKey:@"neLon"]);
        center     = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"centerLat"], [coder decodeDoubleForKey:@"centerLon"]);
        timeOffset = [coder decodeDoubleForKey:@"timeOffset"];
        sourceName = [coder decodeObjectForKey:@"sourceName"];
        snapshot   = [coder decodeObjectForKey:@"snapshot"];
        recording  = [coder decodeObjectForKey:@"recording"];
        duration   = [coder decodeDoubleForKey:@"duration"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:southWest.latitude  forKey:@"swLat"];
    [coder encodeDouble:southWest.longitude forKey:@"swLon"];
    [coder encodeDouble:southWest.latitude  forKey:@"neLat"];
    [coder encodeDouble:southWest.longitude forKey:@"neLon"];
    [coder encodeDouble:center.latitude     forKey:@"centerLat"];
    [coder encodeDouble:center.longitude    forKey:@"centerLon"];
    [coder encodeDouble:timeOffset          forKey:@"timeOffset"];
    [coder encodeObject:sourceName          forKey:@"sourceName"];
    [coder encodeObject:snapshot            forKey:@"snapshot"];
    [coder encodeObject:recording           forKey:@"recording"];
    [coder encodeDouble:duration            forKey:@"duration"];
}

@end