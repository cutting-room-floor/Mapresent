//
//  DSMRMainViewController.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRMainViewController.h"

#import "DSMRTimelineMarker.h"
#import "DSMRWrapperController.h"
#import "DSMRThemePickerController.h"
#import "DSMRAudioRecorderView.h"
#import "DSMRDrawingPaletteViewController.h"
#import "DSMRDrawingSurfaceView.h"
#import "DSMRTimelineMarkerView.h"

#import "RMMapView.h"
#import "RMMBTilesTileSource.h"
#import "RMTileStreamSource.h"

#import "MBProgressHUD.h"

#import "UIImage-Extensions.h"

#import <CoreLocation/CoreLocation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

@interface DSMRMainViewController () 

@property (nonatomic, strong) IBOutlet RMMapView *mapView;
@property (nonatomic, strong) IBOutlet UILabel *mapLabel;
@property (nonatomic, strong) IBOutlet UIView *playbackView;
@property (nonatomic, strong) IBOutlet DSMRTimelineView *timelineView;
@property (nonatomic, strong) IBOutlet UIButton *playButton;
@property (nonatomic, strong) IBOutlet UIButton *backButton;
@property (nonatomic, strong) IBOutlet UIButton *fullScreenButton;
@property (nonatomic, strong) IBOutlet UILabel *timeLabel;
@property (nonatomic, strong) IBOutletCollection() NSArray *viewsDisabledDuringPlayback;
@property (nonatomic, strong) QuadCurveMenu *toolMenu;
@property (nonatomic, strong) NSMutableArray *markers;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSMutableArray *themes;
@property (nonatomic, strong) NSDictionary *chosenThemeInfo;
@property (nonatomic, strong) UIPageViewController *themePager;
@property (nonatomic, strong) DSMRVideoExporter *videoExporter;
@property (nonatomic, strong) UIPopoverController *inspectorPopover;
@property (nonatomic, assign) dispatch_queue_t serialQueue;
@property (nonatomic, assign) NSTimeInterval presentationDuration;
@property (nonatomic, readonly, assign) BOOL isFullScreen;

- (void)resetMapView;
- (IBAction)pressedPlay:(id)sender;
- (IBAction)pressedShare:(id)sender;
- (IBAction)pressedFullScreen:(id)sender;
- (IBAction)pressedRewind:(id)sender;
- (void)fireMarkerAtIndex:(NSInteger)index;
- (NSString *)documentsFolderPath;
- (void)refresh;
- (void)saveState:(id)sender;
- (void)appWillBackground:(NSNotification *)notification;
- (void)playLatestMovie;
- (void)emailLatestMovie;
- (void)beginExport;
- (void)cleanupExportWithBlock:(BKBlock)block;
- (void)pressedExportCancel:(id)sender;
- (void)addMarker:(DSMRTimelineMarker *)marker refreshingInterface:(BOOL)shouldRefresh;

@end

#pragma mark -

@implementation DSMRMainViewController

@synthesize mapView;
@synthesize mapLabel;
@synthesize playbackView;
@synthesize timelineView;
@synthesize playButton;
@synthesize backButton;
@synthesize fullScreenButton;
@synthesize timeLabel;
@synthesize viewsDisabledDuringPlayback;
@synthesize toolMenu;
@synthesize markers;
@synthesize recorder;
@synthesize player;
@synthesize themes;
@synthesize chosenThemeInfo;
@synthesize themePager;
@synthesize videoExporter;
@synthesize inspectorPopover;
@synthesize serialQueue;
@synthesize presentationDuration;

#pragma mark -
#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    serialQueue = dispatch_queue_create("com.mapbox.mapresent.DSMRMainViewController.serial", DISPATCH_QUEUE_SERIAL);

    self.mapView.delegate = self;
    
    [self resetMapView];
    
    [RMMapView class]; // avoid code stripping
    
    timeLabel.text = @"0.00";

    markers = [NSMutableArray array];

    NSString *saveFilePath = [[self documentsFolderPath] stringByAppendingPathComponent:@"Document.mapresent"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:saveFilePath])
        for (NSData *savedMarker in [[NSDictionary dictionaryWithContentsOfFile:saveFilePath] objectForKey:@"markers"])
            [markers addObject:[NSKeyedUnarchiver unarchiveObjectWithData:savedMarker]];
    
    self.timelineView.delegate = self;
    
    [self refresh];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playToggled:)       name:DSMRTimelineViewPlayToggled               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playProgressed:)    name:DSMRTimelineViewPlayProgressed            object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    UIImage *menuItemImage        = [UIImage imageNamed:@"bg-menuitem.png"];
    UIImage *menuItemImagePressed = [UIImage imageNamed:@"bg-menuitem-highlighted.png"];
    
    NSArray *images  = [NSArray arrayWithObjects:@"point", @"audio", @"theme", @"draw", nil];
    
    NSMutableArray *menuItems = [NSMutableArray array];
    
    for (NSString *image in images)
        [menuItems addObject:[[QuadCurveMenuItem alloc] initWithImage:menuItemImage
                                                     highlightedImage:menuItemImagePressed
                                                         ContentImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@.png", image]]
                                              highlightedContentImage:nil]];
    
    toolMenu = [[QuadCurveMenu alloc] initWithFrame:CGRectMake(0, 0, 60, 60) menus:menuItems];

    toolMenu.menuWholeAngle = M_PI / 2;
    toolMenu.rotateAngle = M_PI / 2;
    toolMenu.startPoint = CGPointMake(30, 30);
    
    toolMenu.delegate = self;
    
    [self.view addSubview:toolMenu];
    
    ((UIView *)[toolMenu valueForKey:@"_addButton"]).center = toolMenu.startPoint; // FIXME well this is awful
    
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
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
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
    self.mapView.zoom             = 2.0;
    
    self.mapView.centerCoordinate = CLLocationCoordinate2DMake(30, 0);
    
    [[self.mapView.subviews select:^BOOL(id obj) { return [obj tag] == 11; }] makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (BOOL)isFullScreen
{
    return (self.mapView.bounds.size.height == self.view.bounds.size.height);
}

- (NSString *)documentsFolderPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

- (void)refresh
{
    NSTimeInterval endBumperDuration = 5.0;
    
    // synchronize changes to markers
    //
    @synchronized(self)
    {
        [self.markers sortUsingComparator:^NSComparisonResult(id obj1, id obj2)
        {
            if ([[obj1 valueForKey:@"timeOffset"] doubleValue] > [[obj2 valueForKey:@"timeOffset"] doubleValue])
                return NSOrderedDescending;
            if ([[obj1 valueForKey:@"timeOffset"] doubleValue] < [[obj2 valueForKey:@"timeOffset"] doubleValue])
                return NSOrderedAscending;
            
            return NSOrderedSame;
        }];
    }

    DSMRTimelineMarker *lastMarker = [self.markers lastObject];
    
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
    
    [self.timelineView redrawMarkers];
    
    [self saveState:self];
}

- (void)saveState:(id)sender
{
    // background this in our serial queue since the encoding can take a while
    // 
    dispatch_async(self.serialQueue, ^(void)
    {
        NSMutableArray *savedMarkers = [NSMutableArray array];
        
        // synchronize here to properly capture current marker state
        //
        @synchronized(self)
        {
            for (DSMRTimelineMarker *marker in self.markers)
                [savedMarkers addObject:[NSKeyedArchiver archivedDataWithRootObject:marker]];
        }
        
        NSString *saveFilePath = [[self documentsFolderPath] stringByAppendingPathComponent:@"Document.mapresent"];
        
        [[NSDictionary dictionaryWithObject:savedMarkers forKey:@"markers"] writeToFile:saveFilePath
                                                                             atomically:YES];
    });
}

- (void)appWillBackground:(NSNotification *)notification
{
    // don't allow export to proceed in background - FIXME better detector needed
    //
    if ([UIApplication sharedApplication].idleTimerDisabled)
        [self pressedExportCancel:self];
    
    [self saveState:self];
}

#pragma mark -
#pragma mark Presentation Controls

- (IBAction)pressedRewind:(id)sender
{
    [self resetMapView];

    [self.timelineView rewindToBeginning];
    
    self.timeLabel.text = @"0.00";
}

- (IBAction)pressedPlay:(id)sender
{
    // prepare for audio playback
    //
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    // stop any audio in progress
    //
    if (self.player.isPlaying)
        [self.player stop];

    // reset map view when starting
    //
    if ([self.timeLabel.text floatValue] == 0)
        [self resetMapView];
    
    // remove drawings
    //
    [[self.mapView.subviews select:^BOOL(id obj) { return [obj tag] == 11; }] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    // fire markers with zero offset
    //
    if ([self.markers count] && [[[self.markers objectAtIndex:0] valueForKey:@"timeOffset"] floatValue] == 0 && [self.timeLabel.text floatValue] == 0)
        for (DSMRTimelineMarker *zeroMarker in [self.markers select:^BOOL(id obj) { return ([[obj valueForKey:@"timeOffset"] floatValue] == 0); }])
            [self fireMarkerAtIndex:[self.markers indexOfObject:zeroMarker]];
    
    // toggle playback
    //
    [self.timelineView togglePlay];
}

- (IBAction)pressedFullScreen:(id)sender
{
    CGFloat timelineTranslation;
    CGSize  newMapSize;
    
    if (self.isFullScreen)
    {
        timelineTranslation  = -self.timelineView.bounds.size.height + 10.0;
        newMapSize           = CGSizeMake(1024.0, 480.0);
    }
    else
    {
        timelineTranslation  = self.timelineView.bounds.size.height - 10.0;
        newMapSize           = self.view.bounds.size;
    }
    
    CLLocationCoordinate2D mapCenter = self.mapView.centerCoordinate;
    
    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:UIViewAnimationCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^(void)
                     {
                         self.mapView.frame = CGRectMake(self.mapView.frame.origin.x, self.mapView.frame.origin.y, newMapSize.width, newMapSize.height);
 
                         self.timelineView.center  = CGPointMake(self.timelineView.center.x, self.timelineView.center.y + timelineTranslation);
 
                         self.timelineView.alpha = (self.timelineView.alpha < 1.0 ? 1.0 : 0.05);
                         
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
    
    switch (marker.markerType)
    {
        case DSMRTimelineMarkerTypeLocation:
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
            
            break;
        }
        case DSMRTimelineMarkerTypeAudio:
        {
            // do this async so we don't hold up the timeline
            //
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
            {
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];

                self.player = [[AVAudioPlayer alloc] initWithData:marker.recording error:nil];

                [self.player play];
            });
            
            break;
        }
        case DSMRTimelineMarkerTypeTheme:
        {
            // do this async so we don't hold up the timeline
            //
            dispatch_async(dispatch_get_main_queue(), ^(void)
            {
                self.mapView.tileSource = [[RMTileStreamSource alloc] initWithInfo:marker.tileSourceInfo];
            });
            
            break;
        }
        case DSMRTimelineMarkerTypeDrawing:
        {
            UIImageView *drawing = [[UIImageView alloc] initWithFrame:self.mapView.bounds];
            
            drawing.image = marker.snapshot;
            
            drawing.alpha = 0.0;
            drawing.tag = 11;
            
            [self.mapView addSubview:drawing];
            
            [UIView animateWithDuration:0.3 animations:^(void) { drawing.alpha = 1.0; }];
            
            break;
        }
        case DSMRTimelineMarkerTypeDrawingClear:
        {
            for (UIImageView *drawingView in [self.mapView.subviews select:^BOOL(id obj) { return [obj tag] == 11; }])
            {
                [UIView animateWithDuration:0.3
                                 animations:^(void)
                                 {
                                     drawingView.alpha = 0.0;
                                 }
                                 completion:^(BOOL finished)
                                 {
                                     [drawingView removeFromSuperview];
                                 }];
            }
            
            break;
        }
    }
}

- (void)playToggled:(NSNotification *)notification
{
    // adjust play button state
    //
    [self.playButton setImage:[UIImage imageNamed:([self.playButton.currentImage isEqual:[UIImage imageNamed:@"play.png"]] ? @"pause.png" : @"play.png")] forState:UIControlStateNormal];
    
    // enable/disable other appropriate buttons
    //
    for (UIView *toggleView in self.viewsDisabledDuringPlayback)
    {
        if ([toggleView isKindOfClass:[UIControl class]])
            ((UIControl *)toggleView).enabled = ! self.timelineView.isPlaying;
        
        toggleView.userInteractionEnabled = ! self.timelineView.isPlaying;
    }
}

- (void)playProgressed:(NSNotification *)notification
{
    CGFloat offsetX = [((NSNumber *)[notification object]) floatValue];
    
    NSUInteger wholeSeconds = (int)offsetX / 64;
    CGFloat fraction        = (offsetX - (wholeSeconds * 64.0)) / 64.0;
    CGFloat roundedFraction = (CGFloat)(round(fraction / 0.25) * 0.25);
    
    self.timeLabel.text = [NSString stringWithFormat:@"%5.2f", wholeSeconds + roundedFraction];
    
    if ([self.playButton.currentImage isEqual:[UIImage imageNamed:@"pause.png"]] && [self.timeLabel.text intValue] >= self.presentationDuration)
    {
        [self pressedPlay:self];
        
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
    [TestFlight passCheckpoint:@"began video export process"];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    UIView *exportModal = [[[NSBundle mainBundle] loadNibNamed:@"DSMRExportModalView" owner:self options:nil] lastObject];
    
    UIButton *cancelButton = (UIButton *)[[exportModal.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF isKindOfClass:%@", [UIButton class]]] lastObject];
    
    [cancelButton addTarget:self action:@selector(pressedExportCancel:) forControlEvents:UIControlEventTouchUpInside];
    
    exportModal.frame = self.timelineView.frame;
    exportModal.alpha = 0.0;
    
    [self.view addSubview:exportModal];
    
    if ( ! self.isFullScreen)
        [self pressedFullScreen:self];

    [UIView animateWithDuration:0.75
                     animations:^(void)
                     {
                         exportModal.alpha = 1.0;
                         
                         // move playback view right
                         //
                         self.playbackView.frame = CGRectMake(self.playbackView.frame.origin.x + self.playbackView.frame.size.width, 
                                                              self.playbackView.frame.origin.y, 
                                                              self.playbackView.frame.size.width, 
                                                              self.playbackView.frame.size.height);
                         
                         // move tool menu left
                         //
                         self.toolMenu.frame = CGRectMake(self.toolMenu.frame.origin.x - self.toolMenu.frame.size.width,
                                                          self.toolMenu.frame.origin.y, 
                                                          self.toolMenu.frame.size.width, 
                                                          self.toolMenu.frame.size.height);
                         
                         // size up to full video size & hide status bar
                         //
                         self.view.frame = CGRectMake(0, 0, 768, 1024);

                         [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
                     }
                     completion:^(BOOL finished)
                     {
                         UIView *shieldView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.mapView.bounds.size.width, self.mapView.bounds.size.height - exportModal.bounds.size.height)];
                         
                         shieldView.backgroundColor = [UIColor clearColor];
                         
                         [self.view addSubview:shieldView];
                         
                         [self resetMapView];
                         
                         self.videoExporter = [[DSMRVideoExporter alloc] initWithMapView:self.mapView markers:self.markers];

                         self.videoExporter.delegate = self;

                         [self.videoExporter exportToPath:[[self documentsFolderPath] stringByAppendingPathComponent:@"export.mp4"]];
                     }];
    
    self.mapLabel.hidden = YES;
}

- (void)pressedExportCancel:(id)sender
{
    [self.videoExporter cancelExport];
    
    self.mapLabel.hidden = NO;
    
    [self cleanupExportWithBlock:nil];
    
    [TestFlight passCheckpoint:@"cancelled video export"];
}

- (void)cleanupExportWithBlock:(BKBlock)block
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    [[self.view.subviews lastObject] removeFromSuperview]; // shield view
    [[self.view.subviews lastObject] removeFromSuperview]; // export view
    
    [UIView animateWithDuration:0.25
                     animations:^(void)
                     {                         
                         [self resetMapView];
                         
                         // move playback view left
                         //
                         self.playbackView.frame = CGRectMake(self.playbackView.frame.origin.x - self.playbackView.frame.size.width, 
                                                              self.playbackView.frame.origin.y, 
                                                              self.playbackView.frame.size.width, 
                                                              self.playbackView.frame.size.height);
                         
                         // move tool menu right
                         //
                         self.toolMenu.frame = CGRectMake(self.toolMenu.frame.origin.x + self.toolMenu.frame.size.width,
                                                          self.toolMenu.frame.origin.y, 
                                                          self.toolMenu.frame.size.width, 
                                                          self.toolMenu.frame.size.height);
                         
                         // bring back status bar
                         //
                         [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];

                         self.view.frame = CGRectMake([UIApplication sharedApplication].statusBarFrame.size.width, 
                                                      0,
                                                      768 - [UIApplication sharedApplication].statusBarFrame.size.width,
                                                      1024);
                     }
                     completion:^(BOOL finished)
                     {
                         if (self.isFullScreen)
                             [self pressedFullScreen:self];
                         
                         if (block)
                             block();
                     }];
}

#pragma mark -
#pragma mark Sharing

- (IBAction)pressedShare:(id)sender
{
    CGRect buttonRect = [self.view convertRect:((UIView *)sender).frame fromView:((UIView *)sender).superview];
    
    NSString *latestVideoPath = [[self documentsFolderPath] stringByAppendingPathComponent:@"export.mp4"];
    
    UIActionSheet *actionSheet = [UIActionSheet actionSheetWithTitle:nil];
    
    [actionSheet addButtonWithTitle:@"Export To Video" handler:^(void) { [self beginExport]; }];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:latestVideoPath])
    {
        [actionSheet addButtonWithTitle:@"View Latest Video"       handler:^(void) { [self playLatestMovie]; }];
        [actionSheet addButtonWithTitle:@"Email Latest Video"      handler:^(void) { [self emailLatestMovie]; }];
        
        [actionSheet addButtonWithTitle:@"Open Latest Video In..." handler:^(void)
        {
            UIDocumentInteractionController *docOpener = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:latestVideoPath]];
        
            if ( ! [docOpener presentOpenInMenuFromRect:buttonRect inView:self.view animated:YES])
            {
                UIAlertView *alert = [UIAlertView alertViewWithTitle:@"No Compatible Apps" 
                                                             message:@"You don't have any apps installed that are able to open external videos."];
                
                [alert addButtonWithTitle:@"OK"];
                
                [alert show];
            }
            
            [TestFlight passCheckpoint:@"tried to open video in external apps"];
        }];
    }
    
    [actionSheet showFromRect:buttonRect inView:self.view animated:YES];
    
    [TestFlight passCheckpoint:@"opened share menu"];
}

- (void)playLatestMovie
{
    NSURL *movieURL = [NSURL fileURLWithPath:[[self documentsFolderPath] stringByAppendingPathComponent:@"export.mp4"]];
    
    MPMoviePlayerViewController *moviePresenter = [[MPMoviePlayerViewController alloc] initWithContentURL:movieURL];
    
    moviePresenter.moviePlayer.shouldAutoplay = NO;
    moviePresenter.moviePlayer.allowsAirPlay  = YES;
    
    [self presentMoviePlayerViewControllerAnimated:moviePresenter];
    
    [TestFlight passCheckpoint:@"played video in app"];
}

- (void)emailLatestMovie
{
    NSString *movieFile = [[self documentsFolderPath] stringByAppendingPathComponent:@"export.mp4"];

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
    // synchronize additions to markers
    //
    @synchronized(self)
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
    }
    
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
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
        
        NSURL *recordURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.caf", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]]];
        
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
    
    [drawingPopover presentPopoverFromRect:CGRectMake(0, 0, 30, 30) 
                                    inView:self.view 
                  permittedArrowDirections:UIPopoverArrowDirectionAny 
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

    dispatch_async(dispatch_get_main_queue(), ^(void)
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
        [self performBlock:^(id sender) { [sender updateThemePages]; } afterDelay:0.0];
    
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

- (void)beforeMapMove:(RMMapView *)map
{
    if (self.timelineView.isPlaying)
    {
        [self.timelineView togglePlay];
    
        [TestFlight passCheckpoint:@"stopped playback by dragging map"];
    }
}

- (void)mapViewRegionDidChange:(RMMapView *)mapView
{
    self.mapLabel.text = [NSString stringWithFormat:@"%f, %f @ %f", self.mapView.centerCoordinate.latitude, self.mapView.centerCoordinate.longitude, self.mapView.zoom];
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark DSMRTimelineViewDelegate

- (NSArray *)markersForTimelineView:(DSMRTimelineView *)timelineView
{
    return [NSArray arrayWithArray:self.markers];
}

- (void)timelineViewToggledMinimize:(DSMRTimelineView *)timelineView
{
    [self pressedFullScreen:self];
}

- (void)timelineView:(DSMRTimelineView *)timelineView markerViewTapped:(DSMRTimelineMarkerView *)tappedMarkerView
{
    if (self.inspectorPopover.isPopoverVisible)
        [self.inspectorPopover dismissPopoverAnimated:NO];
    
    DSMRTimelineInspectorViewController *inspectorViewController = [[DSMRTimelineInspectorViewController alloc] initWithMarker:tappedMarkerView.marker];
    
    inspectorViewController.delegate = self;
    
    self.inspectorPopover = [[UIPopoverController alloc] initWithContentViewController:inspectorViewController];
    
    self.inspectorPopover.popoverContentSize = inspectorViewController.view.bounds.size;
    
    self.inspectorPopover.passthroughViews = self.timelineView.markerPassthroughViews;
    
    [self.inspectorPopover presentPopoverFromRect:[self.view convertRect:tappedMarkerView.frame fromView:tappedMarkerView.superview]
                                           inView:self.view 
                         permittedArrowDirections:UIPopoverArrowDirectionAny 
                                         animated:YES];
}

- (void)timelineView:(DSMRTimelineView *)timelineView markerViewDoubleTapped:(DSMRTimelineMarkerView *)tappedMarkerView
{
    if ( ! self.timelineView.isPlaying)
        [self fireMarkerAtIndex:[self.markers indexOfObject:tappedMarkerView.marker]];
    
    [TestFlight passCheckpoint:@"double-tapped timeline marker"];
}

- (void)timelineView:(DSMRTimelineView *)timelineView markersChanged:(NSArray *)changedMarkers
{
    [self refresh];
    
    [TestFlight passCheckpoint:@"drag-reordered markers in timeline"]; // FIXME
}

#pragma mark -
#pragma mark DSMRVideoExporterDelegate

- (void)videoExporterDidBeginExporting:(DSMRVideoExporter *)videoExporter
{
    NSLog(@"export began");
    
    [TestFlight passCheckpoint:@"started video export"];
}

- (void)videoExporter:(DSMRVideoExporter *)videoExporter didProgressExporting:(CGFloat)completionValue
{    
    // FIXME - report progress to delegate throughout
    //
    NSLog(@"export progress: %f", completionValue);
}

- (void)videoExporter:(DSMRVideoExporter *)videoExporter didFailExportingWithError:(NSError *)error
{
    NSLog(@"export failure: %@", error);
    
    [self.videoExporter cancelExport];

    [self cleanupExportWithBlock:^(void)
    {
        [UIAlertView showAlertViewWithTitle:@"Video Export Failure"
                                    message:@"There was a problem with the video export. Not much we can do about it right now."
                          cancelButtonTitle:nil
                          otherButtonTitles:[NSArray arrayWithObject:@"OK"]
                                    handler:nil];
    }];
    
    [TestFlight passCheckpoint:@"failed video export"];
}

- (void)videoExporterDidSucceedExporting:(DSMRVideoExporter *)videoExporter
{
    NSLog(@"export success");

    [self cleanupExportWithBlock:^(void)
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
    }];
    
    [TestFlight passCheckpoint:@"completed video export"];
}

#pragma mark -
#pragma mark QuadCurveMenuDelegate

- (void)quadCurveMenu:(QuadCurveMenu *)menu didSelectIndex:(NSInteger)idx
{
    NSArray *actions = [NSArray arrayWithObjects:@"Place", @"Audio", @"Theme", @"Draw", nil];
    
    SEL action = NSSelectorFromString([NSString stringWithFormat:@"pressed%@:", [actions objectAtIndex:idx]]);
    
    [self performSelector:action withObject:menu];
}

#pragma mark -
#pragma mark DSMRTimelineInspectorDelegate

- (void)timelineInspector:(DSMRTimelineInspectorViewController *)timelineInspector wantsToDeleteMarker:(DSMRTimelineMarker *)marker
{
    [self.inspectorPopover dismissPopoverAnimated:YES];
    
    @synchronized(self)
    {
        [self.markers removeObjectAtIndex:[self.markers indexOfObject:marker]];
    }
    
    [self refresh];
    
    [TestFlight passCheckpoint:@"deleted timeline marker"];
}

@end