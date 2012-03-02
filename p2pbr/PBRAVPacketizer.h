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

@interface PBRAVPacketizer : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic) BOOL active;
@property (strong, nonatomic) PBRNetworkManager* socket;

-(void) recordAudio:(AVCaptureAudioDataOutput*)audio andVideo:(AVCaptureVideoDataOutput*)video;

@end
