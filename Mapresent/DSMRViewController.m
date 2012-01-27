//
//  DSMRViewController.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRViewController.h"

#import "DSMRTimelineView.h"

#import "RMMapView.h"
#import "RMMBTilesTileSource.h"

#import <CoreLocation/CoreLocation.h>

@interface DSMRViewController () 

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UILabel *mapLabel;
@property (nonatomic, strong) IBOutlet UIView *inspectorView;
@property (nonatomic, strong) IBOutlet DSMRTimelineView *timelineView;
@property (nonatomic, strong) IBOutlet UITableView *markerTableView;
@property (nonatomic, strong) IBOutlet UIButton *playButton;
@property (nonatomic, strong) IBOutlet UILabel *timeLabel;
@property (nonatomic, strong) NSMutableArray *markers;

- (IBAction)pressedPlay:(id)sender;
- (void)fireMarkerAtIndex:(NSInteger)index;

@end

#pragma mark -

@implementation DSMRViewController

@synthesize mapView;
@synthesize mapLabel;
@synthesize inspectorView;
@synthesize timelineView;
@synthesize markerTableView;
@synthesize playButton;
@synthesize timeLabel;
@synthesize markers;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.delegate = self;
    
    self.mapView.tileSource = [[RMMBTilesTileSource alloc] initWithTileSetURL:[[NSBundle mainBundle] URLForResource:@"geography-class" withExtension:@"mbtiles"]];
    self.mapView.decelerationMode = RMMapDecelerationFast;
    self.mapView.zoom = 1.396605;
    
    [RMMapView class]; // avoid code stripping
    
    timeLabel.text = @"0.000000";

    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"markers"])
        markers = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"markers"]];
    else
        markers = [NSMutableArray array];
    
    [self.markerTableView reloadData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playToggled:)       name:DSMRTimelineViewPlayToggled               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playProgressed:)    name:DSMRTimelineViewPlayProgressed            object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillBackground:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DSMRTimelineViewPlayToggled               object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DSMRTimelineViewPlayProgressed            object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}

#pragma mark -

- (IBAction)pressedPlay:(id)sender
{    
    if ([self.markers count] && [[[self.markers objectAtIndex:0] valueForKey:@"timeOffset"] floatValue] == 0 && [self.timeLabel.text floatValue] == 0)
        [self fireMarkerAtIndex:0];
    
    [self.timelineView togglePlay];
}

- (IBAction)pressedMarker:(id)sender
{
    CLLocationCoordinate2D sw = self.mapView.latitudeLongitudeBoundingBox.southWest;
    CLLocationCoordinate2D ne = self.mapView.latitudeLongitudeBoundingBox.northEast;
    
    NSDictionary *marker = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithFloat:sw.latitude],                             @"swLat",
                               [NSNumber numberWithFloat:sw.longitude],                            @"swLon",
                               [NSNumber numberWithFloat:ne.latitude],                             @"neLat",
                               [NSNumber numberWithFloat:ne.longitude],                            @"neLon",
                               [NSNumber numberWithFloat:self.mapView.centerCoordinate.latitude],  @"centerLat",
                               [NSNumber numberWithFloat:self.mapView.centerCoordinate.longitude], @"centerLon",
                               self.timeLabel.text,                                                @"timeOffset", 
                               [self.mapView.tileSource shortName],                                @"sourceName",
                               nil];
    
    if ([self.markers count])
    {
        int startCount = [self.markers count];
        
        for (NSDictionary *otherMarker in [self.markers copy])
        {
            if ([self.timeLabel.text floatValue] < [[otherMarker valueForKey:@"timeOffset"] floatValue])
            {
                [self.markers insertObject:marker atIndex:[self.markers indexOfObject:otherMarker]];
                
                break;
            }
        }
        
        if ([self.markers count] == startCount)
            [self.markers addObject:marker];
    }
    else
    {
        [self.markers addObject:marker];
    }

    [self.markerTableView reloadData];
}

#pragma mark -

- (void)fireMarkerAtIndex:(NSInteger)index
{
    NSDictionary *marker = [self.markers objectAtIndex:index];
    
    [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:CLLocationCoordinate2DMake([[marker objectForKey:@"swLat"] floatValue], 
                                                                                      [[marker objectForKey:@"swLon"] floatValue])
                                                 northEast:CLLocationCoordinate2DMake([[marker objectForKey:@"neLat"] floatValue], 
                                                                                      [[marker objectForKey:@"neLon"] floatValue]) 
                                                  animated:YES];
}

- (void)appWillBackground:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] setObject:self.markers forKey:@"markers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)playToggled:(NSNotification *)notification
{
    [self.playButton setTitle:([self.playButton.currentTitle isEqualToString:@"Play"] ? @"Pause" : @"Play") forState:UIControlStateNormal];
}

- (void)playProgressed:(NSNotification *)notification
{
    self.timeLabel.text = [NSString stringWithFormat:@"%f", [((NSNumber *)[notification object]) floatValue] / 64];
    
    if ([self.playButton.currentTitle isEqualToString:@"Pause"] && [[self.markers valueForKeyPath:@"timeOffset"] containsObject:self.timeLabel.text])
    {
        for (NSDictionary *marker in self.markers)
        {
            if ([[marker objectForKey:@"timeOffset"] floatValue] == [self.timeLabel.text floatValue])
            {
                [self fireMarkerAtIndex:[self.markers indexOfObject:marker]];
                
                break;
            }
        }
    }
}

#pragma mark -

- (void)mapViewRegionDidChange:(RMMapView *)mapView
{
    self.mapLabel.text = [NSString stringWithFormat:@"%f, %f", self.mapView.centerCoordinate.latitude, self.mapView.centerCoordinate.longitude];
}

#pragma mark -

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.markers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *DSMRViewControllerMarkerIdentifier = @"DSMRViewControllerMarkerIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:DSMRViewControllerMarkerIdentifier];
    
    if ( ! cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:DSMRViewControllerMarkerIdentifier];
    
    NSDictionary *marker = [self.markers objectAtIndex:indexPath.row];

    cell.textLabel.text = [NSString stringWithFormat:@"Marker @ %@s", [marker valueForKey:@"timeOffset"]];
        
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%f, %f)", 
                                    [marker valueForKey:@"sourceName"],
                                    [[marker valueForKey:@"centerLat"] floatValue],
                                    [[marker valueForKey:@"centerLon"] floatValue]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.markers removeObjectAtIndex:indexPath.row];
    
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
}

#pragma mark -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self fireMarkerAtIndex:indexPath.row];
}

@end