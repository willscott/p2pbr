//
//  PBRAVPacketizer.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRAVPacketizer.h"

@interface PBRAVPacketizer()

-(NSURL*) getTemporaryFile;

@end

@implementation PBRAVPacketizer

@synthesize active = _active;
@synthesize socket = _socket;

-(void) recordAudio:(AVCaptureAudioDataOutput*)audio andVideo:(AVCaptureVideoDataOutput*)video
{
  dispatch_queue_t queue = dispatch_queue_create("MediaProcessQueue", NULL);

  [video setSampleBufferDelegate:self queue:queue];
  [audio setSampleBufferDelegate:self queue:queue];
  
  dispatch_release(queue);
}

-(void) setActive:(BOOL)active
{
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  if (self.active) {
    NSLog(@".");
  }
}

/*
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

  [self.source startRecordingToOutputFileURL:[self getTemporaryFile] recordingDelegate:self];

  NSArray* mdarray = ((AVCaptureMovieFileOutput*)captureOutput).metadata;
  for (AVMetadataItem* md in mdarray) {
    NSLog(@"time: %f, duration: %f", CMTimeGetSeconds(md.time), CMTimeGetSeconds(md.duration));
  }
  
  NSData* recordedData = [NSData dataWithContentsOfURL:outputFileURL];

  [self.socket sendData:recordedData andThen:^(BOOL success) {
    NSLog(@"Cleaned up after sending segment.");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[outputFileURL path]]) {
      [fileManager removeItemAtURL:outputFileURL error: nil];
    }
  }];
}
*/

@end