//
//  HTYGenericMenuVC.m
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

#import "HTYGenericMenuVC.h"
#import "HTY360PlayerVC.h"


@interface HTYGenericMenuVC () {
    
}

@end

@implementation HTYGenericMenuVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

#pragma mark Launch actions

-(void) launchVideoWithName:(NSString*)name; {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"mp4"];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    HTY360PlayerVC *videoController = [[HTY360PlayerVC alloc] initWithNibName:@"HTY360PlayerVC" bundle:nil url:url];
    
    if (![[self presentedViewController] isBeingDismissed]) {
        [self presentViewController:videoController animated:YES completion:nil];
    }
}

-(void) openURLWithString:(NSString*)stringurl {
    NSURL *url = [NSURL URLWithString:stringurl];
    [[UIApplication sharedApplication] openURL:url];
}

@end
