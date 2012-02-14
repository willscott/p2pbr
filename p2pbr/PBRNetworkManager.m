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
  //Periodically should dispatch a poll.
  AsyncSocket* sock = [[AsyncSocket alloc] initWithDelegate:self];
  [sock connectToHost:@"128.208.7.74" onPort:8080 error:nil];
  [self.destinations addObject:sock];
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


- (void)onSocket:(AsyncSocket *)sock didSendDataWithTag:(long)tag
{
}

- (void)onSocket:(AsyncSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error;
{
  NSLog(@"Error sending:%@",error);
}



@end
