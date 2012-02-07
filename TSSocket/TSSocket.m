//
//  TSSocket.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TSSocket.h"

#include "AsyncUdpSocket.h"

@interface TSSocket()

@property (weak, nonatomic) id<TSSocketDelegate> delegate;
@property (strong, nonatomic) AsyncUdpSocket* socket;

- (void) sendPacketWithPayload:(NSData*)payload andTag:(long)tag;

@end

@implementation TSSocket

@synthesize delegate = _delegate;
@synthesize socket = _socket;

- (id) initWithDelegate:(id<TSSocketDelegate>)delegate
{
  self = [self init];
  if (self) {
    self.delegate = delegate;
  }
  return self;
}

- (void) pushAudioFrame:(NSData*)data tag:(long)tag
{
  
}

- (void) pushVideoFrame:(NSData*)data tag:(long)tag
{
  
}

- (void) sendPacketWithPayload:(NSData*)payload andTag:(long)tag
{
  NSMutableData* packet = [[NSMutableData alloc] init];
  
  [packet appendData:payload];
  [self.socket sendData:packet withTimeout:1000 tag:tag];
}

- (AsyncUdpSocket*) socket
{
  if (!_socket) {
    _socket = [[AsyncUdpSocket alloc] initWithDelegate:self];
  }
  return _socket;
}

@end

@implementation TSSocket (AsyncSocket)

- (BOOL) connectToHost:(NSString *)host onPort:(UInt16)port error:(NSError **)errPtr
{
  return [self.socket connectToHost:host onPort:port error:errPtr];
}

- (BOOL) isConnected
{
  return [self.socket isConnected];
}

@end
