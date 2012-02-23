//
//  DSMRVideoExporter.h
//  Mapresent
//
//  Created by Justin Miller on 2/21/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DSMRVideoExporter;
@class RMMapView;

@protocol DSMRVideoExporterDelegate <NSObject>

- (void)videoExporterDidBeginExporting:(DSMRVideoExporter *)videoExporter;
- (void)videoExporter:(DSMRVideoExporter *)videoExporter didProgressExporting:(CGFloat)completionValue;
- (void)videoExporter:(DSMRVideoExporter *)videoExporter didFailExportingWithError:(NSError *)error;
- (void)videoExporterDidSucceedExporting:(DSMRVideoExporter *)videoExporter;

@end

#pragma mark -

@interface DSMRVideoExporter : NSObject

@property (nonatomic, weak) id <DSMRVideoExporterDelegate>delegate;
@property (readonly, strong) UIImage *exportSnapshot;

- (id)initWithMapView:(RMMapView *)mapView markers:(NSArray *)markers;
- (void)exportToPath:(NSString *)exportPath;
- (void)cancelExport;

@end