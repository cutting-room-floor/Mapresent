//
//  DSMRAudioRecorderView.m
//  Mapresent
//
//  Created by Justin Miller on 2/15/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRAudioRecorderView.h"

@interface DSMRAudioRecorderLevelsView : UIView

@property (nonatomic, assign) CGFloat averageLevel;
@property (nonatomic, assign) CGFloat peakLevel;

@end

#pragma mark -

@interface DSMRAudioRecorderView ()

@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) DSMRAudioRecorderLevelsView *levelsView;
@property (nonatomic, strong) UILabel *counterLabel;
@property (nonatomic, strong) NSTimer *timer;

@end

#pragma mark -

@implementation DSMRAudioRecorderView

@synthesize recorder;
@synthesize levelsView;
@synthesize counterLabel;
@synthesize timer;

- (id)initWithAudioRecorder:(AVAudioRecorder *)inRecorder target:(id)target action:(SEL)action
{
    self = [super initWithFrame:CGRectZero];

    if (self)
    {
        recorder = inRecorder;
        
        recorder.meteringEnabled = YES;
        
        UIView *mainView = [[[NSBundle mainBundle] loadNibNamed:@"DSMRAudioRecorderView" owner:self options:nil] lastObject];
        
        [self setFrame:mainView.bounds];
        
        [self addSubview:mainView];
        
        UIView *levelsBaseView = [mainView viewWithTag:1];

        levelsView = [[DSMRAudioRecorderLevelsView alloc] initWithFrame:levelsBaseView.bounds];
        
        [levelsBaseView addSubview:levelsView];
    
        counterLabel = (UILabel *)[mainView viewWithTag:2];
        
        [(UIButton *)[mainView viewWithTag:3] addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        
        timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(update) userInfo:nil repeats:YES];
    }
    
    return self;
}

- (void)dealloc
{
    [timer invalidate];
}

#pragma mark -

- (void)update
{
    self.counterLabel.text = [NSString stringWithFormat:@"%i.0s", (int)self.recorder.currentTime];
    
    [self.recorder updateMeters];
    
    self.levelsView.averageLevel = [self.recorder averagePowerForChannel:0];
    
    [self.levelsView setNeedsDisplay];
}

@end

#pragma mark -

@implementation DSMRAudioRecorderLevelsView

@synthesize averageLevel;
@synthesize peakLevel;

- (void)drawRect:(CGRect)rect
{
    self.averageLevel = (self.averageLevel > 0.0 ? 0.0 : ((160.0 - (-1.0 * self.averageLevel)) / 160.0));
    
    if (self.averageLevel > self.peakLevel && self.averageLevel < 1.0)
        self.peakLevel = self.averageLevel;
    
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    // black background
    //
    CGContextSetFillColorWithColor(c, [[UIColor darkGrayColor] CGColor]);
    CGContextFillRect(c, rect);
    
    // green average level
    //
    CGContextSetFillColorWithColor(c, [[UIColor greenColor] CGColor]);
    CGContextFillRect(c, CGRectMake(0, 0, self.averageLevel * rect.size.width, rect.size.height));
    
    // red peak level
    //
    CGContextSetFillColorWithColor(c, [[UIColor redColor] CGColor]);
    CGContextFillRect(c, CGRectMake((self.peakLevel * rect.size.width - 2), 0, 4, rect.size.height));
}

@end