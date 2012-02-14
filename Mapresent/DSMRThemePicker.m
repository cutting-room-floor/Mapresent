//
//  DSMRThemePicker.m
//  Mapresent
//
//  Created by Justin Miller on 1/31/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRThemePicker.h"

#import "RMMapView.h"
#import "RMTileStreamSource.h"

#import <QuartzCore/QuartzCore.h>

@interface DSMRThemePicker ()

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) IBOutlet UILabel *pageLabel;
@property (nonatomic, strong) IBOutlet UIImageView *pageCurlView;

@end

#pragma mark -

@implementation DSMRThemePicker

@synthesize info;
@synthesize transitioning;
@synthesize mapView;
@synthesize label;
@synthesize pageLabel;
@synthesize pageCurlView;

- (id)initWithInfo:(NSDictionary *)inInfo
{
    self = [super initWithNibName:nil bundle:nil];

    if (self)
        info = inInfo;
        
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.label.text     = [self.info objectForKey:@"name"];
    self.pageLabel.text = [self.info objectForKey:@"pageNumber"];

    self.mapView.tileSource = [[RMTileStreamSource alloc] initWithInfo:self.info];

    self.mapView.centerCoordinate = CLLocationCoordinate2DMake([[[self.info objectForKey:@"center"] objectAtIndex:0] floatValue], 
                                                               [[[self.info objectForKey:@"center"] objectAtIndex:1] floatValue]);
    
    self.mapView.zoom = [[[self.info objectForKey:@"center"] lastObject] floatValue];
    
    self.mapView.decelerationMode = RMMapDecelerationFast;
    
    self.mapView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"loading.png"]];
    
    self.mapView.layer.shadowColor   = [[UIColor blackColor] CGColor];
    self.mapView.layer.shadowOffset  = CGSizeMake(0, 1);
    self.mapView.layer.shadowOpacity = 1.0;
    
    self.pageCurlView.alpha = 0.0;
}

#pragma mark -

- (void)setTransitioning:(BOOL)flag
{
    transitioning = flag;
    
    [UIView animateWithDuration:0.1 animations:^(void) { self.pageCurlView.alpha = (flag ? 0.0 : 1.0); }];
}

@end