//
//  TSSocket.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PBRSink <NSObject>

- (BOOL) isConnected;

@end

@protocol PBRAudioSink <PBRSink>

- (void) pushAudioFrame:(NSData*)data atOffset:(uint64_t)offset;

@end

@protocol PBRVideoSink <PBRSink>

- (void) pushVideoFrame:(NSData*)data;

@end

@interface TSSocket : NSObject<PBRAudioSink, PBRVideoSink>

- (BOOL) connect;
- (BOOL) disconnect;

@end

