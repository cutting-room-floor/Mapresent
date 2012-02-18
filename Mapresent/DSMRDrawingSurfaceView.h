//
//  DSMRDrawingSurfaceView.h
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSMRDrawingSurfaceView;

@protocol DSMRDrawingSurfaceDelegate <NSObject>

- (UIColor *)lineColorForDrawingView:(DSMRDrawingSurfaceView *)drawingView;
- (NSUInteger)lineWidthForDrawingView:(DSMRDrawingSurfaceView *)drawingView;

@end

#pragma mark -

@interface DSMRDrawingSurfaceView : UIView

@property (nonatomic, weak) id <DSMRDrawingSurfaceDelegate>delegate;

- (void)clearDrawings;
- (UIImage *)snapshotImage;

@end