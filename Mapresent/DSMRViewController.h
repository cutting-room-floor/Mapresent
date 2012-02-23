//
//  DSMRViewController.h
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DSMRTimelineView.h"
#import "DSMRVideoExporter.h"

#import "RMMapViewDelegate.h"

#import <MessageUI/MessageUI.h>

@interface DSMRViewController : UIViewController <RMMapViewDelegate, 
                                                  UITableViewDataSource, 
                                                  UITableViewDelegate, 
                                                  DSMRTimelineViewDelegate, 
                                                  UIPageViewControllerDataSource, 
                                                  UIPageViewControllerDelegate, 
                                                  MFMailComposeViewControllerDelegate, 
                                                  UIPopoverControllerDelegate, 
                                                  DSMRVideoExporterDelegate>

@end