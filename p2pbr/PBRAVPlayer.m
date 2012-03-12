//
//  PBRAVPlayer.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRAVPlayer.h"

@interface PBRAVPlayer()

@property (weak, nonatomic) AVQueuePlayer* output;
@property (strong, nonatomic) NSMutableOrderedSet* fileQueue;
@property (strong, nonatomic) NSMutableOrderedSet* playQueue;
@property (strong, nonatomic) NSDictionary* playingItem;
@property (strong, nonatomic) NSDate* playingItemStartTime;

-(void)onFileReceivedFromSource:(NSNotification*)note;
-(NSURL*) getTemporaryFile;

-(void) addItemToPlayer:(AVPlayerItem*) item;

#define JITTER 0.1
@end

@implementation PBRAVPlayer

@synthesize socket = _socket;

@synthesize output = _output;
@synthesize fileQueue = _fileQueue;
@synthesize playQueue = _playQueue;
@synthesize playingItem = _playingItem;
@synthesize playingItemStartTime = _playingItemStartTime;

-(void)playTo:(AVQueuePlayer*)dest
{
  if (self.output)
  {
    [self.output pause];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([self.playQueue count] > 0) {
      for (NSDictionary* dict in self.playQueue) {
        if ([fileManager fileExistsAtPath:[[dict objectForKey:@"url"] path]]) {
          [fileManager removeItemAtURL:[dict objectForKey:@"url"] error: nil];
        }
      }
      [self.playQueue removeAllObjects];
    }
    if (self.playingItem) {
      if ([fileManager fileExistsAtPath:[[self.playingItem objectForKey:@"url"] path]]) {
        [fileManager removeItemAtURL:[self.playingItem objectForKey:@"url"] error: nil];
      }  
      self.playingItem = nil;
    }
  }
  self.output = dest;
  [self.output addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:nil];
}

-(void) setSocket:(PBRNetworkManager *)socket
{
  if (_socket) {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PBRSegmentReady" object:_socket];
  }
  _socket = socket;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFileReceivedFromSource:) name:@"PBRSegmentReady" object:socket];
}

-(NSURL*) getTemporaryFile
{
  NSURL*  result;
  
  CFUUIDRef   uuid = CFUUIDCreate(nil);
  assert(uuid != NULL);
  CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
  assert(uuidStr != NULL);
  
  result = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.mp4", NSTemporaryDirectory(), (__bridge NSString *)uuidStr]];
  assert(result != nil);
  
  CFRelease(uuidStr);
  CFRelease(uuid);
  
  return result;
}

-(void)onFileReceivedFromSource:(NSNotification*)note
{
  NSLog(@"Play Notification.");
  NSDate* start = [NSDate date];
  NSURL* location = [self getTemporaryFile];
  NSData* segment = [self.socket segment];
  self.socket.segment = nil;
  
  if ([self.output.items count] < 2) {
    [segment writeToURL:location atomically:NO];
    [self addLocationToQueue:location fromTime:start];
  } else if (self.fileQueue.count < 5) {
    [segment writeToURL:location atomically:NO];
    @synchronized(self.fileQueue) {
      [self.fileQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:location, @"url", start, @"start", nil]];
    }
  } else {
    NSLog(@"Too far behind. Dropping chunk.");    
  }
}

-(void) addLocationToQueue:(NSURL*)location fromTime:(NSDate*)start
{
  AVURLAsset* file = [AVURLAsset assetWithURL:location];
  [file loadValuesAsynchronouslyForKeys:nil completionHandler:[^{
    NSLog(@"Segment ready.");
    AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:file];
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:location, @"url", item, @"asset", start, @"start", nil];
    @synchronized(self.playQueue) {
      [self.playQueue addObject:dict];
    }
    
    [self performSelectorOnMainThread:@selector(addItemToPlayer:) withObject:item waitUntilDone:NO];
  } copy]];  
}

-(void) addItemToPlayer:(AVPlayerItem*) item
{
  if ([self.output canInsertItem:item afterItem:nil]) {
    [self.output insertItem:item afterItem:nil];
    if (self.output.rate == 0.0) {
      [self.output play];
    }
  } else {
    NSLog(@"Couldn't append item to play queue D:");
  }
}

-(void) synchronize
{
  if (!self.output.currentItem) {
    NSLog(@"No current item ???");
    return;
  } else if (self.output.currentItem == [self.playingItem objectForKey:@"asset"]) {
    return;
  }

  NSDictionary* newItem;
  @synchronized(self.playQueue) {
    newItem = [self.playQueue objectAtIndex:0];
    [self.playQueue removeObject:newItem];
  }
  
  if (newItem && self.output.currentItem != [newItem objectForKey:@"asset"]) {
    NSLog(@"Play Queue desynchronized.  That is bad");
    return;
  }

  NSTimeInterval elapsed = [[newItem objectForKey:@"start"] timeIntervalSinceNow];
  NSLog(@"Network -> Play time: %f", elapsed);

  if (self.playingItem) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[[self.playingItem objectForKey:@"url"] path]]) {
      [fileManager removeItemAtURL:[self.playingItem objectForKey:@"url"] error: nil];
    }
  } 
  
  self.playingItemStartTime = [NSDate date];
  self.playingItem = newItem;

  if (self.fileQueue.count) {
    @synchronized(self.fileQueue) {
      NSDictionary* file = [self.fileQueue objectAtIndex:0];
      [self.fileQueue removeObject:file];
      [self addLocationToQueue:[file objectForKey:@"url"] fromTime:[file objectForKey:@"start"]];
    }
  }
}

-(void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  NSAssert([object isEqual:self.output], @"Unexpected observation");
  NSLog(@"Playback changed.");
  [self synchronize];
}


-(NSMutableOrderedSet*) playQueue
{
  if (!_playQueue) {
    _playQueue = [[NSMutableOrderedSet alloc] initWithCapacity:5];
  }
  return _playQueue;
}

-(NSMutableOrderedSet*) fileQueue
{
  if (!_fileQueue) {
    _fileQueue = [[NSMutableOrderedSet alloc] initWithCapacity:5];
  }
  return _fileQueue;
}

@end
