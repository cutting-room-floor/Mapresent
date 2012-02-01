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

@interface DSMRThemePicker ()

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UILabel *label;

@end

#pragma mark -

@implementation DSMRThemePicker

@synthesize info;
@synthesize mapView;
@synthesize label;

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
    
    self.label.text = [self.info objectForKey:@"name"];

    self.mapView.tileSource = [[RMTileStreamSource alloc] initWithInfo:self.info];

    self.mapView.centerCoordinate = CLLocationCoordinate2DMake([[[self.info objectForKey:@"center"] objectAtIndex:0] floatValue], 
                                                               [[[self.info objectForKey:@"center"] objectAtIndex:1] floatValue]);
    
    self.mapView.zoom = [[[self.info objectForKey:@"center"] lastObject] floatValue];
    
    self.mapView.decelerationMode = RMMapDecelerationFast;
}

@end