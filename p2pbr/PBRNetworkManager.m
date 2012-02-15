//
//  PBRNetworkManager.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRNetworkManager.h"

@interface PBRNetworkManager()

@property (strong,nonatomic) NSMutableArray* sourceSockets;

-(void) pollServer;

@end

@implementation PBRNetworkManager

@synthesize server = _server;
@synthesize receiveSocket = _receiveSocket;
@synthesize sourceHosts = _sourceHosts;
@synthesize sourceSockets = _sourceSockets;
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
  if ([parsed isKindOfClass:[NSDictionary class]]) {
    NSArray* dests = [parsed valueForKey:@"put"];
    [dests enumerateObjectsUsingBlock:^(NSArray* dest, NSUInteger idx, BOOL *stop) {
      if (![dest isKindOfClass:[NSArray class]]) {
        return;
      }
      NSString* host = [dest objectAtIndex:0];
      NSNumber* port = [dest objectAtIndex:1];
      
      AsyncSocket* sock = [[AsyncSocket alloc] initWithDelegate:self];
      [sock connectToHost:host onPort:[port intValue] error:nil];
      [self.destinations addObject:sock];
    }];

    NSArray* srcs = [parsed valueForKey:@"get"];
    [srcs enumerateObjectsUsingBlock:^(NSString* src, NSUInteger idx, BOOL *stop) {
      [self.sourceHosts addObject:src];
    }];
    NSLog(@"Loaded %d destinations and %d sources.",[self.destinations count],[self.sourceHosts count]);
  } else {
    NSLog(@"Didn't end up with a valid dictionary.  got %@", parsed);
  }
}

-(void) sendData:(NSData *)data
{
  int len = [data length];
  NSData* length = [NSData dataWithBytes:&len length:sizeof(int)];
  [self.destinations enumerateObjectsUsingBlock:^(AsyncSocket* obj, NSUInteger idx, BOOL *stop) {
    [obj writeData:length withTimeout:1000 tag:random()];
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

-(NSMutableArray*)sourceHosts
{
  if (!_sourceHosts) {
    _sourceHosts = [[NSMutableArray alloc] init];
  }
  return _sourceHosts;
}

-(NSMutableArray*)sourceSockets
{
  if (!_sourceSockets) {
    _sourceSockets = [[NSMutableArray alloc] init];
  }
  return _sourceSockets;
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

  NSLog(@"Got %d bytes of data", [data length]);
}

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
  if (sock != self.receiveSocket)
  {
    NSLog(@"Unexpected accept received from unbound socket %@", sock);
    return;
  }
  [newSocket setDelegate:self];
  [self.sourceSockets addObject:newSocket];
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
  if ([self.sourceSockets containsObject:sock]) {
    if (![self.sourceHosts containsObject:host]) {
      NSLog(@"Unexpected source connection. Should probably stop this.");
    } else {
      NSLog(@"Successfully got connection from %@", host);
    }
  }
}

@end
