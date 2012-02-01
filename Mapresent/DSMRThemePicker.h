//
//  DSMRThemePicker.h
//  Mapresent
//
//  Created by Justin Miller on 1/31/12.
//  Copyright (c) 2012 Development Seed. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DSMRThemePicker : UIViewController

@property (nonatomic, strong) NSDictionary *info;

- (id)initWithInfo:(NSDictionary *)info;

@end