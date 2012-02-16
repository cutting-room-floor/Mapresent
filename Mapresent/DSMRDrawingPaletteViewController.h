//
//  DSMRDrawingPaletteViewController.h
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSMRDrawingPaletteViewController : UIViewController

@property (nonatomic, readonly, strong) UIColor *lineColor;
@property (nonatomic, readonly, assign) NSUInteger lineWidth;

@end