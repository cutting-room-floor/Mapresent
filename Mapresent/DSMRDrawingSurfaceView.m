//
//  DSMRDrawingSurfaceView.m
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRDrawingSurfaceView.h"

@interface DSMRDrawingSurfaceView ()

@property (nonatomic, strong) NSMutableArray *subpaths;
@property (nonatomic, strong) NSMutableArray *subpathLineColors;
@property (nonatomic, strong) NSMutableArray *subpathLineWidths;
@property (nonatomic, assign) BOOL drawingSnapshot;

@end

#pragma mark -

@implementation DSMRDrawingSurfaceView

@synthesize delegate;
@synthesize subpaths;
@synthesize subpathLineColors;
@synthesize subpathLineWidths;
@synthesize drawingSnapshot;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        subpaths          = [NSMutableArray array];
        subpathLineColors = [NSMutableArray array];
        subpathLineWidths = [NSMutableArray array];
        
        self.opaque = NO;
    }
        
    return self;
}

#pragma mark -

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGMutablePathRef latestPath = CGPathCreateMutable();

    CGPathMoveToPoint(latestPath, nil, [[touches anyObject] locationInView:self].x, [[touches anyObject] locationInView:self].y);
    
    [self.subpaths addObject:[NSValue valueWithPointer:latestPath]];
    [self.subpathLineColors addObject:[self.delegate lineColorForDrawingView:self]];
    [self.subpathLineWidths addObject:[NSNumber numberWithUnsignedInteger:[self.delegate lineWidthForDrawingView:self]]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGMutablePathRef latestPath = [[self.subpaths lastObject] pointerValue];
    
    CGPathAddLineToPoint(latestPath, nil, [[touches anyObject] locationInView:self].x, [[touches anyObject] locationInView:self].y);
    
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.subpaths removeLastObject];
    [self.subpathLineColors removeLastObject];
    [self.subpathLineWidths removeLastObject];
    
    [self setNeedsDisplay];
}

#pragma mark -

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    CGContextClearRect(c, rect);
    
    if ( ! self.drawingSnapshot)
    {
        CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.0 alpha:0.5] CGColor]);
        CGContextFillRect(c, rect);
    }
    
    CGContextSetLineCap(c, kCGLineCapRound);
    
    for (int i = 0; i < [self.subpaths count]; i++)
    {
        CGMutablePathRef subpath = [[self.subpaths objectAtIndex:i] pointerValue];

        CGContextBeginPath(c);
        
        CGContextAddPath(c, subpath);
        
        CGContextSetStrokeColorWithColor(c, [[self.subpathLineColors objectAtIndex:i] CGColor]);
        CGContextSetLineWidth(c, [[self.subpathLineWidths objectAtIndex:i] floatValue]);

        CGContextStrokePath(c);
    }
}

#pragma mark -

- (void)clearDrawings
{
    [self.subpaths removeAllObjects];
    [self.subpathLineColors removeAllObjects];
    [self.subpathLineWidths removeAllObjects];
    
    [self setNeedsDisplay];
}

- (UIImage *)snapshotImage
{
    if ( ! [self.subpaths count])
        return nil;
    
    self.drawingSnapshot = YES;
    
    UIGraphicsBeginImageContext(self.bounds.size);
    
    [self drawRect:self.bounds];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    self.drawingSnapshot = NO;
    
    return image;
}

@end