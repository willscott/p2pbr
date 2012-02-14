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


#define MAX_PKT_SIZE 1400

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
  AsyncUdpSocket* sock = [[AsyncUdpSocket alloc] initWithDelegate:self];
  [sock connectToHost:@"128.208.7.74" onPort:8080 error:nil];
  [self.destinations addObject:sock];
}

-(void) sendData:(NSData *)data
{
  [self.destinations enumerateObjectsUsingBlock:^(AsyncUdpSocket* obj, NSUInteger idx, BOOL *stop) {
    unsigned int chunksize = MAX_PKT_SIZE;
    int chunks = [data length]/chunksize;
    int remainder = [data length]%chunksize;
    if (remainder) {
      chunks++;
    } else {
      remainder = chunksize;
    }
    for (int i = 0; i < chunks; i++) {
      [obj sendData:[data subdataWithRange:NSMakeRange(i*chunksize, (i+1==chunks)?remainder:chunksize)] withTimeout:1000 tag:random()];
    }
  }];
}

-(NSMutableArray*)destinations
{
  if (!_destinations) {
    _destinations = [[NSMutableArray alloc] init];
  }
  return _destinations;
}


- (void)onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error;
{
  NSLog(@"Error sending:%@",error);
}



@end
