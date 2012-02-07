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
#import "TSSocket.h"

@interface StreamWriter : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic) AudioStreamBasicDescription destinationAudioFormat;

- (id)initWithSink:(id <PBRAudioSink>)sink;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end
