//
//  DSMRViewController.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRViewController.h"

#import "RMMapView.h"
#import "RMMBTilesTileSource.h"

#import <CoreLocation/CoreLocation.h>

@interface DSMRViewController () 

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UIView *inspectorView;
@property (nonatomic, strong) IBOutlet UIView *timelineView;

@end

#pragma mark -

@implementation DSMRViewController

@synthesize mapView;
@synthesize inspectorView;
@synthesize timelineView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.tileSource = [[RMMBTilesTileSource alloc] initWithTileSetURL:[[NSBundle mainBundle] URLForResource:@"geography-class" withExtension:@"mbtiles"]];
    self.mapView.decelerationMode = RMMapDecelerationFast;
    self.mapView.zoom = 1.396605;
    
    ((UIScrollView *)self.timelineView.superview).contentSize = self.timelineView.frame.size;
    
    [RMMapView class]; // avoid code stripping
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

@end