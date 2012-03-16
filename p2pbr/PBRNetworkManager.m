//
//  PBRNetworkManager.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRControlPacket.h"
#import "PBRNetworkManager.h"
#import "PortMapper.h"

#define UPDATE_LENGTH 2000

#define DEBUG_STATIC 1
#define DEBUG_STATIC_SOURCE "128.208.7.219"
//#define DEBUG_STATIC_SOURCE "172.28.7.55"
#define DEBUG_STATIC_DEST "128.208.7.124"

@interface PBRNetworkManager()

@property (strong,nonatomic) NSMutableArray* sourceSockets;
@property (nonatomic) unsigned int segmentLength;
@property (nonatomic) dispatch_queue_t delegateQueue;
@property (nonatomic) dispatch_queue_t socketQueue;
@property (strong,nonatomic) NSMutableDictionary* outboundQueue;

-(void) pollServer;
-(GCDAsyncSocket*) haveSocketOpenToHost:(NSString*)host onPort:(NSNumber*)port;
-(BOOL) serverDataFormatIsCorrect:(id)parsed;

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
#if !DEBUG_STATIC
    [self pollServer];
    NSTimer* pollTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(pollServer) userInfo:nil repeats:YES];
#endif
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
 
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:req queue:queue completionHandler:^(NSURLResponse* resp, NSData* data, NSError* err) {
      if (err) {
        NSLog(@"Failed to connect to server: %@", err);
        return;
      }
      
      // Keep some info on number of sockets created/retained/closed/etc.
      int sourcesGiven = 0;
      int destsGiven = 0;
      int destsCreated = 0;
      int destsRetained = 0;
      int destsClosed = 0;
      int oldDestCount = [self.destinations count];
      
      // newDestinations is a temporary variable in which we store sockets we retain or create
      // At the end, we assign self.destinations = newDestinations
      NSMutableArray* newDestinations = [[NSMutableArray alloc] init];
      
      // Parse body of webserver reponse as JSON, then check that the data is in the correct form
      id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
      if (![self serverDataFormatIsCorrect:parsed]) {
        return;
      }
      NSArray* destsGivenByServer = [parsed valueForKey:@"put"];  // array of [IP, port] pairs (string, number)
      
      destsGiven = [destsGivenByServer count];
      
      // Retain all sockets the server still wants us to talk to by moving them from self.destinations to newDestinations
      for (NSArray* dest in destsGivenByServer) {
        NSString* host = [dest objectAtIndex:0];
        NSNumber* port = [dest objectAtIndex:1];
        GCDAsyncSocket* existingSocket = [self haveSocketOpenToHost:host onPort:port];
        // Pre-existing socket? Move it to newDestinations
        if (existingSocket != nil) {
          [newDestinations addObject:existingSocket];
          [self.destinations removeObject:existingSocket];
          destsRetained++;
        }
        // Create a socket to each destination we don't already have one to
        else {
          GCDAsyncSocket* sock = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
          [sock connectToHost:host onPort:[port shortValue] error:nil];
          [newDestinations addObject:sock];    
          destsCreated++;
        }
      }
      
      // What's left in self.destinations is those sockets we have open that the server didn't tell us to keep open - close them!
      NSLog(@"have %d sockets left in self.destinations", [self.destinations count]);
      for (GCDAsyncSocket* socketToClose in self.destinations) {
        [socketToClose setDelegate:nil delegateQueue:NULL];
        [socketToClose disconnect];
        destsClosed++;
      }
      [self.destinations removeAllObjects];
      self.destinations = newDestinations;
      if (self.destinations.count == 0) {
        @synchronized(self.outboundQueue) {
          [self.outboundQueue removeAllObjects];
        }
      }

      NSArray* srcs = [parsed valueForKey:@"get"];
      sourcesGiven = [srcs count];
      [self.sourceHosts removeAllObjects];
      for (id obj in self.sourceSockets) {
        dispatch_release(self.socketQueue);
      }
      [self.sourceSockets removeAllObjects];
      for (NSString* src in srcs) {
        [self.sourceHosts addObject:src];
      }
      NSLog(@"Destinations (%d from server): of %d old sockets, retained %d and closed %d. Created %d new.  Loaded %d sources from server.",
            destsGiven, oldDestCount, destsRetained, destsClosed, destsCreated, sourcesGiven);
    }];
  
  // Clear out partial transfers.
  self.segment = nil;
}

-(void) connectTo:(NSString*)host onPort:(NSInteger)port
{
  [self.destinations removeAllObjects];
  GCDAsyncSocket* sock = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
  [sock connectToHost:host onPort:(short)port error:nil];
  [self.destinations addObject:sock];  
  @synchronized(self.outboundQueue) {
    [self.outboundQueue removeAllObjects];
  }
}

-(void) sendData:(NSData *)data andThen:(void (^)(BOOL success))block
{
  long tag = random();
  @synchronized(self.outboundQueue) {
    [self.outboundQueue setObject:[block copy] forKey:[NSNumber numberWithLong:tag+1]];
  }
  NSLog(@"Requesting write for tag: %ld", tag);
  PBRControlPacket* header = [[PBRControlPacket alloc] initWithPayload:data];
  for (GCDAsyncSocket* dst in self.destinations) {
    [dst writeData:[header data] withTimeout:1000 tag:tag];
    [dst writeData:data withTimeout:1000 tag:tag+1];
  }
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
    [_receiveSocket acceptOnPort:(short)rand() error:&error];
    if (error) {
      NSLog(@"Error binding socket: %@", error);
      _receiveSocket = nil;
    }
  }
  return _receiveSocket;
}

-(NSString*)receiveAddress
{
  return [PortMapper localAddress];
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
  NSMutableDictionary* oQueue = self.outboundQueue;
  @synchronized(oQueue) {
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
    PBRControlPacket* header = [[PBRControlPacket alloc] initFromWire:data];
    self.segmentLength = 0;
    if (header.length == 0) {
      NSLog(@"Skipping over empty chunk.");
      [sock readDataToLength:[PBRControlPacket packetLength] withTimeout:1000 tag:random()];
      return;
    }

    self.segment = [[NSMutableData alloc] initWithLength:header.length];
    NSLog(@"Reading new chunk of length %d from %@", header.length, header.stamp);

    NSAssert([data length] == [PBRControlPacket packetLength], @"Header and data concatinated.");
    NSAssert(header.length >= UPDATE_LENGTH, @"Underful chunks unimplemented.");
    [sock readDataToLength:UPDATE_LENGTH withTimeout:1000 buffer:self.segment bufferOffset:0 tag:random()];
    return;
  }

  unsigned int len = [data length];
  if (self.segmentLength + len >= [self.segment length]) {
    NSLog(@"Chunk Fully Read.");
    NSAssert(self.segmentLength + len == [self.segment length], @"Dropped beginning of new packet.");

    [[NSNotificationCenter defaultCenter] postNotificationName:@"PBRSegmentReady" object:self];
    [sock readDataToLength:[PBRControlPacket packetLength] withTimeout:1000 tag:random()];
    return;
  }

  self.segmentLength += len;

  unsigned int nextRead = MIN((unsigned)UPDATE_LENGTH, [self.segment length] - self.segmentLength);
  [sock readDataToLength:nextRead withTimeout:1000 buffer:self.segment bufferOffset:self.segmentLength tag:random()];
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
#if DEBUG_STATIC
  [self.destinations addObject:newSocket];
#endif
  [self socket:newSocket didConnectToHost:[newSocket connectedHost] port:[newSocket connectedPort]];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
#if !DEBUG_STATIC
  if ([self.sourceSockets containsObject:sock]) {
    if (![self.sourceHosts containsObject:host]) {
      NSLog(@"Unexpected source connection from %@. Should probably stop this.", host);
      return;
    }
  } else {
    NSLog(@"Unexpected connection from non-source socket. %@", host);
    return;
  }
#endif

  NSLog(@"Connected to %@", host);
  [sock readDataToLength:[PBRControlPacket packetLength] withTimeout:1000 tag:random()];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"PBRRemoteConnected" object:self];
}


- (GCDAsyncSocket*)haveSocketOpenToHost:(NSString*)host onPort:(NSNumber*)port
{
  return [[self.destinations 
                       filteredArrayUsingPredicate:[NSPredicate 
                                                    predicateWithBlock:^BOOL(GCDAsyncSocket* sock, NSDictionary *bindings) {
    return [host isEqualToString:[sock connectedHost]] && [port unsignedShortValue] == [sock connectedPort];
  }]] lastObject];
}
              
- (BOOL)serverDataFormatIsCorrect:(id)parsed
{                
    // Check data formatting from server
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Didn't end up with a valid dictionary.  got %@", parsed);
        return FALSE;
    }
    
    id destsGivenByServer = [parsed valueForKey:@"put"];
    if (![destsGivenByServer isKindOfClass:[NSArray class]]) {
        NSLog(@"list of destinations isn't an array. got %@", destsGivenByServer);
        return FALSE;
    }
    
    for (id dest in destsGivenByServer) {
        if (![dest isKindOfClass:[NSArray class]]) {
            NSLog(@"One or more destination is not an array. got %@", dest);
            return FALSE;
        }
        if (!([[dest objectAtIndex:0] isKindOfClass:[NSString class]]) ||
            !([[dest objectAtIndex:1] isKindOfClass:[NSNumber class]])) {
                NSLog(@"Host not a string or port not a number: %@", dest);
                return FALSE;
        }
    }    
    return TRUE;
}
@end
