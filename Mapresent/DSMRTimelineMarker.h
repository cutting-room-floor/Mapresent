//
//  DSMRTimelineMarker.h
//  Mapresent
//
//  Created by Justin Miller on 1/27/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CoreLocation/CoreLocation.h>

typedef enum {
    DSMRTimelineMarkerTypeLocation     = 0,
    DSMRTimelineMarkerTypeAudio        = 1,
    DSMRTimelineMarkerTypeTheme        = 2,
    DSMRTimelineMarkerTypeDrawing      = 4,
    DSMRTimelineMarkerTypeDrawingClear = 8,
} DSMRTimelineMarkerType;

@interface DSMRTimelineMarker : NSObject <NSCoding>

@property (nonatomic, assign) DSMRTimelineMarkerType markerType;
@property (nonatomic, assign) CLLocationCoordinate2D southWest;
@property (nonatomic, assign) CLLocationCoordinate2D northEast;
@property (nonatomic, assign) CLLocationCoordinate2D center;
@property (nonatomic, assign) NSTimeInterval timeOffset;
@property (nonatomic, strong) NSString *sourceName;
@property (nonatomic, strong) UIImage *snapshot;
@property (nonatomic, strong) NSData *recording;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) NSDictionary *tileSourceInfo;
@property (nonatomic, strong) UIImage *drawingImage;

@end