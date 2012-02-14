//
//  PBRNetworkManager.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRNetworkManager.h"

@interface PBRNetworkManager()

-(void) pollServer;

@end

@implementation PBRNetworkManager

@synthesize server = _server;
@synthesize receiveSocket = _receiveSocket;
@synthesize sources = _sources;
@synthesize destinations = _destinations;

-(id) initWithServer:(NSURL*)server
{
  self = [self init];
  if (self) {
    self.server = server;
    [self pollServer];
  }
  return self;
}

-(void) pollServer
{
  UInt16 port = [self.receiveSocket localPort];
  //Periodically should dispatch a poll.
  NSMutableURLRequest* req = [[NSMutableURLRequest alloc] initWithURL:self.server];
  [req addValue:[NSString stringWithFormat:@"%u", port] forHTTPHeaderField:@"x-local-port"];
  NSURLResponse* response;
  NSData* data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:nil];
  id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if ([parsed isMemberOfClass:[NSDictionary class]]) {
    NSArray* dests = [parsed valueForKey:@"put"];
    [dests enumerateObjectsUsingBlock:^(NSArray* dest, NSUInteger idx, BOOL *stop) {
      NSString* host = [dest objectAtIndex:0];
      NSNumber* port = [dest objectAtIndex:1];
      
      AsyncSocket* sock = [[AsyncSocket alloc] initWithDelegate:self];
      [sock connectToHost:host onPort:[port intValue] error:nil];
      [self.destinations addObject:sock];
    }];

    NSArray* srcs = [parsed valueForKey:@"get"];
    [srcs enumerateObjectsUsingBlock:^(NSString* src, NSUInteger idx, BOOL *stop) {
      [self.sources addObject:src];
    }];
    NSLog(@"Loaded %d destinations and %d sources.",[self.destinations count],[self.sources count]);
  }
}

-(void) sendData:(NSData *)data
{
  [self.destinations enumerateObjectsUsingBlock:^(AsyncSocket* obj, NSUInteger idx, BOOL *stop) {
    [obj writeData:data withTimeout:1000 tag:random()];
  }];
}

-(NSMutableArray*)destinations
{
  if (!_destinations) {
    _destinations = [[NSMutableArray alloc] init];
  }
  return _destinations;
}

-(NSMutableArray*)sources
{
  if (!_sources) {
    _sources = [[NSMutableArray alloc] init];
  }
  return _sources;
}

-(AsyncSocket*)receiveSocket
{
  if (!_receiveSocket) {
    _receiveSocket = [[AsyncSocket alloc] initWithDelegate:self];
    NSError* error;
    [_receiveSocket acceptOnPort:rand() error:&error];
    if (error) {
      NSLog(@"Error binding socket: %@", error);
      _receiveSocket = nil;
    }
  }
  return _receiveSocket;
}

- (void)onSocket:(AsyncSocket *)sock didSendDataWithTag:(long)tag
{
}

- (void)onSocket:(AsyncSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error;
{
  NSLog(@"Error sending:%@",error);
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  if (sock != self.receiveSocket)
  {
    NSLog(@"Unexpected data received from %@", sock);
  }

  NSLog(@"Got %d bytes of data", [data length]);
}

@end
