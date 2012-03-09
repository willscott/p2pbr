//
//  PBRAVPlayer.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRAVPlayer.h"

@interface PBRAVPlayer()

@property (weak, nonatomic) AVPlayer* output;
@property (strong, nonatomic) NSMutableOrderedSet* playQueue;
@property (strong, nonatomic) NSDictionary* playingItem;

-(void)onFileReceivedFromSource:(NSNotification*)note;
-(NSURL*) getTemporaryFile;

-(void)playbackEnd:(NSNotification*)note;
@end

@implementation PBRAVPlayer

@synthesize socket = _socket;

@synthesize output = _output;
@synthesize playQueue = _playQueue;
@synthesize playingItem = _playingItem;

-(void)playTo:(AVPlayer*)dest
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
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.output.currentItem];
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
  NSURL* location = [self getTemporaryFile];
  NSData* segment = [self.socket segment];
  self.socket.segment = nil;
  [segment writeToURL:location atomically:NO];
  
  AVURLAsset* file = [AVURLAsset assetWithURL:location];
  [file loadValuesAsynchronouslyForKeys:nil completionHandler:[^{
    NSLog(@"Segment ready.");
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:location, @"url", file, @"asset", nil];
    @synchronized(self.playQueue) {
      [self.playQueue addObject:dict];
    }
  } copy]];
}


-(void)playbackEnd:(NSNotification*)note
{
  NSLog(@"Playback End.");
  if ([self.playQueue count] == 0) {
    // Loading screen.
    [self.output seekToTime:CMTimeMake(0, 1)];
    [self.output play];
    return;
  } else {
    if ([self.playQueue count] > 1) {
      NSLog(@"Failing to keep up with queue.");
    }
    NSDictionary* nextItem;
    @synchronized(self.playQueue) {
      nextItem = [self.playQueue objectAtIndex:0];
      [self.playQueue removeObject:nextItem];
    }
    AVPlayerItem* playerItem = [AVPlayerItem playerItemWithAsset:[nextItem objectForKey:@"asset"]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackEnd:) 
                                                 name:AVPlayerItemDidPlayToEndTimeNotification 
                                               object:playerItem];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:AVPlayerItemDidPlayToEndTimeNotification 
                                                  object:self.output.currentItem];

    [self.output replaceCurrentItemWithPlayerItem:playerItem];
    [self.output seekToTime:CMTimeMake(0, 1)];
    [self.output play];

    if (self.playingItem) {
      NSFileManager *fileManager = [NSFileManager defaultManager];
      if ([fileManager fileExistsAtPath:[[self.playingItem objectForKey:@"url"] path]]) {
        [fileManager removeItemAtURL:[self.playingItem objectForKey:@"url"] error: nil];
      }
    } 

    self.playingItem = nextItem;
  }
}

-(NSMutableOrderedSet*) playQueue
{
  if (!_playQueue) {
    _playQueue = [[NSMutableOrderedSet alloc] initWithCapacity:5];
  }
  return _playQueue;
}

@end
