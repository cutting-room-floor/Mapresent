//
//  DSMRTimelineView.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRTimelineView.h"

@implementation DSMRTimelineView

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self)
        [self setFrame:CGRectMake([self frame].origin.x, [self frame].origin.y, 3072, [self frame].size.height)];
    
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(c, [[UIColor darkGrayColor] CGColor]);
    CGContextFillRect(c, rect);

    CGContextSetStrokeColorWithColor(c, [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor]);
    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:1.0 alpha:0.25] CGColor]);

    CGContextSetLineWidth(c, 1);
    CGContextBeginPath(c);    
    CGContextMoveToPoint(c, 1.0, 0.0);
    CGContextAddLineToPoint(c, 1.0, 75.0);
    CGContextStrokePath(c);
    
    CGContextSetLineWidth(c, 2);
    
    for (float i = 0.0; i < self.bounds.size.width; i = i + 10.0)
    {
        CGContextBeginPath(c);
        
        float y;
        
        if (fmodf(i, 50.0) == 0.0)
        {
            [[NSString stringWithFormat:@"%i", (int)i] drawAtPoint:CGPointMake(i + 5.0, 65.0) withFont:[UIFont systemFontOfSize:[UIFont smallSystemFontSize]]];

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
}

@end