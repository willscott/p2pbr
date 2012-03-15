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


// We have mediaOutput0 (with video/audioInputs0) and 1
// One gets ready to receive data while the other one is receiving dataa
// When we're finished with the currently working one, it is asynchronously told
// to finishWriting and we start sending data to the other one.
@property (strong, nonatomic) AVAssetWriterInput* videoInputActive;
@property (strong, nonatomic) AVAssetWriterInput* audioInputActive;
@property (strong, nonatomic) AVAssetWriter* mediaOutputActive;
@property (strong, nonatomic) AVAssetWriterInput* videoInputNext;
@property (strong, nonatomic) AVAssetWriterInput* audioInputNext;
@property (strong, nonatomic) AVAssetWriter* mediaOutputNext;

@property (strong, nonatomic) NSDate* segmentStart;

-(NSURL*) getTemporaryFile;

- (void) handleVideoSample:(CMSampleBufferRef)sampleBuffer;
- (void) handleAudioSample:(CMSampleBufferRef)sampleBuffer;
- (void) finishWritingFileAndSendAndClean:(AVAssetWriter*)writer;
-(AVAssetWriter*) createNewAVAssetWriter;
@end

@implementation PBRAVPacketizer

// mediaOutputs and their a/vInput
@synthesize videoInputActive = _videoInputActive;
@synthesize audioInputActive = _audioInputActive;
@synthesize mediaOutputActive = _mediaOutputActive;
@synthesize videoInputNext = _videoInputNext;
@synthesize audioInputNext = _audioInputNext;
@synthesize mediaOutputNext = _mediaOutputNext;

@synthesize segmentStart = _segmentStart;

@synthesize active = _active;
@synthesize socket = _socket;

#define SEGMENT_LENGTH 0.5

-(void) recordAudio:(AVCaptureAudioDataOutput*)audio andVideo:(AVCaptureVideoDataOutput*)video
{
  dispatch_queue_t queue = dispatch_queue_create("MediaProcessQueue", NULL);

  
  [video setSampleBufferDelegate:self queue:queue];
  [audio setSampleBufferDelegate:self queue:queue];
  dispatch_release(queue);
  

  if (!audio || !video) {
    self.videoInputActive = nil;
    self.audioInputActive = nil;
    self.videoInputNext = nil;
    self.audioInputNext = nil;
    return;
  }

  // AssetWriter flow is coherently described at
  // http://stackoverflow.com/questions/4149963/this-code-to-write-videoaudio-through-avassetwriter-and-avassetwriterinputs-is

  NSDictionary* videoOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                        AVVideoCodecH264, AVVideoCodecKey,
                                        [NSNumber numberWithInt:640], AVVideoWidthKey,
                                        [NSNumber numberWithInt:480], AVVideoHeightKey,
                                        nil];
  AVAssetWriterInput* videoInputActive = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo 
                                                                      outputSettings:videoOutputSettings];
  AVAssetWriterInput* videoInputNext = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo 
                                                                            outputSettings:videoOutputSettings];
  videoInputActive.expectsMediaDataInRealTime = YES;
  videoInputNext.expectsMediaDataInRealTime = YES;

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
  AVAssetWriterInput* audioInputActive = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio 
                                                                      outputSettings:audioOutputSettings];
  AVAssetWriterInput* audioInputNext = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio 
                                                                      outputSettings:audioOutputSettings];
  audioInputActive.expectsMediaDataInRealTime = YES;
  audioInputNext.expectsMediaDataInRealTime = YES;
  
  self.videoInputActive = videoInputActive;
  self.audioInputActive = audioInputActive;
  self.videoInputNext = videoInputNext;
  self.audioInputNext = audioInputNext;
  
  self.mediaOutputActive = [self createNewAVAssetWriter];
  self.mediaOutputNext = [self createNewAVAssetWriter];
  
  [self.mediaOutputActive addInput:self.videoInputActive];
  [self.mediaOutputActive addInput:self.audioInputActive];
  [self.mediaOutputNext addInput:self.videoInputNext];
  [self.mediaOutputNext addInput:self.audioInputNext];
  
  [self.mediaOutputActive startWriting];
  [self.mediaOutputNext startWriting];
  
  /** This determines that an empty data is 207 bytes
  AVAssetWriter* test = [self createNewAVAssetWriter];
  [test startWriting];
  [test startSessionAtSourceTime:CMTimeMakeWithSeconds(0, 1)];
  [test finishWriting];
  NSData* testData = [NSData dataWithContentsOfURL:test.outputURL];
  NSLog(@"%d", [testData length]);
   */

  
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
    AVAssetWriter* finished = self.mediaOutputActive;
    if (self.mediaOutputNext == nil) {
      NSLog(@"Next media output not ready by the time previous one finished.");
      return;
    }
    if (self.mediaOutputNext.status != AVAssetWriterStatusWriting) {
      NSLog(@"Warning: switching to next writer with status %d", self.mediaOutputNext.status);
      return;
    }
    // NSLog(@"finished with writer %p in status %d, switching to next writer %p with status %d", finished, finished.status, self.mediaOutputNext, self.mediaOutputNext.status);
    self.mediaOutputActive = self.mediaOutputNext;
    self.videoInputActive = self.videoInputNext;
    self.audioInputActive = self.audioInputNext;
    self.mediaOutputNext = nil;   // by the time we get around to the next segment, this should have been
                                  // created anew asynchronously by the following call
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [self finishWritingFileAndSendAndClean:finished];
    });

    self.segmentStart = nil;
  }

  if (self.active) {
    // Start first segment of new series of recordings.
    if (!self.segmentStart) {
      self.segmentStart = [NSDate date];
      if (self.mediaOutputActive.status != AVAssetWriterStatusWriting) {
        [self.mediaOutputActive startWriting];
        //NSLog(@"called startWriting");

//        NSLog(@"Warning: active writer status is %d", self.mediaOutputActive.status);
//        return;
      }
      CMTime tstamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
      [self.mediaOutputActive startSessionAtSourceTime:tstamp];
      //NSLog(@"started session with timestamp %f on output %@", CMTimeGetSeconds(tstamp), self.mediaOutputActive);
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
      NSLog(@"Skipping premature buffer.");
      return;
    }
     
    //video
    if ([captureOutput isKindOfClass:[AVCaptureVideoDataOutput class]]) {
      [self handleVideoSample:sampleBuffer];
    } 
    //audio
    else if([captureOutput isKindOfClass:[AVCaptureAudioDataOutput class]]) {
      [self handleAudioSample:sampleBuffer];      
    }

  
  }
}

- (void) handleVideoSample:(CMSampleBufferRef)sampleBuffer
{
  if(![self.videoInputActive appendSampleBuffer:sampleBuffer]) {
    NSLog(@"Unable to add video sample.");
  }
}

- (void) handleAudioSample:(CMSampleBufferRef)sampleBuffer
{
  if(![self.audioInputActive appendSampleBuffer:sampleBuffer]) {
    NSLog(@"Unable to add audio sample.");
  }
}


- (void) finishWritingFileAndSendAndClean:(AVAssetWriter*)writer
{
  // **********
  // old writer: finish writing
  // send out old data
  // clean up old data's file
  // 
  // new writer: create
  // new writer: configure
  // new writer: add old writer's inputs
  // new writer: set as next
  // self.inputNexts: set as new writer's inputs
  // new writer: start writing
  // **********
  
  if (![writer finishWriting]) {
    NSLog(@"Unable to finish writing segment output. Status: %d, Error: %@", writer.status, writer.error);
    return;
  }
  
  NSData* recordedData = [NSData dataWithContentsOfURL:writer.outputURL];
  [self.socket sendData:recordedData andThen:^(BOOL success) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:[writer.outputURL path]]) {
      [fileManager removeItemAtURL:writer.outputURL error: nil];
    }
  }];

  AVAssetWriter* newWriter = [self createNewAVAssetWriter];
 
  // Add old writer's inputs on new writer, and
  // set old writer's inputs as next inputs
  for (AVAssetWriterInput* input in writer.inputs) {
    [newWriter addInput:input];
    if ([input.mediaType isEqualToString:AVMediaTypeVideo]) {
      self.videoInputNext = input;
    }
    else if ([input.mediaType isEqualToString:AVMediaTypeAudio]) {
      self.audioInputNext = input;
    }
    else {
      NSLog(@"Old writer had inputs not of type Audio or Video");
    }
  }
  [newWriter startWriting];
  
  self.mediaOutputNext = newWriter;
  
  if (self.mediaOutputNext.status != AVAssetWriterStatusWriting) {
    NSLog(@"Warning: next writer status is %d", self.mediaOutputNext.status);
    return;
  }
}

- (AVAssetWriter*) createNewAVAssetWriter {
  NSError *err = nil;
  AVAssetWriter* newWriter = [[AVAssetWriter alloc] initWithURL:[self getTemporaryFile]
                                                    fileType:AVFileTypeMPEG4                    
                                                    error:&err];
  //Metadata
  [newWriter setCommonMetadata:[NSDictionary dictionaryWithObjectsAndKeys:
                                @"p2pbr", AVMetadataCommonKeyTitle,
                                @"p2pbr", AVMetadataCommonKeyPublisher,
                                @"iOS p2pbr", AVMetadataCommonKeySoftware,
                                nil]];
  return newWriter;
}

@end
