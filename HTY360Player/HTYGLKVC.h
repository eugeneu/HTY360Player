//
//  HTYGLKVC.h
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

#define SHOW_DEBUG_LABEL 0

@class HTY360PlayerVC;

@interface HTYGLKVC : GLKViewController<UIGestureRecognizerDelegate>

@property (strong, nonatomic, readwrite) HTY360PlayerVC* videoPlayerController;
@property (assign, nonatomic, readonly) BOOL isUsingMotion;

- (void)startDeviceMotion;
- (void)stopDeviceMotion;

@end
