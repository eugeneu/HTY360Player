//
//  HTYGLKVC.h
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

// Video rendering layout
enum videoLayout_t {
    EQUIRECTANGULAR,
    CUBEMAP_32,
    CUBEMAP_180,
    NUM_LAYOUTS
};

@class HTY360PlayerVC;

@interface HTYGLKVC : GLKViewController<UIGestureRecognizerDelegate>

@property (strong, nonatomic, readwrite) HTY360PlayerVC* videoPlayerController;
@property (assign, nonatomic, readonly) BOOL isUsingMotion;
@property (assign, nonatomic, readwrite) enum videoLayout_t currentLayout;

- (void)startDeviceMotion;
- (void)stopDeviceMotion;

- getCurrentLayout;
- (void) nextLayout;

@end
