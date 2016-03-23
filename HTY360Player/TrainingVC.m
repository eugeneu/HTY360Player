//
//  TrainingVC.m
//  HTY360Player
//
//  Created by Evgeniy Upenik on 22/03/16.
//  Copyright © 2016 Hanton. All rights reserved.
//

#import "TrainingVC.h"
#import "HTY360PlayerVC.h"
#import "HTYGenericMenuVC.h"

@interface TrainingVC ()
@property (weak, nonatomic) IBOutlet UIButton *buttonPlayA;
@property (weak, nonatomic) IBOutlet UIButton *buttonPlayB;
@property (weak, nonatomic) IBOutlet UIButton *buttonNext;

@end

@implementation TrainingVC

NSArray *trainingSeqs;
NSInteger currrentTrainPairIdx = 0;

BOOL trainAPlayed = false;
BOOL trainBPlayed = false;
BOOL lastPair = false;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.title=@"Training Session";
    _buttonNext.enabled = NO;
    
    trainingSeqs = @[ @[  @[@"ld5_Drive_equirec_1920x1080_x264_qp22", @0],    @[@"ld5_Drive_cubemap_32_1620x1080_x264_qp24", @1]  ],
                      @[  @[@"ld5_Drive_equirec_1920x1080_x264_qp22", @0],    @[@"ld5_Drive_cubemap_180_1800x1080_x264_qp24", @2]  ],
                      @[  @[@"ld5_Drive_cubemap_32_1620x1080_x264_qp24", @1], @[@"ld5_Drive_cubemap_180_1800x1080_x264_qp24", @2]  ]
                      ];
    currrentTrainPairIdx = 0;
    trainAPlayed = false;
    trainBPlayed = false;
    lastPair = false;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Buttons

- (IBAction)PlayA:(id)sender {
    NSArray *currrentTrainPair = trainingSeqs[currrentTrainPairIdx][0];
    NSLog(@"currrentTrainPair = %@", currrentTrainPair);
    NSString *trainName = currrentTrainPair[0];
    NSInteger trainLayout = [[currrentTrainPair objectAtIndex:1] integerValue];
    [self launchVideoWithNameAndLayout:trainName layout:(int)trainLayout];
    trainAPlayed = true;
    _buttonPlayA.enabled = NO;
    if (trainBPlayed && !lastPair) {
        _buttonNext.enabled = YES;
    }
}
- (IBAction)PlayB:(id)sender {
    NSArray *currrentTrainPair = trainingSeqs[currrentTrainPairIdx][1];
    NSLog(@"currrentTrainPair = %@", currrentTrainPair);
    NSString *trainName = currrentTrainPair[0];
    NSInteger trainLayout = [[currrentTrainPair objectAtIndex:1] integerValue];
    [self launchVideoWithNameAndLayout:trainName layout:(int)trainLayout];
    trainBPlayed = true;
    _buttonPlayB.enabled = NO;
    if (trainAPlayed && !lastPair) {
        _buttonNext.enabled = YES;
    }
}
- (IBAction)Next:(id)sender {
    _buttonNext.enabled = NO;
    
    _buttonPlayA.enabled = YES;
    _buttonPlayB.enabled = YES;
    
    currrentTrainPairIdx += 1;
    
    [_buttonPlayA setTitle:[NSString stringWithFormat:@"Play T%ldA",currrentTrainPairIdx+1] forState: UIControlStateNormal];
    [_buttonPlayB setTitle:[NSString stringWithFormat:@"Play T%ldB",currrentTrainPairIdx+1] forState: UIControlStateNormal];
    
    if ([trainingSeqs count] <= currrentTrainPairIdx + 1 ) {
        lastPair = true;
    }
}

@end
