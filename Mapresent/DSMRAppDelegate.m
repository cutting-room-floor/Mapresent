//
//  DSMRAppDelegate.m
//  Mapresent
//
//  Created by Justin Miller on 1/24/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import "DSMRAppDelegate.h"

#import "DSMRViewController.h"

@interface DSMRAppDelegate ()

@property (nonatomic, strong) DSMRViewController *viewController;

@end

#pragma mark -

@implementation DSMRAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    self.viewController = [[DSMRViewController alloc] initWithNibName:@"DSMRViewController" bundle:nil];
    
    self.window.rootViewController = self.viewController;
    
    [self.window makeKeyAndVisible];
    
    [TestFlight takeOff:@"e801c1913c6812d34c0c7764f6bf406a_OTIwOA"];

    return YES;
}

@end