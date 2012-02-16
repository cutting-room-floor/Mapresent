//
//  DSMRDrawingPaletteViewController.m
//  Mapresent
//
//  Created by Justin Miller on 2/16/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRDrawingPaletteViewController.h"

#import <QuartzCore/QuartzCore.h>

@interface DSMRDrawingPaletteViewController ()

@property (nonatomic, strong) UIColor *lineColor;
@property (nonatomic, assign) NSUInteger lineWidth;
@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *lineColorButtons;
@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *lineWidthButtons;

- (void)tappedLineColorButton:(id)sender;
- (void)tappedLineWidthButton:(id)sender;

@end

#pragma mark -

@implementation DSMRDrawingPaletteViewController

@synthesize lineColor;
@synthesize lineWidth;
@synthesize lineColorButtons;
@synthesize lineWidthButtons;

- (void)viewDidLoad
{
    [super viewDidLoad];

    for (UIButton *lineColorButton in self.lineColorButtons)
    {
        lineColorButton.layer.borderColor   = [[UIColor lightGrayColor] CGColor];
        lineColorButton.layer.borderWidth   = 2.0;

        lineColorButton.layer.shadowColor   = [[UIColor blackColor] CGColor];
        lineColorButton.layer.shadowOpacity = 0.5;
        lineColorButton.layer.shadowOffset  = CGSizeMake(0.0, 1.0);
        
        [lineColorButton addTarget:self action:@selector(tappedLineColorButton:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    for (int i = 2; i <= [self.lineWidthButtons count] * 2; i = i + 2)
    {
        UIButton *lineWidthButton = [self.lineWidthButtons objectAtIndex:((i / 2) - 1)];
        
        lineWidthButton.layer.borderColor   = [[UIColor lightGrayColor] CGColor];
        lineWidthButton.layer.borderWidth   = 2.0;
        
        lineWidthButton.layer.shadowColor   = [[UIColor blackColor] CGColor];
        lineWidthButton.layer.shadowOpacity = 0.5;
        lineWidthButton.layer.shadowOffset  = CGSizeMake(0.0, 1.0);
        
        [lineWidthButton addTarget:self action:@selector(tappedLineWidthButton:) forControlEvents:UIControlEventTouchUpInside];
        
        lineWidthButton.backgroundColor = [UIColor whiteColor];
        
        UIGraphicsBeginImageContext(CGSizeMake(lineWidthButton.bounds.size.width * 0.75, i));
        
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [[UIColor blackColor] CGColor]);
        CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, lineWidthButton.bounds.size.width * 0.75, i));
        
        UIImage *lineImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        [lineWidthButton setImage:lineImage forState:UIControlStateNormal];
        
        lineWidthButton.tag = i;
    }
    
    [self tappedLineColorButton:[self.lineColorButtons objectAtIndex:0]];
    [self tappedLineWidthButton:[self.lineWidthButtons objectAtIndex:0]];
}

#pragma mark -

- (void)tappedLineColorButton:(id)sender
{
    for (UIButton *lineColorButton in self.lineColorButtons)
    {
        lineColorButton.layer.borderColor = [[UIColor lightGrayColor] CGColor];
        lineColorButton.layer.borderWidth = 2.0;
    }
    
    UIButton *selectedButton = (UIButton *)sender;
    
    selectedButton.layer.borderColor = [[UIColor brownColor] CGColor];
    selectedButton.layer.borderWidth = 5.0;
    
    [UIView animateWithDuration:0.1
                     animations:^(void)
                     {
                         selectedButton.transform = CGAffineTransformMakeScale(0.9, 0.9);
                     }
                     completion:^(BOOL completion)
                     {
                         [UIView animateWithDuration:0.1 animations:^(void) { selectedButton.transform = CGAffineTransformIdentity; }];
                     }];
    
    self.lineColor = selectedButton.backgroundColor;
}

- (void)tappedLineWidthButton:(id)sender
{
    for (UIButton *lineWidthButton in self.lineWidthButtons)
    {
        lineWidthButton.layer.borderColor = [[UIColor lightGrayColor] CGColor];
        lineWidthButton.layer.borderWidth = 2.0;
    }
    
    UIButton *selectedButton = (UIButton *)sender;
    
    selectedButton.layer.borderColor = [[UIColor brownColor] CGColor];
    selectedButton.layer.borderWidth = 5.0;

    [UIView animateWithDuration:0.1
                     animations:^(void)
                     {
                         selectedButton.transform = CGAffineTransformMakeScale(0.9, 0.9);
                     }
                     completion:^(BOOL completion)
                     {
                         [UIView animateWithDuration:0.1 animations:^(void) { selectedButton.transform = CGAffineTransformIdentity; }];
                     }];

    self.lineWidth = selectedButton.tag;
}

@end