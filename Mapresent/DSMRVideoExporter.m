//
//  DSMRVideoExporter.m
//  Mapresent
//
//  Created by Justin Miller on 2/21/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRVideoExporter.h"

#import "DSMRTimelineMarker.h"

#import "RMMapView.h"
#import "RMTileSource.h"
#import "RMTileStreamSource.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#define DSMRVideoExporterErrorDomain @"DSMRVideoExporterErrorDomain"

#define DSMRVideoExporterVideoWidth  1024.0f
#define DSMRVideoExporterVideoHeight  768.0f
#define DSMRVideoExporterFrameRate     30.0f

@interface DSMRVideoExporter ()

@property (strong) UIImage *exportSnapshot;
@property (nonatomic, assign, getter=isExporting) BOOL exporting;
@property (assign) BOOL shouldCancel;
@property (nonatomic, strong) RMMapView *mapView;
@property (nonatomic, strong) NSArray *markers;
@property (strong) NSMutableArray *trackedTiles;
@property (nonatomic, strong) AVAssetExportSession *assetExportSession;
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;

- (UIImage *)imageByAddingOverlayImage:(UIImage *)overlayImage toBaseImage:(UIImage *)baseImage atAlpha:(CGFloat)alpha;
- (UIImage *)fullyLoadedSnapshotForMapActions:(void (^)(void))block;
- (void)failExportingWithError:(NSError *)error;
- (void)updatePixelBufferWithCGImage:(CGImageRef)image size:(CGSize)size;
- (void)tileIn:(NSNotification *)notification;
- (void)tileOut:(NSNotification *)notification;

@end

#pragma mark -

@implementation DSMRVideoExporter

@synthesize delegate;
@synthesize exportSnapshot;
@synthesize exporting;
@synthesize shouldCancel;
@synthesize mapView=_mapView;
@synthesize markers=_markers;
@synthesize trackedTiles;
@synthesize assetExportSession;
@synthesize pixelBuffer;

- (id)initWithMapView:(RMMapView *)mapView markers:(NSArray *)markers
{
    self = [super init];
    
    if (self)
    {
        _mapView = mapView;
        _markers = markers;

        pixelBuffer = nil;
    }
    
    return self;
}

#pragma mark -

- (void)exportToPath:(NSString *)exportPath
{
    if ( ! self.isExporting)
    {
        self.exporting = YES;

        self.shouldCancel = NO;

        [self.delegate videoExporterDidBeginExporting:self];
        
        // dispatch so that we can return
        //
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void)
        {
            // start video writing session
            //
            NSString *videoOutputFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"export-video.mp4"];

            [[NSFileManager defaultManager] removeItemAtPath:videoOutputFile error:nil];

            NSError *error = nil;
            
            AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:videoOutputFile]
                                                                   fileType:AVFileTypeMPEG4
                                                                      error:&error];

            if (error)
                [self failExportingWithError:error];

            CGSize videoSize = CGSizeMake(DSMRVideoExporterVideoWidth, DSMRVideoExporterVideoHeight);
            
            NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              AVVideoCodecH264,                            AVVideoCodecKey,
                                              [NSNumber numberWithFloat:videoSize.width],  AVVideoWidthKey,
                                              [NSNumber numberWithFloat:videoSize.height], AVVideoHeightKey, 
                                              nil];

            AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];

            NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB] 
                                                                                              forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];

            AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                            sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];

            if ( ! [videoWriter canAddInput:writerInput])
                [self failExportingWithError:[NSError errorWithDomain:DSMRVideoExporterErrorDomain code:1000 userInfo:nil]];

            [videoWriter addInput:writerInput];

            [videoWriter startWriting];
            [videoWriter startSessionAtSourceTime:kCMTimeZero];

            if (self.shouldCancel)
                return;
            
            // capture initial reset frame of map
            //
            UIImage *snapshot = [self fullyLoadedSnapshotForMapActions:^(void)
            {
                [self.delegate performSelector:@selector(resetMapView)]; // FIXME decouple
            }];
            
            if (self.shouldCancel)
                return;
            
            self.exportSnapshot = snapshot;
            
            while ( ! [writerInput isReadyForMoreMediaData])
                [NSThread sleepForTimeInterval:0.5];
            
            [self updatePixelBufferWithCGImage:[snapshot CGImage] size:videoSize];
            
            if ( ! [adaptor appendPixelBuffer:self.pixelBuffer withPresentationTime:kCMTimeZero])
                [self failExportingWithError:[NSError errorWithDomain:DSMRVideoExporterErrorDomain code:1001 userInfo:nil]];
            
            UIImage *cleanMapFrame = self.exportSnapshot;
            UIImage *compositedDrawings = nil;
            
            // iterate markers, rendering each to video
            //
            for (DSMRTimelineMarker *marker in self.markers)
            {
                if (self.shouldCancel)
                    return;
                
                switch (marker.markerType)
                {
                    case DSMRTimelineMarkerTypeLocation:
                    {
                        // setup frame stepping
                        //
                        float duration = 1.0; // this will vary in the future
                        float steps    = duration * DSMRVideoExporterFrameRate;
                        
                        CLLocationCoordinate2D startCenter = self.mapView.centerCoordinate;
                        CLLocationCoordinate2D endCenter   = marker.center;
                        
                        float startZoom = self.mapView.zoom;
                        float endZoom   = marker.zoom;
                        
                        float latStep  = (endCenter.latitude  - startCenter.latitude)  / steps;
                        float lonStep  = (endCenter.longitude - startCenter.longitude) / steps;
                        float zoomStep = (endZoom - startZoom) / steps;
                        
                        // create each frame
                        //
                        for (float step = 1.0; step <= steps; step++)
                        {
                            // move map & get snapshot
                            //
                            UIImage *snapshot = [self fullyLoadedSnapshotForMapActions:^(void)
                            {
                                [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(self.mapView.centerCoordinate.latitude  + latStep, 
                                                                                             self.mapView.centerCoordinate.longitude + lonStep) 
                                                         animated:NO];
                                             
                                self.mapView.zoom = self.mapView.zoom + zoomStep;
                            }];
                            
                            if (self.shouldCancel)
                                return;
                            
                            cleanMapFrame = snapshot;
                            
                            // add drawings atop
                            //
                            snapshot = [self imageByAddingOverlayImage:compositedDrawings toBaseImage:snapshot atAlpha:1.0];
                            
                            self.exportSnapshot = snapshot;
                            
                            while ( ! [writerInput isReadyForMoreMediaData])
                                [NSThread sleepForTimeInterval:0.5];
                            
                            [self updatePixelBufferWithCGImage:[snapshot CGImage] size:videoSize];

                            CMTime frameTime = CMTimeAdd(CMTimeMake(marker.timeOffset * 1000, 1000), CMTimeMake(step, DSMRVideoExporterFrameRate));
                            
                            if( ! [adaptor appendPixelBuffer:self.pixelBuffer withPresentationTime:frameTime])
                                [self failExportingWithError:[NSError errorWithDomain:DSMRVideoExporterErrorDomain code:1002 userInfo:nil]];
                        }

                        break;
                    }
                    case DSMRTimelineMarkerTypeAudio:
                    {
                        // audio markers get added in a second pass
                        //
                        break;
                    }
                    case DSMRTimelineMarkerTypeTheme:
                    {
                        // change theme & get snapshot
                        //
                        UIImage *snapshot = [self fullyLoadedSnapshotForMapActions:^(void)
                        {
                            [self.mapView removeAllCachedImages];
                            
                            self.mapView.tileSource = [[RMTileStreamSource alloc] initWithInfo:marker.tileSourceInfo];
                        }];
                        
                        if (self.shouldCancel)
                            return;

                        cleanMapFrame = snapshot;

                        // add drawings atop
                        //
                        snapshot = [self imageByAddingOverlayImage:compositedDrawings toBaseImage:snapshot atAlpha:1.0];

                        self.exportSnapshot = snapshot;
                        
                        while ( ! [writerInput isReadyForMoreMediaData])
                            [NSThread sleepForTimeInterval:0.5];
                        
                        [self updatePixelBufferWithCGImage:[snapshot CGImage] size:videoSize];
                        
                        // FIXME: need fancy transitions like fade here
                        //
                        if( ! [adaptor appendPixelBuffer:self.pixelBuffer withPresentationTime:CMTimeMake(marker.timeOffset * 1000, 1000)])
                            [self failExportingWithError:[NSError errorWithDomain:DSMRVideoExporterErrorDomain code:1010 userInfo:nil]];
                        
                        break;
                    }
                    case DSMRTimelineMarkerTypeDrawing:
                    {
                        // append composite of drawing atop last frame
                        //
                        UIImage *snapshot = [self imageByAddingOverlayImage:marker.snapshot toBaseImage:self.exportSnapshot atAlpha:1.0];
                        
                        if (self.shouldCancel)
                            return;
                        
                        self.exportSnapshot = snapshot;
                        
                        while ( ! [writerInput isReadyForMoreMediaData])
                            [NSThread sleepForTimeInterval:0.5];
                        
                        [self updatePixelBufferWithCGImage:[snapshot CGImage] size:videoSize];
                        
                            if( ! [adaptor appendPixelBuffer:self.pixelBuffer withPresentationTime:CMTimeMake(marker.timeOffset * 1000, 1000)])
                                [self failExportingWithError:[NSError errorWithDomain:DSMRVideoExporterErrorDomain code:1011 userInfo:nil]];

                        // add image view for visual debugging purposes - FIXME
                        //
                        UIImageView *drawing = [[UIImageView alloc] initWithFrame:self.mapView.bounds];
                        
                        drawing.image = marker.snapshot;
                        drawing.tag = 11;
                        
                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                        {
                            [self.mapView addSubview:drawing];
                        });
                        
                        // cumulatively draw atop previous drawings for future frames
                        //
                        compositedDrawings = [self imageByAddingOverlayImage:marker.snapshot toBaseImage:compositedDrawings atAlpha:1.0];
                        
                        break;
                    }
                    case DSMRTimelineMarkerTypeDrawingClear:
                    {
                        // append last clean map frame 
                        //
                        UIImage *snapshot = cleanMapFrame;
                        
                        self.exportSnapshot = snapshot;
                        
                        while ( ! [writerInput isReadyForMoreMediaData])
                            [NSThread sleepForTimeInterval:0.5];
                        
                        [self updatePixelBufferWithCGImage:[snapshot CGImage] size:videoSize];
                        
                        if( ! [adaptor appendPixelBuffer:self.pixelBuffer withPresentationTime:CMTimeMake(marker.timeOffset * 1000, 1000)])
                            [self failExportingWithError:[NSError errorWithDomain:DSMRVideoExporterErrorDomain code:1011 userInfo:nil]];
                        
                        // remove debug views - FIXME
                        //
                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                        {
                            [[self.mapView.subviews select:^BOOL(id obj) { return [obj tag] == 11; }] makeObjectsPerformSelector:@selector(removeFromSuperview)];
                        });

                        // reset composited drawings
                        //
                        compositedDrawings = nil;
                        
                        break;
                    }
                    default:
                    {
                        NSLog(@"skipping export of unsupported marker of type %i", marker.markerType);
                        
                        break;
                    }
                }
            }
        
            // close video writing session
            //
            [writerInput markAsFinished];
            [videoWriter finishWriting];

            if (self.shouldCancel)
                return;
            
            // add audio markers to video file via new composition
            //
            AVMutableComposition *composition = [AVMutableComposition composition];

            // get existing video asset
            //
            AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoOutputFile] 
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

            if (self.shouldCancel)
                return;
            
            // iterate & add audio markers
            //
            AVMutableCompositionTrack *compositionAudioTrack;

            for (DSMRTimelineMarker *marker in self.markers)
            {
               if (marker.markerType == DSMRTimelineMarkerTypeAudio)
               {
                   if ( ! compositionAudioTrack)
                   {
                       // create audio track on target composition
                       //
                       compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio 
                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
                   }
                   
                   // write marker audio data to temp file
                   //
                   NSString *tempFile = [NSString stringWithFormat:@"%@%@.caf", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]];
                   
                   [marker.recording writeToFile:tempFile atomically:YES];

                   // get audio asset
                   //
                   AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:tempFile] 
                                                                options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                                                                                    forKey:AVURLAssetPreferPreciseDurationAndTimingKey]];
                   
                   // get its audio track
                   //
                   AVAssetTrack *audioAssetTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
                   
                   // add marker audio track to target composition audio track
                   //
                   [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) 
                                                  ofTrack:audioAssetTrack 
                                                   atTime:CMTimeMake(marker.timeOffset * 1000, 1000) 
                                                    error:&error];
                   
                   if (error)
                       [self failExportingWithError:error];
                   
                   // FIXME: clean up temp files
               }
            }

            // setup export session for composition
            //
            self.assetExportSession = [[AVAssetExportSession alloc] initWithAsset:composition 
                                                                       presetName:AVAssetExportPresetPassthrough];  

            NSString *combinationPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"export-combined.mp4"];

            [[NSFileManager defaultManager] removeItemAtPath:combinationPath error:nil];

            self.assetExportSession.outputFileType = AVFileTypeMPEG4;
            self.assetExportSession.outputURL = [NSURL fileURLWithPath:combinationPath];

            [self.assetExportSession exportAsynchronouslyWithCompletionHandler:^(void)
            {
                switch (self.assetExportSession.status) 
                {
                    case AVAssetExportSessionStatusCompleted:
                    {
                        NSLog(@"export session complete");
                        
                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                        {
                            [[NSFileManager defaultManager] removeItemAtPath:exportPath error:nil];
                            [[NSFileManager defaultManager] moveItemAtPath:combinationPath toPath:exportPath error:nil];
                        
                            [self.delegate videoExporterDidSucceedExporting:self];
                        });
                        
                        break;
                    }
                    case AVAssetExportSessionStatusFailed:
                    {
                        NSLog(@"export session failed");
                        
                        dispatch_sync(dispatch_get_main_queue(), ^(void)
                        {
                            [self.delegate videoExporter:self didFailExportingWithError:self.assetExportSession.error];
                        });
                        
                        break;
                    }
                    case AVAssetExportSessionStatusCancelled:
                    {
                        NSLog(@"export session cancelled");
                        
                        break;
                    }
                }
            }];
        });
    }
}

- (void)cancelExport
{
    NSLog(@"user wants to cancel");
    
    if (self.assetExportSession)
        [self.assetExportSession cancelExport];
    
    self.shouldCancel = YES;
    
    if (self.pixelBuffer)
    {
        CFRelease(self.pixelBuffer);
        self.pixelBuffer = nil;
    }
}

#pragma mark -

- (NSString *)documentsFolderPath // FIXME - dupe
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

- (UIImage *)imageByAddingOverlayImage:(UIImage *)overlayImage toBaseImage:(UIImage *)baseImage atAlpha:(CGFloat)alpha
{
    if ( ! overlayImage)
        return baseImage;
    
    if ( ! baseImage)
        return overlayImage;
    
    // do this on the main queue so we can use the UIKit convenience functions
    //
    __block UIImage *finalImage;
    
    CGRect rect = CGRectMake(0, 0, baseImage.size.width, baseImage.size.height);
    
    dispatch_sync(dispatch_get_main_queue(), ^(void)
    {
        UIGraphicsBeginImageContext(baseImage.size);

        [baseImage drawInRect:rect];

        [overlayImage drawInRect:rect blendMode:kCGBlendModeNormal alpha:alpha];

        finalImage = UIGraphicsGetImageFromCurrentImageContext();

        UIGraphicsEndImageContext();
    });

    return finalImage;
}

- (UIImage *)fullyLoadedSnapshotForMapActions:(void (^)(void))block
{
    // start tracking tiles
    //
    self.trackedTiles = [NSMutableArray array];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tileIn:)  name:RMTileRequested object:self.mapView.tileSource];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tileOut:) name:RMTileRetrieved object:self.mapView.tileSource];
    
    // perform map action(s)
    //
    dispatch_sync(dispatch_get_main_queue(), block);
    
    // wait for all tiles to load
    //
    while ([self.trackedTiles count])
        [NSThread sleepForTimeInterval:0.5];
    
    // clean up tile tracking
    //
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RMTileRequested object:self.mapView.tileSource];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RMTileRetrieved object:self.mapView.tileSource];
    
    // take snapshot
    //
    __block UIImage *snapshot;
    
    dispatch_sync(dispatch_get_main_queue(), ^(void)
    {
        snapshot = [self.mapView takeSnapshot];
    });
    
    return snapshot;
}

- (void)failExportingWithError:(NSError *)error
{
    NSLog(@"%@", error);
    
    void (^failBlock)(void) = ^
    {
        self.exporting = NO;
        
        [self.delegate videoExporter:self didFailExportingWithError:error];
    };
    
    if (dispatch_get_current_queue() != dispatch_get_main_queue())
        dispatch_sync(dispatch_get_main_queue(), failBlock);
    
    else
        failBlock();
}

- (void)updatePixelBufferWithCGImage:(CGImageRef)image size:(CGSize)size
{
    if ( ! self.pixelBuffer)
    {        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, 
                                    [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, 
                                    nil];
        
        CVPixelBufferRef buffer = nil;
        
        CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &buffer);
        
        self.pixelBuffer = buffer;
    }
        
    CVPixelBufferLockBaseAddress(self.pixelBuffer, 0);

    void *pixelData = CVPixelBufferGetBaseAddress(self.pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(pixelData, 
                                                 size.width, 
                                                 size.height, 
                                                 8, 
                                                 CVPixelBufferGetBytesPerRow(self.pixelBuffer), 
                                                 colorSpace, 
                                                 kCGImageAlphaPremultipliedFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(self.pixelBuffer, 0);
}

- (void)tileIn:(NSNotification *)notification
{
    [self.trackedTiles addObject:[notification object]];
}

- (void)tileOut:(NSNotification *)notification
{
    [self.trackedTiles removeObject:[notification object]];
}

@end