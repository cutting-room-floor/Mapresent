//
//  DSMRViewController.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRViewController.h"

#import "DSMRTimelineMarker.h"
#import "DSMRWrapperController.h"
#import "DSMRThemePickerController.h"
#import "DSMRAudioRecorderView.h"
#import "DSMRDrawingPaletteViewController.h"
#import "DSMRDrawingSurfaceView.h"

#import "RMMapView.h"
#import "RMMBTilesTileSource.h"
#import "RMTileStreamSource.h"

#import "MBProgressHUD.h"

#import "UIImage-Extensions.h"

#import <CoreLocation/CoreLocation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

@interface DSMRViewController () 

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UILabel *mapLabel;
@property (nonatomic, strong) IBOutlet UIView *inspectorView;
@property (nonatomic, strong) IBOutlet DSMRTimelineView *timelineView;
@property (nonatomic, strong) IBOutlet UITableView *markerTableView;
@property (nonatomic, strong) IBOutlet UIButton *playButton;
@property (nonatomic, strong) IBOutlet UIButton *backButton;
@property (nonatomic, strong) IBOutlet UIButton *playFullScreenButton;
@property (nonatomic, strong) IBOutlet UILabel *timeLabel;
@property (nonatomic, strong) IBOutlet UIButton *fullScreenButton;
@property (nonatomic, strong) IBOutletCollection() NSArray *viewsDisabledDuringPlayback;
@property (nonatomic, strong) NSMutableArray *markers;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSMutableArray *themes;
@property (nonatomic, strong) NSDictionary *chosenThemeInfo;
@property (nonatomic, strong) UIPageViewController *themePager;
@property (nonatomic, strong) DSMRVideoExporter *videoExporter;
@property (nonatomic, assign) dispatch_queue_t serialQueue;
@property (nonatomic, assign) NSTimeInterval presentationDuration;
@property (nonatomic, readonly, assign) BOOL isFullScreen;

- (void)resetMapView;
- (IBAction)pressedPlay:(id)sender;
- (IBAction)pressedPlayFullscreen:(id)sender;
- (IBAction)pressedShare:(id)sender;
- (IBAction)pressedFullScreen:(id)sender;
- (IBAction)pressedRewind:(id)sender;
- (IBAction)pressedDraw:(id)sender;
- (void)fireMarkerAtIndex:(NSInteger)index;
- (NSString *)documentsFolderPath;
- (void)refresh;
- (void)saveState:(id)sender;
- (void)playLatestMovie;
- (void)emailLatestMovie;
- (void)beginExport;
- (void)cleanupExportWithSuccess:(BOOL)flag;
- (void)pressedExportCancel:(id)sender;
- (void)addMarker:(DSMRTimelineMarker *)marker refreshingInterface:(BOOL)shouldRefresh;

@end

#pragma mark -

@implementation DSMRViewController

@synthesize mapView;
@synthesize mapLabel;
@synthesize inspectorView;
@synthesize timelineView;
@synthesize markerTableView;
@synthesize playButton;
@synthesize backButton;
@synthesize playFullScreenButton;
@synthesize timeLabel;
@synthesize fullScreenButton;
@synthesize viewsDisabledDuringPlayback;
@synthesize markers;
@synthesize recorder;
@synthesize player;
@synthesize themes;
@synthesize chosenThemeInfo;
@synthesize themePager;
@synthesize videoExporter;
@synthesize serialQueue;
@synthesize presentationDuration;

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    serialQueue = dispatch_queue_create("com.mapbox.mapresent", DISPATCH_QUEUE_SERIAL);

    self.mapView.delegate = self;
    
    [self resetMapView];
    
    [RMMapView class]; // avoid code stripping
    
    timeLabel.text = @"0.000000";

    markers = [NSMutableArray array];

    NSString *saveFilePath = [[self documentsFolderPath] stringByAppendingPathComponent:@"Document.mapresent"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:saveFilePath])
        for (NSData *savedMarker in [[NSDictionary dictionaryWithContentsOfFile:saveFilePath] objectForKey:@"markers"])
            [markers addObject:[NSKeyedUnarchiver unarchiveObjectWithData:savedMarker]];
    
    self.timelineView.delegate = self;
    
    [self refresh];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playToggled:)    name:DSMRTimelineViewPlayToggled               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playProgressed:) name:DSMRTimelineViewPlayProgressed            object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveState:)      name:UIApplicationWillResignActiveNotification object:nil];
    
#ifdef ADHOC
    // add beta tester feedback button
    //
    UIImage *testFlightImage = [UIImage imageNamed:@"testflight.png"];
    
    UIButton *feedbackButton = [[UIButton alloc] initWithFrame:CGRectMake(10,
                                                                          self.view.bounds.size.height - testFlightImage.size.height - 10, 
                                                                          testFlightImage.size.width, 
                                                                          testFlightImage.size.height)];
    
    [feedbackButton setImage:testFlightImage forState:UIControlStateNormal];
    
    [feedbackButton addTarget:[TestFlight class] action:@selector(openFeedbackView) forControlEvents:UIControlEventTouchUpInside];
    
    feedbackButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    
    feedbackButton.alpha = 0.25;
    
    [self.view addSubview:feedbackButton];
#endif
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationLandscapeLeft; // FIXME this is because of UIGetScreenImage() crops
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DSMRTimelineViewPlayToggled               object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:DSMRTimelineViewPlayProgressed            object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}

#pragma mark -
#pragma mark Miscellaneous

- (void)resetMapView
{
    self.mapView.backgroundColor  = [UIColor blackColor];
    self.mapView.tileSource       = [[RMMBTilesTileSource alloc] initWithTileSetURL:[[NSBundle mainBundle] URLForResource:@"geography-class" 
                                                                                                            withExtension:@"mbtiles"]];
    self.mapView.decelerationMode = RMMapDecelerationFast;
    self.mapView.zoom             = 1.396605; // FIXME - do this by SW/NE corners
}

- (BOOL)isFullScreen
{
    return (self.mapView.bounds.size.width == self.view.bounds.size.width);
}

- (NSString *)documentsFolderPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

- (void)refresh
{
    NSTimeInterval endBumperDuration = 5.0;
    
    NSArray *sortedMarkers = [self.markers sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
    {
        if ([[obj1 valueForKey:@"timeOffset"] doubleValue] > [[obj2 valueForKey:@"timeOffset"] doubleValue])
            return NSOrderedDescending;
        if ([[obj1 valueForKey:@"timeOffset"] doubleValue] < [[obj2 valueForKey:@"timeOffset"] doubleValue])
            return NSOrderedAscending;
        
        return NSOrderedSame;
    }];

    DSMRTimelineMarker *lastMarker = [sortedMarkers lastObject];
    
    switch (lastMarker.markerType)
    {
        case DSMRTimelineMarkerTypeAudio:
        {
            self.presentationDuration = lastMarker.timeOffset + lastMarker.duration + endBumperDuration;
            break;
        }
        default:
        {
            self.presentationDuration = lastMarker.timeOffset + endBumperDuration;
            break;
        }
    }
    
    [self.markerTableView reloadData];
    
    [self.timelineView redrawMarkers];
    
    // avoid an ever-growing lag by doing this async
    //
    dispatch_async(self.serialQueue, ^(void) { [self saveState:self]; });
}

- (void)saveState:(id)sender
{
    @synchronized(self)
    {
        NSMutableArray *savedMarkers = [NSMutableArray array];
        
        for (DSMRTimelineMarker *marker in self.markers)
            [savedMarkers addObject:[NSKeyedArchiver archivedDataWithRootObject:marker]];
        
        NSString *saveFilePath = [[self documentsFolderPath] stringByAppendingPathComponent:@"Document.mapresent"];
        
        [[NSDictionary dictionaryWithObject:savedMarkers forKey:@"markers"] writeToFile:saveFilePath
                                                                             atomically:YES];
    }
}

#pragma mark -
#pragma mark Presentation Controls

- (IBAction)pressedRewind:(id)sender
{
    [[self.mapView.subviews select:^BOOL(id obj) { return [obj isKindOfClass:[UIImageView class]]; }] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    [self.timelineView rewindToBeginning];
    
    self.timeLabel.text = @"0.000000";
}

- (IBAction)pressedPlayFullscreen:(id)sender
{
    [self pressedFullScreen:self];
    
    [self performSelector:@selector(pressedPlay:) withObject:self afterDelay:1.0];
    
    [TestFlight passCheckpoint:@"played fullscreen"];
}

- (IBAction)pressedPlay:(id)sender
{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    for (UIView *toggleView in self.viewsDisabledDuringPlayback)
    {
        if ([toggleView isKindOfClass:[UIControl class]])
            ((UIControl *)toggleView).enabled = ! ((UIControl *)toggleView).enabled;
        
        toggleView.userInteractionEnabled = ! toggleView.userInteractionEnabled;
    }
        
    if ([self.markers count] && [[[self.markers objectAtIndex:0] valueForKey:@"timeOffset"] floatValue] == 0 && [self.timeLabel.text floatValue] == 0)
        for (DSMRTimelineMarker *zeroMarker in [self.markers select:^BOOL(id obj) { return ([[obj valueForKey:@"timeOffset"] floatValue] == 0); }])
            [self fireMarkerAtIndex:[self.markers indexOfObject:zeroMarker]];
    
    [self.timelineView togglePlay];
        
    [[self.mapView.subviews select:^BOOL(id obj) { return [obj isKindOfClass:[UIImageView class]]; }] makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (IBAction)pressedFullScreen:(id)sender
{
    CGFloat inspectorTranslation;
    CGFloat timelineTranslation;
    CGSize  newMapSize;
    
    if (self.isFullScreen)
    {
        inspectorTranslation = -self.inspectorView.bounds.size.width;
        timelineTranslation  = -self.timelineView.bounds.size.height;
        newMapSize           = CGSizeMake(640.0, 480.0);
    }
    else
    {
        inspectorTranslation = self.inspectorView.bounds.size.width;
        timelineTranslation  = self.timelineView.bounds.size.height;
        newMapSize           = self.view.bounds.size;
    }
    
    CLLocationCoordinate2D mapCenter = self.mapView.centerCoordinate;
    
    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:UIViewAnimationCurveEaseInOut
                     animations:^(void)
                     {
                         self.mapView.frame = CGRectMake(self.mapView.frame.origin.x, self.mapView.frame.origin.y, newMapSize.width, newMapSize.height);
 
                         self.fullScreenButton.transform = CGAffineTransformRotate(self.fullScreenButton.transform, M_PI);
 
                         self.inspectorView.center = CGPointMake(self.inspectorView.center.x + inspectorTranslation, self.inspectorView.center.y);
                         self.timelineView.center  = CGPointMake(self.timelineView.center.x, self.timelineView.center.y + timelineTranslation);
 
                         self.mapView.centerCoordinate = mapCenter;
                     }
                     completion:nil];
    
    [TestFlight passCheckpoint:@"toggled fullscreen mode"];
}

#pragma mark -
#pragma mark Playback

- (void)fireMarkerAtIndex:(NSInteger)index
{
    DSMRTimelineMarker *marker = [self.markers objectAtIndex:index];
    
    if (marker.markerType == DSMRTimelineMarkerTypeLocation)
    {
        float targetZoom               = marker.zoom;
        float roundedTargetZoom        = roundf(targetZoom);
        float targetScaleFactor        = log2f(targetZoom);
        float roundedTargetScaleFactor = log2f(roundf(roundedTargetZoom));
        float zoomRatio                = targetScaleFactor / roundedTargetScaleFactor;
        float tilesPerSide             = powf(2.0, roundedTargetZoom);
        float pixelsPerSide            = (float)[self.mapView.tileSource tileSideLength] * tilesPerSide;
        float scaledPixelsPerSide      = roundf(pixelsPerSide * zoomRatio);
        float targetMetersPerPixel     = self.mapView.projection.planetBounds.size.width / scaledPixelsPerSide;
        
        RMProjectedPoint projectedCenter = [self.mapView coordinateToProjectedPoint:marker.center];
        
        RMProjectedPoint bottomLeft = RMProjectedPointMake(projectedCenter.x - ((self.mapView.bounds.size.width  * targetMetersPerPixel) / 2),
                                                           projectedCenter.y - ((self.mapView.bounds.size.height * targetMetersPerPixel) / 2));
        
        RMProjectedPoint topRight   = RMProjectedPointMake(projectedCenter.x + ((self.mapView.bounds.size.width  * targetMetersPerPixel) / 2),
                                                           projectedCenter.y + ((self.mapView.bounds.size.height * targetMetersPerPixel) / 2));
        
        [UIView animateWithDuration:1.0
                              delay:0.0
                            options:UIViewAnimationCurveLinear | UIViewAnimationOptionBeginFromCurrentState
                         animations:^(void)
                         {
                             [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:[self.mapView projectedPointToCoordinate:bottomLeft]
                                                                          northEast:[self.mapView projectedPointToCoordinate:topRight]
                                                                           animated:NO];
                         }
                         completion:nil];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeAudio)
    {
        self.player = [[AVAudioPlayer alloc] initWithData:marker.recording error:nil];
        
        [self.player play];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeTheme)
    {
        [self.mapView performSelector:@selector(setTileSource:) withObject:[[RMTileStreamSource alloc] initWithInfo:marker.tileSourceInfo] afterDelay:0.0];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeDrawing)
    {
        UIImageView *drawing = [[UIImageView alloc] initWithFrame:self.mapView.bounds];
        
        drawing.image = marker.snapshot;
        
        drawing.alpha = 0.0;
        
        [self.mapView addSubview:drawing];
        
        [UIView animateWithDuration:0.25 animations:^(void) { drawing.alpha = 1.0; }];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeDrawingClear)
    {
        for (UIImageView *drawingView in [self.mapView.subviews select:^BOOL(id obj) { return [obj isKindOfClass:[UIImageView class]]; }])
        {
            [UIView animateWithDuration:0.25
                             animations:^(void)
                             {
                                 drawingView.alpha = 0.0;
                             }
                             completion:^(BOOL finished)
                             {
                                 [drawingView removeFromSuperview];
                             }];
        }
    }
}

- (void)playToggled:(NSNotification *)notification
{
    [self.playButton setImage:[UIImage imageNamed:([self.playButton.currentImage isEqual:[UIImage imageNamed:@"play.png"]] ? @"pause.png" : @"play.png")] forState:UIControlStateNormal];
}

- (void)playProgressed:(NSNotification *)notification
{
    self.timeLabel.text = [NSString stringWithFormat:@"%f", [((NSNumber *)[notification object]) floatValue] / 64];
    
    if ([self.playButton.currentImage isEqual:[UIImage imageNamed:@"pause.png"]] && [self.timeLabel.text intValue] >= self.presentationDuration)
    {
        [self pressedPlay:self];
        
        if (self.isFullScreen)
            [self pressedFullScreen:self];
        
        [TestFlight passCheckpoint:@"played presentation to completion"];
    }
    else if ([self.playButton.currentImage isEqual:[UIImage imageNamed:@"pause.png"]] && [[self.markers valueForKeyPath:@"timeOffset"] containsObject:[NSNumber numberWithDouble:[self.timeLabel.text doubleValue]]])
    {
        for (DSMRTimelineMarker *marker in self.markers)
            if (marker.timeOffset == [self.timeLabel.text doubleValue])
                [self fireMarkerAtIndex:[self.markers indexOfObject:marker]];
    }
}

#pragma mark -
#pragma mark Video Export

- (void)beginExport
{
    [TestFlight passCheckpoint:@"began video export"];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    UIView *exportModal = [[[NSBundle mainBundle] loadNibNamed:@"DSMRExportModalView" owner:self options:nil] lastObject];
    
    UIButton *cancelButton = (UIButton *)[[exportModal.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF isKindOfClass:%@", [UIButton class]]] lastObject];
    
    [cancelButton addTarget:self action:@selector(pressedExportCancel:) forControlEvents:UIControlEventTouchUpInside];
    
    exportModal.frame = self.timelineView.frame;
    exportModal.alpha = 0.0;
    
    [self.view addSubview:exportModal];
    
    [UIView animateWithDuration:0.75
                     animations:^(void)
                     {
                         exportModal.alpha = 1.0;
                         
                         self.inspectorView.frame = CGRectMake(self.inspectorView.frame.origin.x + self.inspectorView.frame.size.width, 
                                                               self.inspectorView.frame.origin.y, 
                                                               self.inspectorView.frame.size.width, 
                                                               self.inspectorView.frame.size.height);
                         
                         self.timelineView.frame = CGRectMake(self.timelineView.frame.origin.x, 
                                                              self.timelineView.frame.origin.y + self.timelineView.frame.size.height, 
                                                              self.timelineView.frame.size.width, 
                                                              self.timelineView.frame.size.height);
                         
                         self.mapView.frame = CGRectMake((self.view.bounds.size.width - self.mapView.bounds.size.width) / 2.0, 
                                                         self.mapView.frame.origin.y, 
                                                         self.mapView.frame.size.width, 
                                                         self.mapView.frame.size.height);
                     }
                     completion:^(BOOL finished)
                     {
                         UIView *shieldView = [[UIView alloc] initWithFrame:self.mapView.frame];
                         
                         shieldView.backgroundColor = [UIColor clearColor];
                         
                         [self.view addSubview:shieldView];
                         
                         [self resetMapView];
                         
                         self.videoExporter = [[DSMRVideoExporter alloc] initWithMapView:self.mapView markers:self.markers];

                         self.videoExporter.delegate = self;

                         [self.videoExporter exportToPath:[[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"]];
                     }];
    
    self.fullScreenButton.hidden = YES;
    self.mapLabel.hidden = YES;
}

- (void)pressedExportCancel:(id)sender
{
    [self.videoExporter cancelExport];
    
    self.fullScreenButton.hidden = NO;
    self.mapLabel.hidden = NO;
    
    [self cleanupExportWithSuccess:NO];
    
    [TestFlight passCheckpoint:@"cancelled export"];
}

- (void)cleanupExportWithSuccess:(BOOL)flag
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [[self.view.subviews lastObject] removeFromSuperview]; // shield view
    [[self.view.subviews lastObject] removeFromSuperview]; // export view
    
    [UIView animateWithDuration:0.25
                     animations:^(void)
                     {
                         self.inspectorView.frame = CGRectMake(self.inspectorView.frame.origin.x - self.inspectorView.frame.size.width, 
                                                               self.inspectorView.frame.origin.y, 
                                                               self.inspectorView.frame.size.width, 
                                                               self.inspectorView.frame.size.height);
                         
                         self.timelineView.frame = CGRectMake(self.timelineView.frame.origin.x, 
                                                              self.timelineView.frame.origin.y - self.timelineView.frame.size.height, 
                                                              self.timelineView.frame.size.width, 
                                                              self.timelineView.frame.size.height);

                         self.mapView.frame = CGRectMake(self.view.bounds.origin.x, 
                                                         self.mapView.frame.origin.y, 
                                                         self.mapView.frame.size.width, 
                                                         self.mapView.frame.size.height);
                     }
                     completion:^(BOOL finished)
                     {
                         if (flag)
                         {
                             [UIAlertView showAlertViewWithTitle:@"Video Export Complete"
                                                         message:@"Your video was exported successfully. You may view, email, or open it in other apps by tapping on the Share menu."
                                               cancelButtonTitle:nil
                                               otherButtonTitles:[NSArray arrayWithObjects:@"Email Now", @"View Now", @"OK", nil]
                                                         handler:^(UIAlertView *alertView, NSInteger buttonIndex)
                              {
                                  if (buttonIndex == alertView.firstOtherButtonIndex)
                                  {
                                      [self emailLatestMovie];
                                  }
                                  else if (buttonIndex == alertView.firstOtherButtonIndex + 1)
                                  {
                                      [self playLatestMovie];
                                  }
                              }];
                         }
                     }];
}

#pragma mark -
#pragma mark Sharing

- (IBAction)pressedShare:(id)sender
{
    NSString *latestVideoPath = [[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"];
    
    CGRect attachRect = CGRectMake(696, 435, 1, 1);
    
    UIActionSheet *actionSheet = [UIActionSheet actionSheetWithTitle:nil];
    
    [actionSheet addButtonWithTitle:@"Export To Video" handler:^(void) { [self beginExport]; }];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:latestVideoPath])
    {
        [actionSheet addButtonWithTitle:@"View Latest Video"       handler:^(void) { [self playLatestMovie]; }];
        [actionSheet addButtonWithTitle:@"Email Latest Video"      handler:^(void) { [self emailLatestMovie]; }];
        
        [actionSheet addButtonWithTitle:@"Open Latest Video In..." handler:^(void)
        {
            UIDocumentInteractionController *docOpener = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:latestVideoPath]];
        
            if ( ! [docOpener presentOpenInMenuFromRect:attachRect inView:self.view animated:YES])
            {
                UIAlertView *alert = [UIAlertView alertViewWithTitle:@"No Compatible Apps" 
                                                             message:@"You don't have any apps installed that are able to open external videos."];
                
                [alert addButtonWithTitle:@"OK"];
                
                [alert show];
            }
            
            [TestFlight passCheckpoint:@"tried to open video in external apps"];
        }];
    }
    
    [actionSheet showFromRect:attachRect inView:self.view animated:YES];
    
    [TestFlight passCheckpoint:@"opened share menu"];
}

- (void)playLatestMovie
{
    NSURL *movieURL = [NSURL fileURLWithPath:[[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"]];
    
    MPMoviePlayerViewController *moviePresenter = [[MPMoviePlayerViewController alloc] initWithContentURL:movieURL];
    
    moviePresenter.moviePlayer.shouldAutoplay = NO;
    moviePresenter.moviePlayer.allowsAirPlay  = YES;
    
    [self presentMoviePlayerViewControllerAnimated:moviePresenter];
    
    [TestFlight passCheckpoint:@"played video in app"];
}

- (void)emailLatestMovie
{
    NSString *movieFile = [[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"];

    MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
    
    [mailer setSubject:@"Mapresent!"];
    [mailer setMessageBody:@"<p>&nbsp;</p><p>Powered by <a href=\"http://mapbox.com\">MapBox</a></p>" 
                    isHTML:YES];
    [mailer addAttachmentData:[NSData dataWithContentsOfFile:movieFile]
                     mimeType:@"video/mp4"
                     fileName:[movieFile lastPathComponent]];
    
    mailer.modalPresentationStyle = UIModalPresentationPageSheet;
    
    mailer.mailComposeDelegate = self;
    
    [self presentModalViewController:mailer animated:YES];
    
    [TestFlight passCheckpoint:@"emailed video"];
}

#pragma mark -
#pragma mark Timeline Editing

- (void)addMarker:(DSMRTimelineMarker *)marker refreshingInterface:(BOOL)shouldRefresh
{
    dispatch_sync(self.serialQueue, ^(void)
    {
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
    });
    
    if (shouldRefresh)
        [self refresh];
}

- (IBAction)pressedPlace:(id)sender
{
    DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
    
    marker.markerType = DSMRTimelineMarkerTypeLocation;
    marker.center     = self.mapView.centerCoordinate;
    marker.zoom       = self.mapView.zoom;
    marker.timeOffset = [self.timeLabel.text doubleValue];
    marker.sourceName = [self.mapView.tileSource shortName];
    marker.snapshot   = [self.mapView takeSnapshot];;
    
    [self addMarker:marker refreshingInterface:YES];
    
    [TestFlight passCheckpoint:@"added place marker"];
}

- (IBAction)pressedAudio:(id)sender
{
    if ( ! self.recorder.recording)
    {
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
        
        NSURL *recordURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.dat", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]]];
        
        NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithFloat:16000.0],                 AVSampleRateKey,
                                  [NSNumber numberWithInt:kAudioFormatAppleLossless], AVFormatIDKey,
                                  [NSNumber numberWithInt:1],                         AVNumberOfChannelsKey,
                                  [NSNumber numberWithInt:AVAudioQualityMax],         AVEncoderAudioQualityKey,
                                  nil];
        
        self.recorder = [[AVAudioRecorder alloc] initWithURL:recordURL settings:settings error:nil];

        UIView *shieldView = [[UIView alloc] initWithFrame:self.view.bounds];
        
        shieldView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        shieldView.alpha = 0.0;
        shieldView.tag = 8;
        
        [self.view addSubview:shieldView];
        
        DSMRAudioRecorderView *recorderView = [[DSMRAudioRecorderView alloc] initWithAudioRecorder:self.recorder target:self action:_cmd];
        
        recorderView.center = CGPointMake(round(self.view.bounds.size.width / 2), round(self.view.bounds.size.height / 2));
        
        [shieldView addSubview:recorderView];
        
        [UIView animateWithDuration:0.25
                         animations:^(void)
                         {
                             shieldView.alpha = 1.0;
                         }
                         completion:^(BOOL finished)
                         {
                             [self.recorder record];        
                         }];
    }
    else
    {
        [UIView animateWithDuration:0.25
                         animations:^(void)
                         {
                             [self.view viewWithTag:8].alpha = 0.0;
                         }
                         completion:^(BOOL finished)
                         {
                             [[self.view viewWithTag:8] removeFromSuperview];
                         }];
        
        [self.recorder stop];

        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        
        AVAudioPlayer *clip = [[AVAudioPlayer alloc] initWithContentsOfURL:self.recorder.url error:nil];
        
        DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
        
        marker.markerType = DSMRTimelineMarkerTypeAudio;
        marker.timeOffset = [self.timeLabel.text doubleValue];
        marker.recording  = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:[self.recorder.url absoluteString]]];
        marker.duration   = clip.duration;
        
        [[NSFileManager defaultManager] removeItemAtURL:self.recorder.url error:nil];
        
        [self addMarker:marker refreshingInterface:YES];
        
        [TestFlight passCheckpoint:@"added audio marker"];
    }
}

- (IBAction)pressedTheme:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view.window animated:YES].labelText = @"Loading themes...";
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://api.tiles.mapbox.com/v1/mapbox/tilesets.json"]]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
                           {
                               if ( ! error)
                               {
                                   self.themes = [NSMutableArray array];
                                   
                                   for (NSMutableDictionary *tileset in [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:nil])
                                   {
                                       RMTileStreamSource *source = [[RMTileStreamSource alloc] initWithInfo:tileset];
                                       
                                       if ([source coversFullWorld])
                                       {
                                           [tileset setObject:[NSString stringWithFormat:@"%i", ([self.themes count] + 1)] forKey:@"pageNumber"];
                                           
                                           [self.themes addObject:tileset];
                                       }
                                   }
                                   
                                   self.themePager = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl
                                                                                     navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                                                   options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:UIPageViewControllerSpineLocationMin] forKey:UIPageViewControllerOptionSpineLocationKey]];
                                   
                                   [self.themePager setViewControllers:[NSArray arrayWithObject:[[DSMRThemePickerController alloc] initWithInfo:[self.themes objectAtIndex:0]]]
                                                             direction:UIPageViewControllerNavigationDirectionForward 
                                                              animated:NO 
                                                            completion:nil];
                                   
                                   ((DSMRThemePickerController *)[self.themePager.viewControllers objectAtIndex:0]).transitioning = NO;
                                   
                                   [(UIPanGestureRecognizer *)[[self.themePager.gestureRecognizers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF isKindOfClass:%@", [UIPanGestureRecognizer class]]] lastObject] addTarget:self action:@selector(handlePagerPan:)];
                                   
                                   self.themePager.dataSource = self;
                                   self.themePager.delegate   = self;
                                   
                                   DSMRWrapperController *wrapper = [[DSMRWrapperController alloc] initWithRootViewController:self.themePager];

                                   wrapper.navigationBar.barStyle = UIBarStyleBlackTranslucent;
                                   
                                   wrapper.modalPresentationStyle = UIModalPresentationFullScreen;
                                   wrapper.modalTransitionStyle   = UIModalTransitionStyleCrossDissolve;
                                   
                                   self.themePager.navigationItem.title = @"Choose Theme";
                                   
                                   self.themePager.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                                                    target:self
                                                                                                                                    action:@selector(dismissModalViewControllerAnimated:)];
                                   
                                   self.themePager.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Choose"
                                                                                                                        style:UIBarButtonItemStyleDone
                                                                                                                       target:self
                                                                                                                       action:@selector(addThemeTransition:)];
                                   
                                   self.chosenThemeInfo = [self.themes objectAtIndex:0];
                                   
                                   [self presentModalViewController:wrapper animated:YES];
                                   
                                   [MBProgressHUD hideHUDForView:self.view.window animated:YES];
                                   
                                   [TestFlight passCheckpoint:@"browsed themes"];
                               }
                           }];
}

- (IBAction)pressedDraw:(id)sender
{
    UINavigationController *wrapper = [[UINavigationController alloc] init];
    
    UIPopoverController *drawingPopover = [[UIPopoverController alloc] initWithContentViewController:wrapper];
    
    DSMRDrawingSurfaceView *drawingView = [[DSMRDrawingSurfaceView alloc] initWithFrame:self.mapView.frame];

    DSMRDrawingPaletteViewController *drawingPalette = [[DSMRDrawingPaletteViewController alloc] initWithNibName:nil bundle:nil];

    drawingPalette.navigationItem.title = @"Draw";
    
    drawingPalette.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear Drawings"
                                                                                       style:UIBarButtonItemStyleBordered
                                                                                     handler:^(id sender)
                                                                                     {
                                                                                         // clear current drawing
                                                                                         //
                                                                                         [drawingView clearDrawings];
                                                                                         
                                                                                         // add drawing clear marker to timeline
                                                                                         //
                                                                                         DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
                                                                                         
                                                                                         marker.markerType = DSMRTimelineMarkerTypeDrawingClear;
                                                                                         marker.timeOffset = [self.timeLabel.text doubleValue];
                                                                                     
                                                                                         [self addMarker:marker refreshingInterface:NO];
                                                                                         
                                                                                         // dismiss drawing palette
                                                                                         //
                                                                                         [self popoverControllerShouldDismissPopover:drawingPopover];
                                                                                         [drawingPopover dismissPopoverAnimated:YES];
                                                                                         
                                                                                         [TestFlight passCheckpoint:@"added drawing clear marker"];
                                                                                     }];
    
    drawingPalette.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                                    handler:^(id sender)
                                                                                                    {
                                                                                                        [self popoverControllerShouldDismissPopover:drawingPopover];
                                                                                                        [drawingPopover dismissPopoverAnimated:YES];
                                                                                                    }];
    
    wrapper.viewControllers = [NSArray arrayWithObject:drawingPalette];
    
    drawingPopover.popoverContentSize = CGSizeMake(drawingPalette.view.bounds.size.width, drawingPalette.view.bounds.size.height + drawingPalette.navigationController.navigationBar.frame.size.height);
    
    drawingPopover.delegate = self;
    
    [drawingPopover presentPopoverFromRect:[self.view convertRect:[(UIView *)sender frame] fromView:self.inspectorView] 
                                    inView:self.view 
                  permittedArrowDirections:UIPopoverArrowDirectionUp 
                                  animated:YES];
    
    drawingView.delegate = drawingPalette;
    drawingView.tag = 9;
    
    drawingPopover.passthroughViews = [NSArray arrayWithObject:drawingView];
    
    [self.view addSubview:drawingView];
    
    [UIView animateWithDuration:0.25 animations:^(void) { drawingView.alpha = 1.0; }];
}

#pragma mark -
#pragma mark Theme Picking

- (void)updateThemePages
{
    DSMRThemePickerController *currentThemePicker = (DSMRThemePickerController *)[self.themePager.viewControllers lastObject];
    
    if ([self pageViewController:self.themePager viewControllerAfterViewController:currentThemePicker])
        currentThemePicker.transitioning = NO;
}

- (void)handlePagerPan:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan)
        ((DSMRThemePickerController *)[self.themePager.viewControllers lastObject]).transitioning = YES;
}

- (void)addThemeTransition:(id)sender
{
    DSMRWrapperController *wrapper    = (DSMRWrapperController *)self.modalViewController;
    UIPageViewController *pager       = (UIPageViewController *)wrapper.topViewController;
    DSMRThemePickerController *picker = (DSMRThemePickerController *)[pager.viewControllers lastObject];

    [self dismissModalViewControllerAnimated:YES];

    DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];

    marker.markerType     = DSMRTimelineMarkerTypeTheme;
    marker.timeOffset     = [self.timeLabel.text doubleValue];
    marker.tileSourceInfo = self.chosenThemeInfo;
    
    [self addMarker:marker refreshingInterface:YES];

    dispatch_async(self.serialQueue, ^(void)
    {
        marker.snapshot = picker.snapshot;
       
        [self refresh];
    });
    
    [TestFlight passCheckpoint:@"added theme marker"];
}

#pragma mark -
#pragma mark UIPageViewControllerDelegate

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    int index = [self.themes indexOfObject:((DSMRThemePickerController *)viewController).info];
    
    if (index > 0)
        return [[DSMRThemePickerController alloc] initWithInfo:[self.themes objectAtIndex:(index - 1)]];
        
    return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    int index = [self.themes indexOfObject:((DSMRThemePickerController *)viewController).info];
    
    if (index < [self.themes count] - 1)
        return [[DSMRThemePickerController alloc] initWithInfo:[self.themes objectAtIndex:(index + 1)]];
    
    return nil;
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
    int index = [self.themes indexOfObject:((DSMRThemePickerController *)[pageViewController.viewControllers lastObject]).info];

    self.chosenThemeInfo = [self.themes objectAtIndex:index];
    
    if (finished)
        [self performSelector:@selector(updateThemePages) withObject:nil afterDelay:0.0];
    
    [TestFlight passCheckpoint:@"turned theme page"];
}

#pragma mark -
#pragma mark UIPopoverControllerDelegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    // dismissed draw palette
    //
    DSMRDrawingSurfaceView *drawingView = (DSMRDrawingSurfaceView *)[self.view viewWithTag:9];
    
    [UIView animateWithDuration:0.25 
                     animations:^(void)
                     {
                         drawingView.alpha = 0.0;
                     }
                     completion:^(BOOL finished)
                     {
                         [drawingView removeFromSuperview];
                     }];
    
    UIImage *drawingImage = [drawingView snapshotImage];
    
    if (drawingImage)
    {
        // add drawing marker to timeline
        //
        DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
        
        marker.markerType = DSMRTimelineMarkerTypeDrawing;
        marker.timeOffset = [self.timeLabel.text doubleValue];
        marker.snapshot   = drawingImage;
        
        [self addMarker:marker refreshingInterface:NO];
        
        [TestFlight passCheckpoint:@"added drawing marker"];
    }

    [self refresh];

    return YES;
}

#pragma mark -
#pragma mark RMMapViewDelegate

- (void)mapViewRegionDidChange:(RMMapView *)mapView
{
    self.mapLabel.text = [NSString stringWithFormat:@"%f, %f", self.mapView.centerCoordinate.latitude, self.mapView.centerCoordinate.longitude];
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark UITableViewDataSource

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

    if (marker.markerType == DSMRTimelineMarkerTypeLocation)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Map @ %fs", marker.timeOffset];

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%f, %f)", marker.sourceName, marker.center.latitude, marker.center.longitude];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeAudio)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Audio @ %fs", marker.timeOffset];

        cell.detailTextLabel.text = [NSString stringWithFormat:@"%f seconds", marker.duration];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeTheme)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Theme @ %fs", marker.timeOffset];
        
        cell.detailTextLabel.text = [marker.tileSourceInfo objectForKey:@"name"];
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeDrawing)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Drawing @ %fs", marker.timeOffset];
        
        cell.detailTextLabel.text = nil;
    }
    else if (marker.markerType == DSMRTimelineMarkerTypeDrawingClear)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Clear Drawings @ %fs", marker.timeOffset];
        
        cell.detailTextLabel.text = nil;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.markers removeObjectAtIndex:indexPath.row];
    
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    
    [self refresh];
    
    [TestFlight passCheckpoint:@"deleted timeline marker"];
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self fireMarkerAtIndex:indexPath.row];
    
    [TestFlight passCheckpoint:@"tapped palette table marker"];
}

#pragma mark -
#pragma mark DSMRTimelineViewDelegate

- (NSArray *)timelineMarkers
{
    return [NSArray arrayWithArray:self.markers];
}

- (void)timelineMarkerTapped:(DSMRTimelineMarker *)marker
{
    if ( ! self.timelineView.isPlaying)
        [self fireMarkerAtIndex:[self.markers indexOfObject:marker]];
    
    [TestFlight passCheckpoint:@"tapped timeline marker"];
}

#pragma mark -
#pragma mark DSMRVideoExporterDelegate

- (void)videoExporterDidBeginExporting:(DSMRVideoExporter *)videoExporter
{
    NSLog(@"export began");
}

- (void)videoExporter:(DSMRVideoExporter *)videoExporter didProgressExporting:(CGFloat)completionValue
{
    NSLog(@"export progress: %f", completionValue);
}

- (void)videoExporter:(DSMRVideoExporter *)videoExporter didFailExportingWithError:(NSError *)error
{
    NSLog(@"export failure: %@", error);
    
    [self cleanupExportWithSuccess:NO];
}

- (void)videoExporterDidSucceedExporting:(DSMRVideoExporter *)videoExporter
{
    NSLog(@"export success");

    [self cleanupExportWithSuccess:YES];
    
//    UILocalNotification *notification = [[UILocalNotification alloc] init];
//    
//    notification.alertAction = @"Launch";
//    notification.alertBody   = @"The video export has completed.";
//    notification.soundName   = UILocalNotificationDefaultSoundName;
//    
//    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
//    
//    [TestFlight passCheckpoint:@"completed video export"];

}

@end