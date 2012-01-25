//
//  DSMRViewController.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRViewController.h"

#import "RMMapView.h"

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
    
    self.mapView.centerCoordinate = CLLocationCoordinate2DMake(45.52, -122.681944);
    
    self.mapView.decelerationMode = RMMapDecelerationFast;
    
    [RMMapView class]; // avoid code stripping
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

@end