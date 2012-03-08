//
//  PBRConnectViewController.h
//  p2pbr
//
//  Created by willscott@gmail.com on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PBRNetworkManager.h"

@interface PBRConnectViewController : UITableViewController <UITextFieldDelegate>

@property (weak, nonatomic) PBRNetworkManager* network;

- (BOOL)textFieldShouldReturn:(UITextField *)textField;

@end
