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
    
    self.levelsView.averageLevel = fminf([self.recorder averagePowerForChannel:0], 0.0); // clip at max of 0.0
    
    [self.levelsView setNeedsDisplay];
}

@end

#pragma mark -

@implementation DSMRAudioRecorderLevelsView

@synthesize averageLevel;
@synthesize peakLevel;

- (void)drawRect:(CGRect)rect
{
    // update peak, still in dB, max below 0.0
    //
    self.peakLevel = (self.peakLevel < 0.0 ? self.peakLevel : -160.0);
    
    if (self.averageLevel > self.peakLevel && self.averageLevel > -160.0 && self.averageLevel < 0.0)
        self.peakLevel = self.averageLevel;
    
    // convert to linear float scale
    //
    float averageScale = log10f((self.averageLevel) / -160.0) / -1.5; // first 0.0-1.0 represents good levels, 1.0+ bad
    float peakScale    = log10f((self.peakLevel)    / -160.0) / -1.5;
    
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    // black background
    //
    CGContextSetFillColorWithColor(c, [[UIColor darkGrayColor] CGColor]);
    CGContextFillRect(c, rect);
    
    // green "normal 2/3" background
    //
    CGContextSetFillColorWithColor(c, [[UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.2] CGColor]);
    CGContextFillRect(c, CGRectMake(0, 0, (2.0 * rect.size.width) / 3.0, rect.size.height));
    
    // red "bad 1/3" background
    //
    CGContextSetFillColorWithColor(c, [[UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.2] CGColor]);
    CGContextFillRect(c, CGRectMake((2.0 * rect.size.width) / 3.0, 0.0, rect.size.width / 3.0, rect.size.height));
    
    // animated average level bar
    //
    CGContextSetFillColorWithColor(c, [[UIColor yellowColor] CGColor]);
    CGContextFillRect(c, CGRectMake(0.0, rect.size.height / 4.0, averageScale * rect.size.width, rect.size.height / 2.0));
    
    CGContextSetFillColorWithColor(c, [[UIColor redColor] CGColor]);
    CGContextFillRect(c, CGRectMake((peakScale * rect.size.width - 2), 0, 4, rect.size.height));
}

@end