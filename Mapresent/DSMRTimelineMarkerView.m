//
//  DSMRTimelineMarkerView.m
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineMarkerView.h"

#import "UIImage-Extensions.h"

@interface DSMRTimelineMarkerView ()

@property (nonatomic, strong) DSMRTimelineMarker *marker;

@end

#pragma mark -

@implementation DSMRTimelineMarkerView

@synthesize marker=_marker;

- (id)initWithMarker:(DSMRTimelineMarker *)marker
{
    self = [super initWithFrame:CGRectZero];
    
    if (self)
    {
        _marker = marker;
        
        CGRect baseRect = CGRectMake(0, 0, 64, 20);
        
        switch (marker.markerType)
        {
            case DSMRTimelineMarkerTypeLocation:
            {
                self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.2];
                
                UIImageView *imageView = [[UIImageView alloc] initWithImage:[marker.snapshot imageByScalingProportionallyToSize:CGSizeMake(18, 18)]];
                
                imageView.center = CGPointMake(11, 11);
                
                [self addSubview:imageView];
                
                break;
            }
            case DSMRTimelineMarkerTypeAudio:
            {
                self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.2];
                
                baseRect = CGRectMake(baseRect.origin.x, baseRect.origin.y, marker.duration * 64.0, baseRect.size.height);
                
                break;
            }
            case DSMRTimelineMarkerTypeTheme:
            {
                self.backgroundColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.2];
                
                break;
            }
            case DSMRTimelineMarkerTypeDrawing:
            case DSMRTimelineMarkerTypeDrawingClear:
            {
                self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:1.0 alpha:0.2];
                
                break;
            }
        }

        self.frame = baseRect;
    }
        
    return self;
}

@end