//
//  DSMRViewController.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRViewController.h"

#import "DSMRTimelineMarker.h"

#import "RMMapView.h"
#import "RMMBTilesTileSource.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>

@interface DSMRViewController () 

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UILabel *mapLabel;
@property (nonatomic, strong) IBOutlet UIView *inspectorView;
@property (nonatomic, strong) IBOutlet DSMRTimelineView *timelineView;
@property (nonatomic, strong) IBOutlet UITableView *markerTableView;
@property (nonatomic, strong) IBOutlet UIButton *playButton;
@property (nonatomic, strong) IBOutlet UIButton *audioButton;
@property (nonatomic, strong) IBOutlet UILabel *timeLabel;
@property (nonatomic, strong) NSMutableArray *markers;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;

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
@synthesize audioButton;
@synthesize timeLabel;
@synthesize markers;
@synthesize recorder;
@synthesize player;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mapView.delegate = self;
    
    self.mapView.tileSource = [[RMMBTilesTileSource alloc] initWithTileSetURL:[[NSBundle mainBundle] URLForResource:@"geography-class" withExtension:@"mbtiles"]];
    self.mapView.decelerationMode = RMMapDecelerationFast;
    self.mapView.zoom = 1.396605;
    
    [RMMapView class]; // avoid code stripping
    
    timeLabel.text = @"0.000000";

    markers = [NSMutableArray array];

    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"markers"])
        for (NSData *savedMarker in [[NSUserDefaults standardUserDefaults] arrayForKey:@"markers"])
            [markers addObject:[NSKeyedUnarchiver unarchiveObjectWithData:savedMarker]];
    
    [self.markerTableView reloadData];
    
    self.timelineView.delegate = self;
    
    [self.timelineView redrawMarkers];
    
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
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    if ([self.markers count] && [[[self.markers objectAtIndex:0] valueForKey:@"timeOffset"] floatValue] == 0 && [self.timeLabel.text floatValue] == 0)
        [self fireMarkerAtIndex:0];
    
    [self.timelineView togglePlay];
}

- (IBAction)pressedAudio:(id)sender
{
    if ( ! self.recorder.recording)
    {
        [self.audioButton setTitle:@"Stop" forState:UIControlStateNormal];

        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];

        NSURL *recordURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.rec", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]]];
        
        NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithFloat:8000.0],                  AVSampleRateKey,
                                     [NSNumber numberWithInt:kAudioFormatAppleLossless], AVFormatIDKey,
                                     [NSNumber numberWithInt:1],                         AVNumberOfChannelsKey,
                                     [NSNumber numberWithInt:AVAudioQualityMax],         AVEncoderAudioQualityKey,
                                     nil];
        
        self.recorder = [[AVAudioRecorder alloc] initWithURL:recordURL settings:settings error:nil];
        
        [self.recorder record];
    }
    else
    {
        [self.recorder stop];

        [self.audioButton setTitle:@"Audio" forState:UIControlStateNormal];
        
        AVAudioPlayer *clip = [[AVAudioPlayer alloc] initWithContentsOfURL:self.recorder.url error:nil];
        
        DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
        
        marker.timeOffset = [self.timeLabel.text doubleValue];
        marker.recording  = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:[self.recorder.url absoluteString]]];
        marker.duration   = clip.duration;
        
        [[NSFileManager defaultManager] removeItemAtURL:self.recorder.url error:nil];
        
        if ([self.markers count])
        {
            int startCount = [self.markers count];
            
            for (DSMRTimelineMarker *otherMarker in [self.markers copy])
            {
                if ([self.timeLabel.text doubleValue] < otherMarker.timeOffset)
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
        
        [self.timelineView redrawMarkers];
        
        [TestFlight passCheckpoint:@"recorded audio marker"];
    }
}

- (IBAction)pressedMarker:(id)sender
{
    UIGraphicsBeginImageContext(self.mapView.bounds.size);
    
    [self.mapView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
    
    marker.southWest  = self.mapView.latitudeLongitudeBoundingBox.southWest;
    marker.northEast  = self.mapView.latitudeLongitudeBoundingBox.northEast;
    marker.center     = self.mapView.centerCoordinate;
    marker.timeOffset = [self.timeLabel.text doubleValue];
    marker.sourceName = [self.mapView.tileSource shortName];
    marker.snapshot   = snapshot;
    
    if ([self.markers count])
    {
        int startCount = [self.markers count];
        
        for (DSMRTimelineMarker *otherMarker in [self.markers copy])
        {
            if ([self.timeLabel.text doubleValue] < otherMarker.timeOffset)
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
    
    [self.timelineView redrawMarkers];
    
    [TestFlight passCheckpoint:@"created map marker"];
}

#pragma mark -

- (void)fireMarkerAtIndex:(NSInteger)index
{
    DSMRTimelineMarker *marker = [self.markers objectAtIndex:index];
    
    if (marker.sourceName)
    {
        [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:marker.southWest northEast:marker.northEast animated:YES];
    }
    else if (marker.recording)
    {
        self.player = [[AVAudioPlayer alloc] initWithData:marker.recording error:nil];
    
        [self.player play];
    }
}

- (void)appWillBackground:(NSNotification *)notification
{
    NSMutableArray *savedMarkers = [NSMutableArray array];
    
    for (DSMRTimelineMarker *marker in self.markers)
        [savedMarkers addObject:[NSKeyedArchiver archivedDataWithRootObject:marker]];
    
    [[NSUserDefaults standardUserDefaults] setObject:savedMarkers forKey:@"markers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [TestFlight passCheckpoint:@"backgrounded app"];
}

- (void)playToggled:(NSNotification *)notification
{
    [self.playButton setTitle:([self.playButton.currentTitle isEqualToString:@"Play"] ? @"Pause" : @"Play") forState:UIControlStateNormal];
    
    [TestFlight passCheckpoint:@"toggled play"];
}

- (void)playProgressed:(NSNotification *)notification
{
    self.timeLabel.text = [NSString stringWithFormat:@"%f", [((NSNumber *)[notification object]) floatValue] / 64];
    
    if ([self.playButton.currentTitle isEqualToString:@"Pause"] && [[self.markers valueForKeyPath:@"timeOffset"] containsObject:[NSNumber numberWithDouble:[self.timeLabel.text doubleValue]]])
    {
        for (DSMRTimelineMarker *marker in self.markers)
        {
            if (marker.timeOffset == [self.timeLabel.text doubleValue])
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
    
    DSMRTimelineMarker *marker = [self.markers objectAtIndex:indexPath.row];

    if (marker.sourceName)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Map @ %fs", marker.timeOffset];

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%f, %f)", marker.sourceName, marker.center.latitude, marker.center.longitude];
    }
    else if (marker.recording)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Audio @ %fs", marker.timeOffset];

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%f seconds", marker.duration];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.markers removeObjectAtIndex:indexPath.row];
    
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    
    [self.timelineView redrawMarkers];
    
    [TestFlight passCheckpoint:@"deleted marker"];
}

#pragma mark -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self fireMarkerAtIndex:indexPath.row];
    
    [TestFlight passCheckpoint:@"selected marker"];
}

#pragma mark -

- (NSArray *)timelineMarkers
{
    return [NSArray arrayWithArray:self.markers];
}

@end