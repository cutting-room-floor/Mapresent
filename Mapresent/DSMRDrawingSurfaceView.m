//
//  DSMRDrawingSurfaceView.m
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRDrawingSurfaceView.h"

@implementation DSMRDrawingSurfaceView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
        self.opaque = NO;
        
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(c, [[UIColor colorWithWhite:0.0 alpha:0.5] CGColor]);
    CGContextFillRect(c, rect);
}

@end