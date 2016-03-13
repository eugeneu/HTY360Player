//
//  HTYMenuVC.m
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

@import Photos;

#import "HTYMenuVC.h"
#import "HTY360PlayerVC.h"

// Name of Demo Video file
NSString *demoName = @"im360_Golf_cubemap_32_1620x1080p30_x264";
NSArray *fileNameList; // TODO: Put here a list of tuples (fileNAme, layout)

@interface HTYMenuVC () <UINavigationControllerDelegate>
@end

@implementation HTYMenuVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

#pragma mark Button management

- (IBAction)playDemo:(id)sender {
    [self launchVideoWithName: demoName];
}

- (IBAction)playFile:(id)sender {
    // Get list of video files in device library
    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:nil];
    __block AVAsset *avasset;
    // Take the last added video
    PHAsset *asset = [assetsFetchResult lastObject];
    // Use original file
    PHVideoRequestOptions *videoRequestOptions = [[PHVideoRequestOptions alloc] init];
    videoRequestOptions.version = PHVideoRequestOptionsVersionOriginal;
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoRequestOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
        avasset = asset;
    }];
    NSURL *url = nil; int timer = 0;
    while(!(url = [(AVURLAsset *)avasset URL])||timer<1000) timer++; // TODO: Find a way to wait for it properly
    NSLog(@"Playing %@",url);
    HTY360PlayerVC *videoController = [[HTY360PlayerVC alloc] initWithNibName:@"HTY360PlayerVC" bundle:nil url:url];
    [self presentViewController:videoController animated:YES completion:nil];
}

@end
