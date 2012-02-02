//
//  StreamWriter.m
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "StreamWriter.h"

@interface StreamWriter()
@property (strong, nonatomic) NSURL* destination;
@property (strong, nonatomic) GCDAsyncSocket* socket;
@property (strong, nonatomic) NSError* lastError;
@property (strong, nonatomic) NSNumber* tag;
@end

@implementation StreamWriter
@synthesize destination = _destination;
@synthesize socket = _socket;
@synthesize lastError = _lastError;
@synthesize tag = _tag;

- (id)initWithDestination:(NSURL *)dest
{
  self = [self init];
  if (self) {
    self.tag = [[NSNumber alloc] initWithLong:0];
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                             delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    self.destination = dest;
  }
  return self;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  if (![self.socket isConnected]) {
    return;
  }
  CMBlockBufferRef dataRef = CMSampleBufferGetDataBuffer(sampleBuffer);
  size_t length = CMBlockBufferGetDataLength(dataRef);
  if (length) {
    char* pointer;
    CMBlockBufferGetDataPointer(dataRef, 0, nil, &length, &pointer);
    NSData* data = [[NSData alloc] initWithBytesNoCopy:pointer length:length];
    [self.socket writeData:data withTimeout:1000.0 tag:[self.tag longValue]];
  }
}

- (NSNumber*) tag
{
  return [[NSNumber alloc] initWithLong:[_tag longValue] + 1];
}

- (void) connect
{
  NSString* host = [self.destination host];
  uint16_t port = [[self.destination port] intValue];
  
  NSError* err = nil;
  [self.socket connectToHost:host onPort:port withTimeout:1000.0 error:&err];
  if (err) {
    NSLog(@"Error connecting: %@", err);
  }
}

- (void) disconnect
{
  [self.socket disconnectAfterWriting];
}

@end
