//
//  DSMRTimelineView.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineView.h"

#import "DSMRTimelineMarker.h"

#import "UIImage-Extensions.h"

@interface DSMRTileLineViewTimeline : UIView

@end

#pragma mark -

@interface DSMRTimelineView ()

@property (nonatomic, strong) UIScrollView *scroller;
@property (nonatomic, strong) DSMRTileLineViewTimeline *timeline;
@property (nonatomic, strong) NSTimer *playTimer;

@end

#pragma mark -

@implementation DSMRTimelineView

@synthesize delegate;
@synthesize scroller;
@synthesize timeline;
@synthesize playTimer;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self)
    {
        [self setBackgroundColor:[UIColor darkGrayColor]];
        
        scroller = [[UIScrollView alloc] initWithFrame:[self bounds]];
        
        [self addSubview:scroller];
        
        timeline = [[DSMRTileLineViewTimeline alloc] initWithFrame:CGRectMake(0, 0, [self bounds].size.width * 3, [self bounds].size.height)];
        
        [scroller addSubview:timeline];

        scroller.contentSize = timeline.frame.size;
        scroller.delegate = self;
    }
    
    return self;
}

#pragma mark -

- (void)togglePlay
{
    if ([self.playTimer isValid])
        [self.playTimer invalidate];
    else
        self.playTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 64.0) target:self selector:@selector(firePlayTimer:) userInfo:nil repeats:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayToggled object:self];
}

- (void)firePlayTimer:(NSTimer *)timer
{
    CGPoint targetOffset = CGPointMake(self.scroller.contentOffset.x + 1.0, self.scroller.contentOffset.y);
    
    if (targetOffset.x > self.timeline.bounds.size.width - self.scroller.bounds.size.width)
    {
        [self togglePlay];
    }
    else
    {
        [self.scroller setContentOffset:targetOffset animated:NO];
     
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayProgressed object:[NSNumber numberWithFloat:targetOffset.x]];
    }
}

- (void)redrawMarkers
{
    [self.timeline.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    for (DSMRTimelineMarker *marker in [self.delegate timelineMarkers])
    {
        UIView *markerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 64, 20)];
        
        CGFloat placement, width;
        
        if (marker.sourceName)
        {
            markerView.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.2];
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[marker.snapshot imageByScalingProportionallyToSize:CGSizeMake(18, 18)]];
            
            imageView.center = CGPointMake(11, 11);
            
            [markerView addSubview:imageView];
            
            placement = 100;
            width     = markerView.frame.size.width;
        }
        else if (marker.recording)
        {
            markerView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:1.0 alpha:0.2];
            
            placement = 130;
            width     = marker.duration * 64.0;
        }
        else if (marker.tileSourceInfo)
        {
            markerView.backgroundColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.2];
            
            placement = 160;
            width     = markerView.frame.size.width;
        }
        
        markerView.frame = CGRectMake((marker.timeOffset * 64.0) + 512.0, placement, width, markerView.frame.size.height);
        
        [self.timeline addSubview:markerView];
    }
}

#pragma mark -

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([self.playTimer isValid])
        [self togglePlay];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.dragging && scrollView.contentOffset.x >= 0 && scrollView.contentOffset.x <= (self.timeline.bounds.size.width - self.scroller.bounds.size.width))
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayProgressed object:[NSNumber numberWithFloat:scroller.contentOffset.x]];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [[NSNotificationCenter defaultCenter] postNotificationName:DSMRTimelineViewPlayProgressed object:[NSNumber numberWithFloat:scroller.contentOffset.x]];
}

@end

#pragma mark -

@implementation DSMRTileLineViewTimeline

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(c, [[UIColor darkGrayColor] CGColor]);
    CGContextFillRect(c, rect);

    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.0 alpha:0.5] CGColor]);
    CGContextFillRect(c, CGRectMake(0, 0, 512.0, 250.0));
    CGContextFillRect(c, CGRectMake(self.bounds.size.width - 512.0, 0, 512.0, 250.0));

    CGContextSetStrokeColorWithColor(c, [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor]);
    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor]);

    CGContextSetLineWidth(c, 2);
    
    for (float i = 512.0; i < self.bounds.size.width - 512.0; i = i + 8.0)
    {
        CGContextBeginPath(c);
        
        float y;
        
        if (fmodf(i, 64.0) == 0.0)
        {
            [[NSString stringWithFormat:@"%i", (int)(i - 512.0) / 64] drawAtPoint:CGPointMake(i + 4.0, 65.0) withFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]]];

            y = 75.0;
        }
        else
        {
            y = 50.0;
        }
        
        CGContextMoveToPoint(c, i, 0.0);
        CGContextAddLineToPoint(c, i, y);
        
        CGContextStrokePath(c);
    }
    
    CGContextSetLineWidth(c, 2.0);
    CGContextBeginPath(c);    
    CGContextMoveToPoint(c, self.bounds.size.width - 512.0, 0.0);
    CGContextAddLineToPoint(c, self.bounds.size.width - 512.0, 75.0);
    CGContextStrokePath(c);
}

@end