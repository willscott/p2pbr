//
//  PBRAVPlayer.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRAVPlayer.h"

@interface PBRAVPlayer()

@property (weak, nonatomic) MPMoviePlayerController* output;
@property (strong, nonatomic) NSURL* currentSegment;

-(void)onFile:(NSNotification*)note;
-(void)moviePlayerLoadStateChanged:(NSNotification*)note;
-(void)moviePlayBackDidFinish:(NSNotification*)note;
-(NSURL*) getTemporaryFile;

@end

@implementation PBRAVPlayer

@synthesize socket = _socket;

@synthesize output = _output;
@synthesize currentSegment = _currentSegment;

BOOL pending = NO;

-(void)playTo:(MPMoviePlayerController*)dest
{
  if (self.output)
  {
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:MPMoviePlayerLoadStateDidChangeNotification 
                                                  object:self.output];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:MPMoviePlayerPlaybackDidFinishNotification 
                                                  object:self.output];
  }
  self.output = dest;
  [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(moviePlayerLoadStateChanged:) 
                                               name:MPMoviePlayerLoadStateDidChangeNotification 
                                             object:dest];
  [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(moviePlayBackDidFinish:) 
                                               name:MPMoviePlayerPlaybackDidFinishNotification 
                                             object:dest];
}

-(void) setSocket:(PBRNetworkManager *)socket
{
  if (_socket) {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PBRSegmentReady" object:_socket];
  }
  _socket = socket;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFile:) name:@"PBRSegmentReady" object:socket];
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

-(void)onFile:(NSNotification*)note
{
  if (self.currentSegment == nil)
  {
    self.currentSegment = [self getTemporaryFile];
    [[self.socket segment] writeToURL:self.currentSegment atomically:NO];
    [self.output setContentURL:self.currentSegment];
    [self.output prepareToPlay];
  } else {
    pending = true;
  }
}

-(void)moviePlayerLoadStateChanged:(NSNotification*)note
{
  [self.output play];
}

-(void)moviePlayBackDidFinish:(NSNotification*)note
{
  NSLog(@"Finished segment.");

  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:[self.currentSegment path]]) {
    [fileManager removeItemAtURL:self.currentSegment error: nil];
  }
  self.currentSegment = nil;
  
  if (pending) {
    pending = NO;
    [self onFile:nil];
  }
}

@end
