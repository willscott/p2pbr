//
//  PBRAVPacketizer.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRAVPacketizer.h"
#import "AVAssetWriter+compactMetadata.h"

@interface PBRAVPacketizer()

@property (strong, nonatomic) AVAssetWriterInput* videoInput;
@property (strong, nonatomic) AVAssetWriterInput* audioInput;
@property (strong, nonatomic) AVAssetWriter* mediaOutput;
@property (strong, nonatomic) NSDate* segmentStart;

-(NSURL*) getTemporaryFile;

- (void) handleVideoSample:(CMSampleBufferRef)sampleBuffer;
- (void) handleAudioSample:(CMSampleBufferRef)sampleBuffer;
- (void) sendFileAndClean:(NSURL*)file;
@end

@implementation PBRAVPacketizer

@synthesize videoInput = _videoInput;
@synthesize audioInput = _audioInput;
@synthesize mediaOutput = _mediaOutput;
@synthesize segmentStart = _segmentStart;

@synthesize active = _active;
@synthesize socket = _socket;

#define SEGMENT_LENGTH 1

-(void) recordAudio:(AVCaptureAudioDataOutput*)audio andVideo:(AVCaptureVideoDataOutput*)video
{
  dispatch_queue_t queue = dispatch_queue_create("MediaProcessQueue", NULL);

  
  [video setSampleBufferDelegate:self queue:queue];
  [audio setSampleBufferDelegate:self queue:queue];
  dispatch_release(queue);
  

  if (!audio || !video) {
    self.videoInput = nil;
    self.audioInput = nil;
    return;
  }

  // AssetWriter flow is coherently described at
  // http://stackoverflow.com/questions/4149963/this-code-to-write-videoaudio-through-avassetwriter-and-avassetwriterinputs-is

  NSDictionary* videoOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        AVVideoCodecH264, AVVideoCodecKey,
                                        [NSNumber numberWithInt:640], AVVideoWidthKey,
                                        [NSNumber numberWithInt:480], AVVideoHeightKey,
                                        nil];
  AVAssetWriterInput* videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo 
                                                                      outputSettings:videoOutputSettings];
  videoInput.expectsMediaDataInRealTime = YES;

  AudioChannelLayout cl;
  bzero(&cl, sizeof(cl));
  cl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;

  NSDictionary* audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                       [NSNumber numberWithInt: 1],                    AVNumberOfChannelsKey,
                                       [NSNumber numberWithFloat: 44100.0],            AVSampleRateKey,
                                       [NSNumber numberWithInt: 64000],                AVEncoderBitRateKey,
                                       [NSData dataWithBytes: &cl length:sizeof(cl)],  AVChannelLayoutKey,
                                       nil];
  AVAssetWriterInput* audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio 
                                                                      outputSettings:audioOutputSettings];
  audioInput.expectsMediaDataInRealTime = YES;
  
  self.videoInput = videoInput;
  self.audioInput = audioInput;
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
  // Finish Active segment.
  if (self.segmentStart && [[NSDate date] timeIntervalSinceDate:self.segmentStart] > SEGMENT_LENGTH) {
    if (![self.mediaOutput finishWriting]) {
      NSLog(@"Unable to finish writing segment output.");
      return;
    }
    self.segmentStart = nil;

    [self performSelectorInBackground:@selector(sendFileAndClean:) withObject:self.mediaOutput.outputURL];
    self.mediaOutput = nil;
  }

  if (self.active) {
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
      NSLog(@"Skipping premature buffer.");
      return;
    }
    
    // Start new segment.
    if (!self.mediaOutput) {
      self.segmentStart = [NSDate date];
      NSError *err = nil;
      self.mediaOutput = [[AVAssetWriter alloc] initWithURL:[self getTemporaryFile]
                                                   fileType:AVFileTypeMPEG4 
                                                      error:&err];
      [self.mediaOutput addInput:self.videoInput];
      [self.mediaOutput addInput:self.audioInput];

      //Metadata
      [self.mediaOutput setCommonMetadata:[NSDictionary dictionaryWithObjectsAndKeys:
                                           @"p2pbr", AVMetadataCommonKeyTitle,
                                           @"p2pbr", AVMetadataCommonKeyPublisher,
                                           @"iOS p2pbr", AVMetadataCommonKeySoftware,
                                           nil]];

      [self.mediaOutput startWriting];
      CMTime tstamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
      [self.mediaOutput startSessionAtSourceTime:tstamp];
    }
    
    if (self.mediaOutput.status > AVAssetWriterStatusWriting) {
      NSLog(@"Warning: writer status is %d", self.mediaOutput.status);
      return;
    }

    if ([captureOutput isKindOfClass:[AVCaptureVideoDataOutput class]]) {
      [self handleVideoSample:sampleBuffer];
    } else if([captureOutput isKindOfClass:[AVCaptureAudioDataOutput class]]) {
      [self handleAudioSample:sampleBuffer];      
    }
  }
}

- (void) handleVideoSample:(CMSampleBufferRef)sampleBuffer
{
  if(![self.videoInput appendSampleBuffer:sampleBuffer]) {
    NSLog(@"Unable to add video sample.");
  }
}

- (void) handleAudioSample:(CMSampleBufferRef)sampleBuffer
{
  if(![self.audioInput appendSampleBuffer:sampleBuffer]) {
    NSLog(@"Unable to add audio sample.");
  }
}

- (void) sendFileAndClean:(NSURL*)file
{
  NSData* recordedData = [NSData dataWithContentsOfURL:file];
  
  [self.socket sendData:recordedData andThen:^(BOOL success) {
    NSLog(@"Cleaned up after sending segment.");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[file path]]) {
      [fileManager removeItemAtURL:file error: nil];
    }
  }];

}

@end