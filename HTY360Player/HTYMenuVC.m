//
//  HTYMenuVC.m
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

@import Photos;

#import "HTYMenuVC.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "HTY360PlayerVC.h"

@interface HTYMenuVC () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
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

#pragma mark button management

- (IBAction)playDemo:(id)sender {
    [self launchVideoWithName:@"demo"];
    //[self launchVideoWithName:@"demo3"];
}

- (IBAction)playFile:(id)sender {
//    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
//    picker.delegate = self;
//    picker.modalPresentationStyle = UIModalPresentationCurrentContext;
//    picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
//    picker.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
//    picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
//    [self presentViewController:picker animated:YES completion:nil];
    PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:nil];
//    int i = 0;
//    for (PHAsset *asset in assetsFetchResult) {
//        PHVideoRequestOptions *videoRequestOptions = [[PHVideoRequestOptions alloc] init];
//        videoRequestOptions.version = PHVideoRequestOptionsVersionOriginal;
//        
//        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoRequestOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
//            // the AVAsset object represents the original video file
//            //NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
//            NSURL *url = [(AVURLAsset *)asset URL];
////            NSLog(@"--------------------------------------------");
////            NSLog(@"INFO: %@\n", info);
////            NSLog(@"ASSET: %@\n", asset);
//            NSLog(@"URL %d: %@",i, url);
//            //HTY360PlayerVC *videoController = [[HTY360PlayerVC alloc] initWithNibName:@"HTY360PlayerVC" bundle:nil url:url];
//            //[self presentViewController:videoController animated:YES completion:nil];
//        }];
//        //break;
//        i++;
//    }
    __block AVAsset *avasset;
    PHAsset *asset = [assetsFetchResult lastObject];
    //NSLog(@"%@",asset);
    PHVideoRequestOptions *videoRequestOptions = [[PHVideoRequestOptions alloc] init];
    videoRequestOptions.version = PHVideoRequestOptionsVersionOriginal;
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:videoRequestOptions resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
        //NSLog(@"ASSET: %@\n", asset);
        avasset = asset;
    }];
    NSURL *url = nil;
    while(!(url = [(AVURLAsset *)avasset URL]));
    NSLog(@"Playing %@",url);
    HTY360PlayerVC *videoController = [[HTY360PlayerVC alloc] initWithNibName:@"HTY360PlayerVC" bundle:nil url:url];
    [self presentViewController:videoController animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    //  NSLog(@"%@", [info objectForKey:UIImagePickerControllerMediaURL]);
    NSURL *url = [info objectForKey:UIImagePickerControllerMediaURL];
    
    NSLog(@"Playing %@",url);
    HTY360PlayerVC *videoController = [[HTY360PlayerVC alloc] initWithNibName:@"HTY360PlayerVC" bundle:nil url:url];
    
    //  if(![[self presentedViewController] isBeingDismissed])
    //  {
    [self presentViewController:videoController animated:YES completion:nil];
    //  }
}

@end
