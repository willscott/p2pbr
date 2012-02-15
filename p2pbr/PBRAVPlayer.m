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

-(void)onFile:(NSNotification*)note;
-(NSURL*) getTemporaryFile;

@end

@implementation PBRAVPlayer

@synthesize socket = _socket;

@synthesize output = _output;

-(void)playTo:(MPMoviePlayerController*)dest
{
  self.output = dest;
}

-(void) setSocket:(PBRNetworkManager *)socket
{
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
  NSURL* tempUrl = [self getTemporaryFile];
  [[self.socket segment] writeToURL:tempUrl atomically:NO];
  [self.output setContentURL:tempUrl];
  [self.output play];
}

@end
