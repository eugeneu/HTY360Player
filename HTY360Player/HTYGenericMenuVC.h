//
//  HTYGenericMenuVC.h
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HTYGenericMenuVC : UIViewController

-(void) launchVideoWithName:(NSString*)url;
-(void) launchVideoWithNameAndLayout:(NSString*)url layout:(int)layout;
-(void) openURLWithString:(NSString*)stringurl;

@end
