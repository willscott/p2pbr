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
@property (nonatomic) int segmentLength;

-(void) pollServer;

@end

@implementation PBRNetworkManager

@synthesize server = _server;
@synthesize receiveSocket = _receiveSocket;
@synthesize sourceHosts = _sourceHosts;
@synthesize destinations = _destinations;
@synthesize mode = _mode;

@synthesize sourceSockets = _sourceSockets;
@synthesize segmentLength = _segmentLength;
@synthesize segment = _segment;

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
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:self.mode],@"mode",[NSNumber numberWithInt:port],@"port", nil];
    NSData* payload = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:payload];
    
  [NSURLConnection sendAsynchronousRequest:req queue:nil completionHandler:^(NSURLResponse* resp, NSData* data, NSError* err) {
    if (err) {
      NSLog(@"Failed to connect to server: %@", err);
      return;
    }

    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![parsed isKindOfClass:[NSDictionary class]]) {
      NSLog(@"Didn't end up with a valid dictionary.  got %@", parsed);
    }

    NSArray* dests = [parsed valueForKey:@"put"];
    [self.destinations removeAllObjects];
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
    [self.sourceHosts removeAllObjects];
    [self.sourceSockets removeAllObjects];
    [srcs enumerateObjectsUsingBlock:^(NSString* src, NSUInteger idx, BOOL *stop) {
      [self.sourceHosts addObject:src];
    }];
    NSLog(@"Loaded %d destinations and %d sources.",[self.destinations count],[self.sourceHosts count]);
  }];
}

-(void) sendData:(NSData *)data
{
  int len = [data length];
  NSLog(@"send data of length %d", len);
  NSData* length = [NSData dataWithBytes:&len length:sizeof(int)];
  [self.destinations enumerateObjectsUsingBlock:^(AsyncSocket* obj, NSUInteger idx, BOOL *stop) {
    NSLog(@"Sending data to destination at %@",[obj connectedHost]);
    [obj writeData:length withTimeout:1000 tag:random()];
    [obj writeData:data withTimeout:1000 tag:random()];
  }];
}

-(void) setMode:(BOOL)mode
{
  _mode = mode;
  [self pollServer];
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

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
  NSLog(@"Success sending data.");
}

/*
- (void)onSocket:(AsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
  NSLog(@"Got parital data of length %d", partialLength);
}

- (void)onSocket:(AsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
  NSLog(@"Wrote parital data of length %d", partialLength);  
}
*/

-(void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  if (!self.segment) {
    int headerLength = sizeof(int);
    int newlength;
    [data getBytes:&newlength length:headerLength];
    self.segmentLength = 0;
    self.segment = [[NSMutableData alloc] initWithLength:newlength];
    [self onSocket:sock didReadData:[data subdataWithRange:NSMakeRange(headerLength, [data length] - headerLength)] withTag:tag];
    return;
  }

  BOOL done = NO;
  int len = [data length];
  if (self.segmentLength + len >= [self.segment length]) {
    done = YES;
    len = [self.segment length] - self.segmentLength;
  }
  [self.segment replaceBytesInRange:NSMakeRange(self.segmentLength, len) withBytes:[data bytes]];
  self.segmentLength += len;
  
  if (done) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PBRSegmentReady" object:self];
    if (len < [data length]) {
      NSLog(@"De-synced D:");
    }
  }
  
  int next = 4096;
  if (!done && [self.segment length] - self.segmentLength < next)
  {
    next = [self.segment length] - self.segmentLength;
  }
  [sock readDataToLength:next withTimeout:1000 tag:random()];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
  NSLog(@"Socket to %@ disconnecting due to %@", [sock connectedHost], err);
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

- (BOOL)onSocketWillConnect:(AsyncSocket *)sock
{
  return YES;
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
  if ([self.sourceSockets containsObject:sock]) {
    if (![self.sourceHosts containsObject:host]) {
      NSLog(@"Unexpected source connection. Should probably stop this.");
    } else {
      NSLog(@"Got connection from %@", host);
      [sock readDataToLength:4096 withTimeout:1000 tag:random()];
    }
  }
}

@end
