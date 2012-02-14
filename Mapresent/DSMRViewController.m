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
#import "DSMRThemePicker.h"

#import "RMMapView.h"
#import "RMScrollView.h"
#import "RMMBTilesTileSource.h"
#import "RMTileStreamSource.h"

#import "MBProgressHUD.h"

#import "UIImage-Extensions.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <MediaPlayer/MediaPlayer.h>
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
@property (nonatomic, strong) IBOutlet UIButton *fullScreenButton;
@property (nonatomic, strong) NSMutableArray *markers;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSMutableArray *themes;
@property (nonatomic, strong) NSDictionary *chosenThemeInfo;
@property (nonatomic, strong) UIPageViewController *themePager;
@property (nonatomic, assign) dispatch_queue_t processingQueue;
@property (nonatomic, assign) NSTimeInterval presentationDuration;

- (IBAction)pressedPlay:(id)sender;
- (IBAction)pressedShare:(id)sender;
- (IBAction)pressedFullScreen:(id)sender;
- (void)fireMarkerAtIndex:(NSInteger)index;
- (CVPixelBufferRef )pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size;
- (NSString *)documentsFolderPath;
- (void)refresh;
- (void)saveState:(id)sender;
- (void)playLatestMovie;
- (void)emailLatestMovie;
- (void)beginExport;

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
@synthesize fullScreenButton;
@synthesize markers;
@synthesize recorder;
@synthesize player;
@synthesize themes;
@synthesize chosenThemeInfo;
@synthesize themePager;
@synthesize processingQueue;
@synthesize presentationDuration;

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
    
    self.timelineView.delegate = self;
    
    [self refresh];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playToggled:)    name:DSMRTimelineViewPlayToggled               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playProgressed:) name:DSMRTimelineViewPlayProgressed            object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveState:)      name:UIApplicationWillResignActiveNotification object:nil];
    
    processingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
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
    
    ((RMScrollView *)[self.mapView.subviews objectAtIndex:1]).animationDuration = 1.0;
    
    if ([self.markers count] && [[[self.markers objectAtIndex:0] valueForKey:@"timeOffset"] floatValue] == 0 && [self.timeLabel.text floatValue] == 0)
        [self fireMarkerAtIndex:0];
    
    if (self.timelineView.isExporting)
    {
        self.timelineView.exporting = NO;
        
        ((RMScrollView *)[self.mapView.subviews objectAtIndex:1]).animationDuration = 0.3;
        
        self.fullScreenButton.hidden = NO;
        
        [self.timelineView togglePlay];
        
        // start progress HUD
        //
        [MBProgressHUD showHUDAddedTo:self.view.window animated:YES].labelText = @"Creating video...";

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void)
        {
            // clean up capture frames
            //
            for (NSString *imageFile in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil])
            {
                if ([imageFile hasPrefix:@"snap_"] && [imageFile hasSuffix:@".png"])
                {
                    //                    dispatch_async(self.processingQueue, ^(void)
                    //                    {
                    //                        // these are not thread-safe, but that doesn't matter (much) for now
                    //                        //
                    UIImage *originalImage = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), imageFile]];
                    UIImage *croppedImage  = [originalImage imageAtRect:CGRectMake(20, 384, 480, 640)];
                    UIImage *rotatedImage  = [croppedImage imageRotatedByDegrees:90.0];
                    
                    [UIImagePNGRepresentation(rotatedImage) writeToFile:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), imageFile] atomically:YES];
                    
                    NSLog(@"processed %@", imageFile);
                    //                    });
                }
            }
            
            // make the video
            //
            // write images out to video track
            //
            CGSize size = CGSizeMake(640, 480);
            
            NSString *betaCompressionDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"export-video.m4v"];
            
            NSError *error = nil;
            
            unlink([betaCompressionDirectory UTF8String]);
            
            //----initialize compression engine
            AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:betaCompressionDirectory]
                                                                   fileType:AVFileTypeQuickTimeMovie
                                                                      error:&error];
            //            NSParameterAssert(videoWriter);
            if(error)
                NSLog(@"error = %@", [error localizedDescription]);
            
            NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                           [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                           [NSNumber numberWithInt:size.height], AVVideoHeightKey, nil];
            
            AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            
            NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                   [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
            
            AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                             sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
            //            NSParameterAssert(writerInput);
            //            NSParameterAssert([videoWriter canAddInput:writerInput]);
            
            if ([videoWriter canAddInput:writerInput])
                NSLog(@"I can add this input");
            else
                NSLog(@"i can't add this input");
            
            [videoWriter addInput:writerInput];
            
            [videoWriter startWriting];
            [videoWriter startSessionAtSourceTime:kCMTimeZero];
            
            int __block         frame = 0;
            
            for (NSString *imageFile in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil])
            {
                if ([imageFile hasPrefix:@"snap_"] && [imageFile hasSuffix:@".png"])
                {
                    
                    NSLog(@"doing %@", imageFile);
                    
                    while ( ! [writerInput isReadyForMoreMediaData])
                        [NSThread sleepForTimeInterval:0.5];
                    
                    UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), imageFile]];
                    
                    CVPixelBufferRef buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[image CGImage] size:size];
                    if (buffer)
                    {
                        if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 16.0)])
                            NSLog(@"FAIL");
                        else
                            NSLog(@"Success:%d", frame);
                        CFRelease(buffer);
                    }
                    
                    frame++;
                }
            }
            
            [writerInput markAsFinished];
            [videoWriter finishWriting];
            
            // add audio markers to video file via new composition
            //
            AVMutableComposition *composition = [AVMutableComposition composition];
            
            // get existing video asset
            //
            AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:betaCompressionDirectory] 
                                                         options:nil];
            
            // get its video track
            //
            AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
            
            // create video track on target composition
            //
            AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo 
                                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
            
            // add existing video track to target composition video track
            //
            [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) 
                                           ofTrack:videoAssetTrack 
                                            atTime:kCMTimeZero
                                             error:nil];     
            
            // iterate & add audio markers
            //
            for (DSMRTimelineMarker *marker in self.markers)
            {
                AVMutableCompositionTrack *compositionAudioTrack;
                BOOL hasAudio;
                
                if (marker.recording)
                {
                    if ( ! hasAudio)
                    {
                        // create audio track on target composition
                        //
                        compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio 
                                                                         preferredTrackID:kCMPersistentTrackID_Invalid];
                        
                        hasAudio = YES;
                    }
                    
                    // write marker audio data to temp file
                    //
                    NSString *tempFile = [NSString stringWithFormat:@"%@/%@.aiff", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]];
                    
                    [marker.recording writeToFile:tempFile atomically:YES];
                    
                    // get audio asset
                    //
                    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:tempFile] 
                                                                 options:nil];
                    
                    // get its audio track
                    //
                    AVAssetTrack *audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
                    
                    // add marker audio track to target composition audio track
                    //
                    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) 
                                                   ofTrack:audioAssetTrack 
                                                    atTime:CMTimeMake(marker.timeOffset * 1000, 1000) 
                                                     error:nil];
                    
                    // FIXME: clean up
                }
            }
            
            // setup export session for composition
            //
            AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:composition 
                                                                                 presetName:AVAssetExportPresetPassthrough];  
            
            NSString *outputPath = [betaCompressionDirectory stringByReplacingOccurrencesOfString:@"-video" withString:@""];
            
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
            
            assetExport.outputFileType = AVFileTypeMPEG4;
            assetExport.outputURL = [NSURL fileURLWithPath:outputPath];
            
            [assetExport exportAsynchronouslyWithCompletionHandler:^(void)
             {
                 switch (assetExport.status) 
                 {
                     case AVAssetExportSessionStatusCompleted:
                     {
                         NSLog(@"Export Complete");
                         
                         NSString *writtenFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"export.m4v"];
                         NSString *finalFile   = [[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"];
                         
                         [[NSFileManager defaultManager] removeItemAtPath:finalFile error:nil];
                         [[NSFileManager defaultManager] moveItemAtPath:writtenFile toPath:finalFile error:nil];
                         
                         [MBProgressHUD hideHUDForView:self.view.window animated:YES];
                         
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void)
                                        {
                                            [UIAlertView showAlertViewWithTitle:@"Video Export Complete"
                                                                        message:@"Your video exported successfully. Would you like to view it now?"
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:[NSArray arrayWithObjects:@"Email", @"View", nil]
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
                                        });
                         break;
                     }
                     case AVAssetExportSessionStatusFailed:
                     {
                         NSLog(@"Export Failed");
                         NSLog(@"ExportSessionError: %@", [assetExport.error localizedDescription]);
                         break;
                     }
                     case AVAssetExportSessionStatusCancelled:
                     {
                         NSLog(@"Export Failed");
                         NSLog(@"ExportSessionError: %@", [assetExport.error localizedDescription]);
                         break;
                     }
                 }
             }];
        });
    }
    else
        [self.timelineView togglePlay];
}

- (NSString *)documentsFolderPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)pressedFullScreen:(id)sender
{
    CGFloat inspectorTranslation;
    CGFloat timelineTranslation;
    CGSize  newMapSize;
    
    if (self.mapView.bounds.size.width == self.view.bounds.size.width)
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
}

- (CVPixelBufferRef )pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, 
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);
    // CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pxbuffer);
    
//    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL); 
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
//    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, CVPixelBufferGetBytesPerRow(pxbuffer)/*4*size.width*/, rgbColorSpace, kCGImageAlphaPremultipliedFirst);
//    NSParameterAssert(context);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

- (IBAction)pressedShare:(id)sender
{
    UIActionSheet *actionSheet = [UIActionSheet actionSheetWithTitle:nil];
    
    [actionSheet addButtonWithTitle:@"Export To Video" handler:^(void) { [self beginExport]; }];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"]])
    {
        [actionSheet addButtonWithTitle:@"View Latest Video"  handler:^(void) { [self playLatestMovie]; }];
        [actionSheet addButtonWithTitle:@"Email Latest Video" handler:^(void) { [self emailLatestMovie]; }];
    }
    
    [actionSheet showFromRect:CGRectMake(696, 435, 1, 1) inView:self.view animated:YES];
}

- (void)playLatestMovie
{
    NSURL *movieURL = [NSURL fileURLWithPath:[[self documentsFolderPath] stringByAppendingPathComponent:@"export.m4v"]];
    
    MPMoviePlayerViewController *moviePresenter = [[MPMoviePlayerViewController alloc] initWithContentURL:movieURL];
    
    moviePresenter.moviePlayer.shouldAutoplay = NO;
    
    [self presentMoviePlayerViewControllerAnimated:moviePresenter];
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
}

- (void)beginExport
{
    if ( ! self.timelineView.isExporting)
    {
        for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil])
            if ([file hasPrefix:@"snap_"] && [file hasSuffix:@".png"])
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), file] error:nil];
        
        ((RMScrollView *)[self.mapView.subviews objectAtIndex:1]).animationDuration = 8.0;
        
        self.fullScreenButton.hidden = YES;
        
        self.timelineView.exporting = YES;
        
        [NSTimer scheduledTimerWithTimeInterval:(0.5) target:self selector:@selector(takeSnapshot:) userInfo:nil repeats:YES];
        
        [self.timelineView togglePlay];
    }
}

CGImageRef UIGetScreenImage(void); // um, FIXME

- (void)takeSnapshot:(NSTimer *)timer
{
    static int i = 0;
    
    if ( ! self.timelineView.isExporting)
    {
        [timer invalidate];
        i = 0;
        return;
    }
    
    NSString *filename = [NSString stringWithFormat:@"%@/snap_%@%i.png", NSTemporaryDirectory(), (i < 10 ? @"00" : (i < 100 ? @"0" : @"")), i];
    
    CGImageRef image = UIGetScreenImage();
    
//    dispatch_async(self.processingQueue, ^(void)
//    {
        [UIImagePNGRepresentation([UIImage imageWithCGImage:image]) writeToFile:filename atomically:YES];
//    });
    
    CGImageRelease(image);
    
    i++;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    int index = [self.themes indexOfObject:((DSMRThemePicker *)viewController).info];
    
    if (index > 0)
        return [[DSMRThemePicker alloc] initWithInfo:[self.themes objectAtIndex:(index - 1)]];
        
    return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    int index = [self.themes indexOfObject:((DSMRThemePicker *)viewController).info];
    
    if (index < [self.themes count] - 1)
        return [[DSMRThemePicker alloc] initWithInfo:[self.themes objectAtIndex:(index + 1)]];
    
    return nil;
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed
{
    int index = [self.themes indexOfObject:((DSMRThemePicker *)[pageViewController.viewControllers lastObject]).info];

    self.chosenThemeInfo = [self.themes objectAtIndex:index];
    
    if (finished)
        [self performSelector:@selector(updateThemePages) withObject:nil afterDelay:0.0];
}

- (void)updateThemePages
{
    DSMRThemePicker *currentThemePicker = (DSMRThemePicker *)[self.themePager.viewControllers lastObject];
    
    if ([self pageViewController:self.themePager viewControllerAfterViewController:currentThemePicker])
        currentThemePicker.transitioning = NO;
}

- (IBAction)pressedTheme:(id)sender
{
    [MBProgressHUD showHUDAddedTo:self.view.window animated:YES].labelText = @"Loading themes...";
    
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://api.tiles.mapbox.com/v1/mapbox/tilesets.json"]]
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *error)
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
                               
                               [self.themePager setViewControllers:[NSArray arrayWithObject:[[DSMRThemePicker alloc] initWithInfo:[self.themes objectAtIndex:0]]]
                                                         direction:UIPageViewControllerNavigationDirectionForward 
                                                          animated:NO 
                                                        completion:nil];
                               
                               ((DSMRThemePicker *)[self.themePager.viewControllers objectAtIndex:0]).transitioning = NO;
                               
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
                           }];
}

- (void)handlePagerPan:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan)
        ((DSMRThemePicker *)[self.themePager.viewControllers lastObject]).transitioning = YES;
}

- (void)addThemeTransition:(id)sender
{
    [self dismissModalViewControllerAnimated:YES];
    
    DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
    
    marker.markerType     = DSMRTimelineMarkerTypeTheme;
    marker.timeOffset     = [self.timeLabel.text doubleValue];
    marker.tileSourceInfo = self.chosenThemeInfo;
    
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
    
    [self refresh];
}

- (void)refresh
{
    DSMRTimelineMarker *lastMarker = [self.markers lastObject];
    
    switch (lastMarker.markerType)
    {
        case DSMRTimelineMarkerTypeLocation:
        {
            self.presentationDuration = lastMarker.timeOffset + 2.0;
            break;
        }
        case DSMRTimelineMarkerTypeAudio:
        {
            self.presentationDuration = lastMarker.timeOffset = lastMarker.duration + 2.0;
            break;
        }
        case DSMRTimelineMarkerTypeTheme:
        {
            self.presentationDuration = lastMarker.timeOffset + 2.0;
            break;
        }
    }
    
    [self.markerTableView reloadData];
    
    [self.timelineView redrawMarkers];
    
    [self saveState:self];
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

        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        
        AVAudioPlayer *clip = [[AVAudioPlayer alloc] initWithContentsOfURL:self.recorder.url error:nil];
        
        DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
        
        marker.markerType = DSMRTimelineMarkerTypeAudio;
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
        
        [self refresh];
    }
}

- (IBAction)pressedMarker:(id)sender
{
    UIGraphicsBeginImageContext(self.mapView.bounds.size);
    
    [self.mapView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    DSMRTimelineMarker *marker = [[DSMRTimelineMarker alloc] init];
    
    marker.markerType = DSMRTimelineMarkerTypeLocation;
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

    [self refresh];
}

#pragma mark -

- (void)fireMarkerAtIndex:(NSInteger)index
{
    DSMRTimelineMarker *marker = [self.markers objectAtIndex:index];
    
    if (marker.sourceName)
    {
        [self.mapView zoomWithLatitudeLongitudeBoundsSouthWest:marker.southWest northEast:marker.northEast animated:YES];
    }
    else if (marker.recording && ! self.timelineView.isExporting) // don't play audio live when exporting
    {
        self.player = [[AVAudioPlayer alloc] initWithData:marker.recording error:nil];
    
        [self.player play];
    }
    else if (marker.tileSourceInfo)
    {
        [self.mapView performSelector:@selector(setTileSource:) withObject:[[RMTileStreamSource alloc] initWithInfo:marker.tileSourceInfo] afterDelay:0.0];
    }
}

- (void)saveState:(id)sender
{
    NSMutableArray *savedMarkers = [NSMutableArray array];
    
    for (DSMRTimelineMarker *marker in self.markers)
        [savedMarkers addObject:[NSKeyedArchiver archivedDataWithRootObject:marker]];
    
    [[NSUserDefaults standardUserDefaults] setObject:savedMarkers forKey:@"markers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSDictionary dictionaryWithObject:savedMarkers forKey:@"markers"] writeToFile:[[self documentsFolderPath] stringByAppendingPathComponent:@"Document.mapresent"]
                                                                         atomically:YES];
}

- (void)playToggled:(NSNotification *)notification
{
    [self.playButton setTitle:([self.playButton.currentTitle isEqualToString:@"Play"] ? @"Pause" : @"Play") forState:UIControlStateNormal];
}

- (void)playProgressed:(NSNotification *)notification
{
    self.timeLabel.text = [NSString stringWithFormat:@"%f", [((NSNumber *)[notification object]) floatValue] / 64];
    
    if ([self.timeLabel.text intValue] >= self.presentationDuration)
        [self pressedPlay:self];
    
    else if ([self.playButton.currentTitle isEqualToString:@"Pause"] && [[self.markers valueForKeyPath:@"timeOffset"] containsObject:[NSNumber numberWithDouble:[self.timeLabel.text doubleValue]]])
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
    else if (marker.tileSourceInfo)
    {
        cell.textLabel.text = [NSString stringWithFormat:@"Theme @ %fs", marker.timeOffset];
        
        cell.detailTextLabel.text = [marker.tileSourceInfo objectForKey:@"name"];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.markers removeObjectAtIndex:indexPath.row];
    
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    
    [self refresh];
}

#pragma mark -

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self fireMarkerAtIndex:indexPath.row];
}

#pragma mark -

- (NSArray *)timelineMarkers
{
    return [NSArray arrayWithArray:self.markers];
}

@end