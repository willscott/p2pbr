//
//  PBRAVPlayer.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "PBRNetworkManager.h"

@interface PBRAVPlayer : NSObject

@property (strong, nonatomic) PBRNetworkManager* socket;

-(void)playTo:(MPMoviePlayerController*)dest;

@end
