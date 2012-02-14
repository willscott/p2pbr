//
//  PBRAVPacketizer.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRAVPacketizer.h"

@interface PBRAVPacketizer()

@property (strong,nonatomic) AVCaptureMovieFileOutput* source;

-(NSURL*) getTemporaryFile;

@end

@implementation PBRAVPacketizer

@synthesize active = _active;
@synthesize socket = _socket;

@synthesize source = _source;

-(void) recordFrom:(AVCaptureMovieFileOutput*)output
{
  self.source = output;
}

-(void) setActive:(BOOL)active
{
  if (active && !_active) { //Start.
    [self.source startRecordingToOutputFileURL:[self getTemporaryFile] recordingDelegate:self];
  }
  _active = active;
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

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL 
      fromConnections:(NSArray *)connections 
                error:(NSError *)error
{
  if (error && [error code] != -11810) {
    // Stop on errors except for 'maximum length reached.'
    NSLog(@"Error with output: %@", error);
    return;
  }
  if (self.active) {
    [self.source startRecordingToOutputFileURL:[self getTemporaryFile] recordingDelegate:self];
  }
  
  NSData* recordedData = [NSData dataWithContentsOfURL:outputFileURL];

  [self.socket sendData:recordedData];

  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:[outputFileURL path]]) {
    [fileManager removeItemAtURL:outputFileURL error: nil];
  }
}

@end