//
//  EvaluatingVC.m
//  HTY360Player
//
//  Created by Evgeniy Upenik on 23/03/16.
//  Copyright © 2016 Hanton. All rights reserved.
//

#import "EvaluatingVC.h"
#import "HTY360PlayerVC.h"
#import "HTYGenericMenuVC.h"

@interface EvaluatingVC ()
@property (weak, nonatomic) IBOutlet UIButton *buttonPlayA;
@property (weak, nonatomic) IBOutlet UIButton *buttonPlayB;
@property (weak, nonatomic) IBOutlet UIButton *buttonNext;

@end

@implementation EvaluatingVC

NSArray *evalSeqs;
NSInteger currrentEvalPairIdx = 0;

BOOL evalAPlayed = false;
BOOL evalBPlayed = false;
BOOL lastEvalPair = false;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.title=@"Evaluating Session";
    _buttonNext.enabled = NO;
    
    evalSeqs = @[ @[ @[@"im360_Golf_equirec_1920x1080_x264_qp24", @0],     @[@"im360_Golf_cubemap_32_1620x1080_x264_qp23", @1]  ],
                  @[ @[@"im360_Golf_cubemap_32_1620x1080_x264_qp23", @1],  @[@"im360_Golf_cubemap_180_1800x1080_x264_qp24", @2]  ],
                  @[ @[@"im360_Golf_cubemap_180_1800x1080_x264_qp24", @2], @[@"im360_Golf_equirec_1920x1080_x264_qp24", @0]  ],
                  
                  @[ @[@"ld2_City_equirec_1920x1080_x264_qp22", @0],     @[@"ld2_City_cubemap_32_1620x1080_x264_qp24", @1]  ],
                  @[ @[@"ld2_City_cubemap_32_1620x1080_x264_qp24", @1],  @[@"ld2_City_cubemap_180_1800x1080_x264_qp25", @2]  ],
                  @[ @[@"ld2_City_cubemap_180_1800x1080_x264_qp25", @2], @[@"ld2_City_equirec_1920x1080_x264_qp22", @0]  ],
                  
                  @[ @[@"ld5_Mall_equirec_1920x1080_x264_qp22", @0],     @[@"ld5_Mall_cubemap_32_1620x1080_x264_qp23", @1]  ],
                  @[ @[@"ld5_Mall_cubemap_32_1620x1080_x264_qp23", @1],  @[@"ld5_Mall_cubemap_180_1800x1080_x264_qp24", @2]  ],
                  @[ @[@"ld5_Mall_cubemap_180_1800x1080_x264_qp24", @2], @[@"ld5_Mall_equirec_1920x1080_x264_qp22", @0]  ],
                  
                  @[ @[@"ld5_Tunnel_equirec_1920x1080_x264_qp23", @0], @[@"ld5_Tunnel_cubemap_32_1620x1080_x264_qp23", @1]  ],
                  @[ @[@"ld5_Tunnel_cubemap_32_1620x1080_x264_qp23", @1], @[@"ld5_Tunnel_cubemap_180_1800x1080_x264_qp23", @2]  ],
                  @[ @[@"ld5_Tunnel_cubemap_180_1800x1080_x264_qp23", @2], @[@"ld5_Tunnel_equirec_1920x1080_x264_qp23", @0]  ],
                ];
    
    currrentEvalPairIdx = 0;
    evalAPlayed = false;
    evalBPlayed = false;
    lastEvalPair = false;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)playA:(id)sender {
    NSArray *currrentEvalPair = evalSeqs[currrentEvalPairIdx][0];
    NSLog(@"currrentTrainPair = %@", currrentEvalPair);
    NSString *evalName = currrentEvalPair[0];
    NSInteger evalLayout = [[currrentEvalPair objectAtIndex:1] integerValue];
    [self launchVideoWithNameAndLayout:evalName layout: (int)evalLayout];
    evalAPlayed = true;
    _buttonPlayA.enabled = NO;
    if (evalBPlayed && !lastEvalPair) {
        _buttonNext.enabled = YES;
    }
}
- (IBAction)playB:(id)sender {
    NSArray *currrentEvalPair = evalSeqs[currrentEvalPairIdx][1];
    NSLog(@"currrentTrainPair = %@", currrentEvalPair);
    NSString *evalName = currrentEvalPair[0];
    NSInteger evalLayout = [[currrentEvalPair objectAtIndex:1] integerValue];
    [self launchVideoWithNameAndLayout:evalName layout: (int)evalLayout];
    evalBPlayed = true;
    _buttonPlayB.enabled = NO;
    if (evalAPlayed && !lastEvalPair) {
        _buttonNext.enabled = YES;
    }
}
- (IBAction)Next:(id)sender {
    _buttonNext.enabled = NO;
    
    _buttonPlayA.enabled = YES;
    _buttonPlayB.enabled = YES;
    
    currrentEvalPairIdx += 1;
    
    [_buttonPlayA setTitle:[NSString stringWithFormat:@"Play %dA",(int)currrentEvalPairIdx+1] forState: UIControlStateNormal];
    [_buttonPlayB setTitle:[NSString stringWithFormat:@"Play %dB",(int)currrentEvalPairIdx+1] forState: UIControlStateNormal];
    
    if ([evalSeqs count] <= currrentEvalPairIdx + 1 ) {
        lastEvalPair = true;
    }
}

@end
