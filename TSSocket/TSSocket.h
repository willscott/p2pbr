//
//  TSSocket.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>


@protocol PBRSink <NSObject>

- (BOOL) isConnected;

@end

@protocol PBRAudioSink <PBRSink>

- (void) pushAudioFrame:(NSData*)data
               withRate:(int)rate
           andFrameSize:(int)frameSize
            andChannels:(int)channels;

@end

@protocol PBRVideoSink <PBRSink>

- (void) pushVideoFrame:(NSData*)data;

@end

const NSString * TSSocketStatusDidChange;

@interface TSSocket : NSObject<PBRAudioSink, PBRVideoSink>

- (BOOL) connect;
- (BOOL) disconnect;

@end

