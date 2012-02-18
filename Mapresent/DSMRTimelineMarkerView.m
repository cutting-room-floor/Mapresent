//
//  DSMRTimelineMarkerView.m
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineMarkerView.h"

#import "UIImage-Extensions.h"

#import <QuartzCore/QuartzCore.h>

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
        
        CGRect baseRect = CGRectMake(0, 0, 64, 40);
        
        switch (marker.markerType)
        {
            case DSMRTimelineMarkerTypeLocation:
            {
                self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.2];
                
                UIImageView *imageView = [[UIImageView alloc] initWithImage:[marker.snapshot imageByScalingProportionallyToSize:CGSizeMake(40, 30)]];
                
                imageView.center = CGPointMake(CGRectGetMidX(baseRect), CGRectGetMidY(baseRect));
                
                [self addSubview:imageView];
                
                break;
            }
            case DSMRTimelineMarkerTypeAudio:
            {
                self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.2];
                
                // FIXME: this drawing bit should be abstracted
                //
                baseRect = CGRectMake(baseRect.origin.x, baseRect.origin.y, marker.duration * 64.0, baseRect.size.height);
                
                UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(4, 5, baseRect.size.width - 8, 30)];
                
                containerView.backgroundColor = [UIColor clearColor];
                containerView.clipsToBounds   = YES;
                
                UIImage *waveformImage = [UIImage imageNamed:@"waveform.png"];
                
                for (int i = 0; i < containerView.bounds.size.width; i = i + waveformImage.size.width)
                {
                    UIImageView *imageView = [[UIImageView alloc] initWithImage:waveformImage];
                    
                    imageView.alpha = 0.75;
                
                    imageView.frame = CGRectMake(i, 0, waveformImage.size.width, waveformImage.size.height);
                
                    [containerView addSubview:imageView];
                }
                
                [self addSubview:containerView];
                
                break;
            }
            case DSMRTimelineMarkerTypeTheme:
            {
                self.backgroundColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.2];
                
                UIImageView *imageView = [[UIImageView alloc] initWithImage:[marker.snapshot imageByScalingProportionallyToSize:CGSizeMake(40, 30)]];
                
                imageView.center = CGPointMake(CGRectGetMidX(baseRect), CGRectGetMidY(baseRect));
                
                [self addSubview:imageView];

                break;
            }
            case DSMRTimelineMarkerTypeDrawing:
            {
                self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:1.0 alpha:0.2];

                UIImageView *imageView = [[UIImageView alloc] initWithImage:[marker.snapshot imageByScalingProportionallyToSize:CGSizeMake(40, 30)]];
                
                imageView.center = CGPointMake(CGRectGetMidX(baseRect), CGRectGetMidY(baseRect));

                UIView *canvasView = [[UIView alloc] initWithFrame:imageView.bounds];
                
                canvasView.center = imageView.center;
                
                canvasView.backgroundColor = [UIColor whiteColor];
                
                [self addSubview:canvasView];
                [self addSubview:imageView];

                break;
            }
            case DSMRTimelineMarkerTypeDrawingClear:
            {
                self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:1.0 alpha:0.2];
                
                UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"clear.png"]];
                
                imageView.center = CGPointMake(CGRectGetMidX(baseRect), CGRectGetMidY(baseRect));
                
                imageView.alpha = 0.75;
                
                [self addSubview:imageView];
                
                break;
            }
        }

        self.frame = baseRect;
        
        self.layer.cornerRadius    = 5.0;

        self.layer.borderColor     = [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor];
        self.layer.borderWidth     = 2.0;
        
        self.layer.shadowOpacity   = 1.0;
        self.layer.shadowColor     = [[UIColor blackColor] CGColor];
        self.layer.shadowOffset    = CGSizeMake(0.0, 1.0);

        self.layer.shouldRasterize = YES;
    }
        
    return self;
}

@end