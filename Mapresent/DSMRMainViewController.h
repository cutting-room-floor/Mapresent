//
//  DSMRMainViewController.h
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DSMRTimelineView.h"
#import "DSMRVideoExporter.h"
#import "DSMRTimelineInspectorViewController.h"

#import "RMMapViewDelegate.h"

#import "QuadCurveMenu.h"

#import <MessageUI/MessageUI.h>

@interface DSMRMainViewController : UIViewController <RMMapViewDelegate, 
                                                      DSMRTimelineViewDelegate, 
                                                      UIPageViewControllerDataSource, 
                                                      UIPageViewControllerDelegate, 
                                                      MFMailComposeViewControllerDelegate, 
                                                      UIPopoverControllerDelegate, 
                                                      DSMRVideoExporterDelegate,
                                                      QuadCurveMenuDelegate,
                                                      DSMRTimelineInspectorDelegate>

@end