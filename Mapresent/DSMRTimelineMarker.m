//
//  DSMRTimelineMarker.m
//  Mapresent
//
//  Created by Justin Miller on 1/27/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineMarker.h"

@implementation DSMRTimelineMarker

@synthesize markerType;
@synthesize center;
@synthesize zoom;
@synthesize timeOffset;
@synthesize sourceName;
@synthesize snapshot;
@synthesize recording;
@synthesize duration;
@synthesize tileSourceInfo;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    
    if (self)
    {
        markerType     = [coder decodeIntForKey:@"markerType"];
        center         = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"centerLat"], [coder decodeDoubleForKey:@"centerLon"]);
        zoom           = [coder decodeFloatForKey:@"zoom"];
        timeOffset     = [coder decodeDoubleForKey:@"timeOffset"];
        sourceName     = [coder decodeObjectForKey:@"sourceName"];
        snapshot       = [coder decodeObjectForKey:@"snapshot"];
        recording      = [coder decodeObjectForKey:@"recording"];
        duration       = [coder decodeDoubleForKey:@"duration"];
        tileSourceInfo = [coder decodeObjectForKey:@"tileSourceInfo"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:markerType             forKey:@"markerType"];
    [coder encodeDouble:center.latitude     forKey:@"centerLat"];
    [coder encodeDouble:center.longitude    forKey:@"centerLon"];
    [coder encodeFloat:zoom                 forKey:@"zoom"];
    [coder encodeDouble:timeOffset          forKey:@"timeOffset"];
    [coder encodeObject:sourceName          forKey:@"sourceName"];
    [coder encodeObject:snapshot            forKey:@"snapshot"];
    [coder encodeObject:recording           forKey:@"recording"];
    [coder encodeDouble:duration            forKey:@"duration"];
    [coder encodeObject:tileSourceInfo      forKey:@"tileSourceInfo"];
}

@end