//
//  StreamWriter.m
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "StreamWriter.h"

#include <AudioToolbox/AudioToolbox.h>

@interface StreamWriter()
@property (strong, nonatomic) NSURL* destination;
@property (strong, nonatomic) GCDAsyncSocket* socket;
@property (strong, nonatomic) NSError* lastError;
@property (strong, nonatomic) NSNumber* tag;

@property (nonatomic) AudioConverterRef converter;
@property (nonatomic) AudioStreamBasicDescription* sourceAudioFormat;
@end

@implementation StreamWriter
#define AUDIO_BUFFER_SIZE 32768

@synthesize destinationAudioFormat = _destinationAudioFormat;
@synthesize sourceAudioFormat = _sourceAudioFormat;

@synthesize destination = _destination;
@synthesize socket = _socket;
@synthesize lastError = _lastError;
@synthesize tag = _tag;
@synthesize converter = _converter;

- (id)initWithDestination:(NSURL *)dest
{
  self = [self init];
  if (self) {
    self.tag = [[NSNumber alloc] initWithLong:0];
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                             delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    self.destination = dest;
  }
  return self;
}


static OSStatus EncoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
  AudioBufferList* inputStructure = (AudioBufferList*)inUserData;
  ioData->mBuffers[0].mData = inputStructure->mBuffers[0].mData;
  ioData->mBuffers[0].mDataByteSize = inputStructure->mBuffers[0].mDataByteSize;
  ioData->mBuffers[0].mNumberChannels = inputStructure->mBuffers[0].mNumberChannels;

  inputStructure->mBuffers[0].mDataByteSize = 0;
  
  return 0;
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  if (![self.socket isConnected]) {
    return;
  }
  if (!self.sourceAudioFormat) {
    AVCaptureInputPort *source = (AVCaptureInputPort*)[[connection inputPorts] objectAtIndex:0];
    CMAudioFormatDescriptionRef fmt = (CMAudioFormatDescriptionRef)[source formatDescription];
    self.sourceAudioFormat = (AudioStreamBasicDescription *)CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
  }

  //NSLog(@"Format is %ld", inFormat->mFormatID);
  
  CMBlockBufferRef dataRef = CMSampleBufferGetDataBuffer(sampleBuffer);
  size_t length = CMBlockBufferGetDataLength(dataRef);
  if (length) {
    size_t now_length = 0;
    char* pointer;
    CMBlockBufferGetDataPointer(dataRef, 0, nil, &now_length, &pointer);
    if (now_length < length) {
      NSLog(@"data lost %luld < %lud", now_length, length);
    }
    AudioBufferList inputStructure;
    inputStructure.mBuffers[0].mDataByteSize = now_length;
    inputStructure.mBuffers[0].mData = pointer;
    inputStructure.mBuffers[0].mNumberChannels = self.sourceAudioFormat->mChannelsPerFrame;

    NSMutableData* data = [[NSMutableData alloc] initWithLength:AUDIO_BUFFER_SIZE];
    void* outputBuffer = (void*)[data bytes];
    
    AudioBufferList outputStructure;
    outputStructure.mNumberBuffers = 1;
    outputStructure.mBuffers[0].mNumberChannels = self.destinationAudioFormat.mChannelsPerFrame;
    outputStructure.mBuffers[0].mDataByteSize = AUDIO_BUFFER_SIZE;
    outputStructure.mBuffers[0].mData = outputBuffer;
    
    UInt32 numPackets = 1;
    AudioStreamPacketDescription *outputPacketDescriptions = NULL;
    AudioConverterFillComplexBuffer(self.converter, EncoderDataProc, &inputStructure, &numPackets, &outputStructure, outputPacketDescriptions);
    
    if (numPackets > 0) {
      UInt32 outBytes = outputStructure.mBuffers[0].mDataByteSize;
      [self.socket writeData:[data subdataWithRange:NSMakeRange(0, outBytes)] withTimeout:1000.0 tag:[self.tag longValue]];      
    } else {
      NSLog(@"Audio converter returned EOF");
      [self disconnect];
    }

  }
}

- (NSNumber*) tag
{
  return [[NSNumber alloc] initWithLong:[_tag longValue] + 1];
}

- (void) connect
{
  NSString* host = [self.destination host];
  uint16_t port = [[self.destination port] intValue];
  
  NSError* err = nil;
  [self.socket connectToHost:host onPort:port withTimeout:1000.0 error:&err];
  if (err) {
    NSLog(@"Error connecting: %@", err);
  }
}

- (AudioConverterRef) converter
{
  if (!_converter) {
    AudioStreamBasicDescription src = *self.sourceAudioFormat;
    AudioStreamBasicDescription dest = self.destinationAudioFormat;
    AudioConverterNew(&src, &dest, &_converter);
  }
  return _converter;
}

- (AudioStreamBasicDescription) destinationAudioFormat
{
  // TODO(willscott): May want to dynamically adapt audio codec, not just Low def.
  if (_destinationAudioFormat.mFormatID == 0) {
    _destinationAudioFormat.mFormatID = kAudioFormatMPEG4AAC_LD;
    _destinationAudioFormat.mChannelsPerFrame = self.sourceAudioFormat->mChannelsPerFrame;

    // Fill out the rest of the description from the source.
    UInt32 size = sizeof(_destinationAudioFormat);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 
                           0,
                           NULL,
                           &size, 
                           &_destinationAudioFormat);
  }
  return _destinationAudioFormat;
}

- (void) disconnect
{
  [self.socket disconnectAfterWriting];
}

@end
