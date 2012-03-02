//
//  PBRAVPacketizer.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#include "PBRNetworkManager.h"

@interface PBRAVPacketizer : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic) BOOL active;
@property (strong, nonatomic) PBRNetworkManager* socket;

-(void) recordFrom:(AVCaptureMovieFileOutput*)output;

@end
