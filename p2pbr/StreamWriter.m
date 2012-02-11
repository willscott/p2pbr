//
//  StreamWriter.m
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "StreamWriter.h"

@interface StreamWriter()
@property (strong, nonatomic) id <PBRAudioSink> sink;
@property (nonatomic) AudioConverterRef converter;

- (void) socketStatus:(NSNotification *)notification;
- (void) SetupAudioFormat:(UInt32) format;
- (int) ComputeRecordBufferSize:(AudioStreamBasicDescription *)format forTime:(float) seconds;
@end

@implementation StreamWriter
@synthesize sink = _sink;
@synthesize converter = _converter;
BOOL mIsRunning;
AudioQueueRef mQueue;
AudioQueueBufferRef			mBuffers[3];
AudioStreamBasicDescription	mRecordFormat;

- (id) initWithSink:(id <PBRAudioSink>)sink
{
  self = [self init];
  if (self) {
    self.sink = sink;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketStatus:)
                                                 name:(NSString*)TSSocketStatusDidChange
                                               object:nil];

    AudioSessionInitialize(NULL, NULL, NULL, NULL);
    UInt32 category = kAudioSessionCategory_PlayAndRecord;	
		OSStatus error = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		if (error) NSLog(@"Error setting session category %lu", error);

    error = AudioSessionSetActive(YES); 
		if (error) NSLog(@"AudioSessionSetActive %lu", error);
  }
  return self;
}

- (void)dealloc
{
  AudioQueueDispose(mQueue, TRUE); 
  AudioSessionSetActive(NO);
}

- (BOOL) isRunning
{
  return mIsRunning;
}

- (void) SetupAudioFormat:(UInt32) format
{
  memset(&mRecordFormat, 0, sizeof(mRecordFormat));
  UInt32 size = sizeof(mRecordFormat.mSampleRate);
	AudioSessionGetProperty(	kAudioSessionProperty_CurrentHardwareSampleRate,
                            &size, 
                            &mRecordFormat.mSampleRate);
  
	size = sizeof(mRecordFormat.mChannelsPerFrame);
	AudioSessionGetProperty(	kAudioSessionProperty_CurrentHardwareInputNumberChannels, 
                            &size, 
                            &mRecordFormat.mChannelsPerFrame);
  
	mRecordFormat.mFormatID = format;
}

- (int) ComputeRecordBufferSize:(AudioStreamBasicDescription *)format forTime:(float) seconds
{
	int packets, frames, bytes = 0;
  frames = (int)ceil(seconds * format->mSampleRate);
		
  if (format->mBytesPerFrame > 0)
    bytes = frames * format->mBytesPerFrame;
  else {
    UInt32 maxPacketSize;
    if (format->mBytesPerPacket > 0)
      maxPacketSize = format->mBytesPerPacket;	// constant packet size
    else {
      UInt32 propertySize = sizeof(maxPacketSize);
      AudioQueueGetProperty(mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
                            &propertySize);
    }
    if (format->mFramesPerPacket > 0)
      packets = frames / format->mFramesPerPacket;
    else
      packets = frames;	// worst-case scenario: 1 frame in a packet
    if (packets == 0)		// sanity check
      packets = 1;
    bytes = packets * maxPacketSize;
  }
	return bytes;
}


static void InputBufferHandler(void* userData,
                               AudioQueueRef AQ,
                               AudioQueueBufferRef buffer,
                               const AudioTimeStamp* startTime,
                               UInt32 numPkts,
                               const AudioStreamPacketDescription* descriptors)
{
  StreamWriter* writer = (__bridge StreamWriter*)userData;
  
  if (numPkts > 0) {
    //Parse Packets
    NSLog(@"Received %lu packets.", numPkts);
    
    [writer.sink pushAudioFrame:buffer 
                       withRate:mRecordFormat.mSampleRate 
                   andFrameSize:mRecordFormat.mFramesPerPacket 
                    andChannels:mRecordFormat.mChannelsPerFrame];
    
    if ([writer isRunning]) {
      AudioQueueEnqueueBuffer(AQ, buffer, 0, NULL);
    }
  }
}

- (void) socketStatus:(NSNotification *)notification
{
  if ([self.sink isConnected] && !mIsRunning) {
    mIsRunning = true;
    [self SetupAudioFormat:kAudioFormatMPEG4AAC];
    AudioQueueNewInput(&mRecordFormat,
                       InputBufferHandler,
                       (__bridge void*)self /* user data */,
                       NULL /* run loop */,
                       NULL /*run loop mode */,
                       0 /* flags */,
                       &mQueue);

    UInt32 size = sizeof(mRecordFormat);
		AudioQueueGetProperty(mQueue,
                          kAudioQueueProperty_StreamDescription,	
                          &mRecordFormat,
                          &size);
    
		int bufferByteSize = [self ComputeRecordBufferSize:&mRecordFormat forTime:0.5];
		for (int i = 0; i < 3; ++i) {
			AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]);
			AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
		}
    OSStatus err = AudioQueueStart(mQueue, NULL);
    NSLog(@"Audio queue started. %lu", err);
  } else if (![self.sink isConnected] && mIsRunning) {
    mIsRunning = false;
    NSLog(@"Audio queue stopping.");
    AudioQueueStop(mQueue, true);
    AudioQueueDispose(mQueue, true);
  }
}

/*
static OSStatus EncoderDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
  AudioBufferList* inputStructure = (AudioBufferList*)inUserData;
  ioData->mBuffers[0].mData = inputStructure->mBuffers[0].mData;
  ioData->mBuffers[0].mDataByteSize = inputStructure->mBuffers[0].mDataByteSize;
  ioData->mBuffers[0].mNumberChannels = inputStructure->mBuffers[0].mNumberChannels;

  inputStructure->mBuffers[0].mDataByteSize = 0;
  
  return 0;
}
*/

/*
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
  if (![self.sink isConnected]) {
    return;
  }
  NSLog(@"Handling Sample Buffer.");

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
    AudioStreamPacketDescription outputPacketDescription;
    AudioConverterFillComplexBuffer(self.converter, EncoderDataProc, &inputStructure, &numPackets, &outputStructure, &outputPacketDescription);
    
    if (numPackets > 0) {
      UInt32 outBytes = outputStructure.mBuffers[0].mDataByteSize;
      [self.sink pushAudioFrame:[data subdataWithRange:NSMakeRange(0, outBytes)] atOffset:outputPacketDescription.mStartOffset];
    } else {
      NSLog(@"Audio converter returned EOF");
    }
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
*/

@end
