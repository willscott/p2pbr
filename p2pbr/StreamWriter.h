//
//  StreamWriter.h
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVCaptureOutput.h>
#import <AVFoundation/AVCaptureInput.h>
#import "GCDAsyncSocket.h"

@interface StreamWriter : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic) AudioStreamBasicDescription destinationAudioFormat;

- (id)initWithDestination:(NSURL *)dest;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

- (void)connect;
- (void)disconnect;

@end
