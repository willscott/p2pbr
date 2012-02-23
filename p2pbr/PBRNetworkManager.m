//
//  PBRNetworkManager.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRNetworkManager.h"
#define DEBUG_STATIC 0
#define DEBUG_STATIC_SOURCE "128.208.7.219"
#define DEBUG_STATIC_DEST "128.208.7.124"

@interface PBRNetworkManager()

@property (strong,nonatomic) NSMutableArray* sourceSockets;
@property (nonatomic) int segmentLength;
@property (nonatomic) dispatch_queue_t delegateQueue;
@property (nonatomic) dispatch_queue_t socketQueue;
@property (nonatomic, strong) NSMutableDictionary* outboundQueue;

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
@synthesize socketQueue = _socketQueue;
@synthesize delegateQueue = _delegateQueue;
@synthesize outboundQueue = _outboundQueue;

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
 
#ifdef DEBUG_STATIC
  if (self.mode) {
    [self.destinations removeAllObjects];
    GCDAsyncSocket* sock = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
    [sock connectToHost:@DEBUG_STATIC_DEST onPort:8080 error:nil];
    [self.destinations addObject:sock];  
    @synchronized(self.outboundQueue) {
      [self.outboundQueue removeAllObjects];
    }
  } else {
    [self.sourceHosts removeAllObjects];
    [self.sourceHosts addObject:@DEBUG_STATIC_SOURCE];
  }

#else
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  [NSURLConnection sendAsynchronousRequest:req queue:queue completionHandler:^(NSURLResponse* resp, NSData* data, NSError* err) {
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
    @synchronized(self.outboundQueue) {
      [self.outboundQueue removeAllObjects];
    }
    [dests enumerateObjectsUsingBlock:^(NSArray* dest, NSUInteger idx, BOOL *stop) {
      if (![dest isKindOfClass:[NSArray class]]) {
        return;
      }
      NSString* host = [dest objectAtIndex:0];
      NSNumber* port = [dest objectAtIndex:1];
  
      GCDAsyncSocket* sock = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
      [sock connectToHost:host onPort:[port intValue] error:nil];
      [self.destinations addObject:sock];
    }];
      
    NSArray* srcs = [parsed valueForKey:@"get"];
    [self.sourceHosts removeAllObjects];
    [self.sourceSockets enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      dispatch_release(self.socketQueue);
    }];
    [self.sourceSockets removeAllObjects];
    [srcs enumerateObjectsUsingBlock:^(NSString* src, NSUInteger idx, BOOL *stop) {
      [self.sourceHosts addObject:src];
    }];
    NSLog(@"Loaded %d destinations and %d sources.",[self.destinations count],[self.sourceHosts count]);
  }];
#endif

  // Clear out partial transfers.
  self.segment = nil;
}

-(void) sendData:(NSData *)data andThen:(void (^)(BOOL success))block
{
  long tag = random();
  @synchronized(self.outboundQueue) {
    [self.outboundQueue setObject:block forKey:[NSNumber numberWithLong:tag+1]];
  }
  NSLog(@"Requesting write for tag: %ld", tag);
  int len = [data length];
  NSData* length = [NSData dataWithBytes:&len length:sizeof(int)];
  [self.destinations enumerateObjectsUsingBlock:^(GCDAsyncSocket* obj, NSUInteger idx, BOOL *stop) {
    [obj writeData:length withTimeout:1000 tag:tag];
    [obj writeData:data withTimeout:1000 tag:tag+1];
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

-(GCDAsyncSocket*)receiveSocket
{
  if (!self.socketQueue) {
    self.socketQueue = dispatch_queue_create("pbrsocket", NULL);
    dispatch_retain(self.socketQueue);
  }
  if (!self.delegateQueue) {
    self.delegateQueue = dispatch_queue_create("pbrnetwork", NULL);
  }
  if (!_receiveSocket) {
    _receiveSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.delegateQueue socketQueue:self.socketQueue];
    NSError* error;
//    [_receiveSocket acceptOnPort:rand() error:&error];
    [_receiveSocket acceptOnPort:8080 error:&error];
    if (error) {
      NSLog(@"Error binding socket: %@", error);
      _receiveSocket = nil;
    }
  }
  return _receiveSocket;
}

-(NSMutableDictionary*)outboundQueue
{
  if(!_outboundQueue) {
    _outboundQueue = [[NSMutableDictionary alloc] init];
  }
  return _outboundQueue;
}



// Successful write.
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
  NSNumber* key = [NSNumber numberWithLong:tag];
  @synchronized(self.outboundQueue) {
    if ([self.outboundQueue objectForKey:key]) {
      void (^block)(BOOL success) = [self.outboundQueue objectForKey:key];
      [self.outboundQueue removeObjectForKey:key];
      block(YES);
    }
  }
}

// Unsucessful write.
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
  NSNumber* key = [NSNumber numberWithLong:tag];
  @synchronized(self.outboundQueue) {
    if ([self.outboundQueue objectForKey:key]) {
      void (^block)(BOOL success) = [self.outboundQueue objectForKey:key];
      [self.outboundQueue removeObjectForKey:key];
      block(NO);
    }
  }

  // Don't extend the timeout.
  return -1;
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
  if (!self.segment) {
    int headerLength = sizeof(int);
    int newlength;
    [data getBytes:&newlength length:headerLength];
    self.segmentLength = 0;
    self.segment = [[NSMutableData alloc] initWithLength:newlength];
    NSLog(@"Reading new chunk of length %d", newlength);
    [self socket:sock didReadData:[data subdataWithRange:NSMakeRange(headerLength, [data length] - headerLength)] withTag:tag];
    return;
  }

  BOOL done = NO;
  int len = [data length];
  //NSLog(@"Read State: %d/%d",self.segmentLength,[self.segment length]);
  if (self.segmentLength + len >= [self.segment length]) {
    done = YES;
    len = [self.segment length] - self.segmentLength;
  }
  [self.segment replaceBytesInRange:NSMakeRange(self.segmentLength, len) withBytes:[data bytes]];
  self.segmentLength += len;
  
  if (done) {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PBRSegmentReady" object:self];
    if (len < [data length]) {
      NSLog(@"De-synced D: [%d < %d]", len, [data length]);
    }
  }
  
  int next = 4096;
  if (!done && [self.segment length] - self.segmentLength < next)
  {
    next = [self.segment length] - self.segmentLength;
  }
  [sock readDataToLength:next withTimeout:1000 tag:random()];
}

- (void)socket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
  NSLog(@"Socket to %@ disconnecting due to %@", [sock connectedHost], err);
}

- (dispatch_queue_t)newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock
{
  dispatch_retain(self.socketQueue);
  return self.socketQueue;
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
  if (sock != self.receiveSocket)
  {
    NSLog(@"Unexpected accept received from unbound socket %@", sock);
    return;
  }
  
  [newSocket setDelegate:self delegateQueue:self.delegateQueue];
  [self.sourceSockets addObject:newSocket];
  [self socket:newSocket didConnectToHost:[newSocket connectedHost] port:[newSocket connectedPort]];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
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
