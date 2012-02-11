//
//  StreamWriter.h
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "TSSocket.h"

@interface StreamWriter : NSObject

- (id)initWithSink:(id <PBRAudioSink>)sink;

- (BOOL)isRunning;

@end
