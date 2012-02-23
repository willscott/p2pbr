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
@property (strong, nonatomic) NSURL* currentSegment;

-(void)onFileReceivedFromSource:(NSNotification*)note;
-(NSURL*) getTemporaryFile;

-(void)startPlayback:(AVAsset*)asset;
-(void)playbackEnd:(NSNotification*)note;
@end

@implementation PBRAVPlayer

@synthesize socket = _socket;

@synthesize output = _output;
@synthesize currentSegment = _currentSegment;

-(void)playTo:(AVPlayer*)dest
{
  if (self.output)
  {
    [self.output pause];
    if (self.currentSegment) {
      NSFileManager *fileManager = [NSFileManager defaultManager];
      if ([fileManager fileExistsAtPath:[self.currentSegment path]]) {
        [fileManager removeItemAtURL:self.currentSegment error: nil];
      }
      self.currentSegment = nil;
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
  self.currentSegment = [self getTemporaryFile];
  NSData* segment = [self.socket segment];
  self.socket.segment = nil;
  [segment writeToURL:self.currentSegment atomically:NO];
  
  AVURLAsset* file = [AVURLAsset assetWithURL:self.currentSegment];
  [file loadValuesAsynchronouslyForKeys:nil completionHandler:^(void) {
    // Dispatch again to the main queue, in order to properly interact with the UI.
    dispatch_async(dispatch_get_main_queue(), ^(void) {
      [self startPlayback:file];
    });
  }];
}
     
-(void)startPlayback:(AVAsset*)asset
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.output.currentItem];
  AVURLAsset* oldItem;
  if([self.output.currentItem.asset isKindOfClass:[AVURLAsset class]]) {
    oldItem = (AVURLAsset*)self.output.currentItem.asset;
  }
  AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
  [self.output replaceCurrentItemWithPlayerItem:item];
  [self.output seekToTime:CMTimeMake(0, 1)];
  [self.output play];

  if (oldItem && [oldItem.URL.path hasPrefix:NSTemporaryDirectory()]) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:oldItem.URL.path]) {
      [fileManager removeItemAtURL:oldItem.URL error: nil];
    }
  } else if (oldItem) {
    NSLog(@"'%@' doesn't have prefix '%@'", oldItem.URL.path, NSTemporaryDirectory());
  }
}

-(void)playbackEnd:(NSNotification*)note
{
  if (!self.currentSegment) {
    // Loading screen.
    [self.output seekToTime:CMTimeMake(0, 1)];
    [self.output play];
    return;
  }
  NSLog(@"Finished segment. with info %@", note);
}

@end
