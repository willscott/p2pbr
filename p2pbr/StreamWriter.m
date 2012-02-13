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

#define ADTS_HEADER_LENGTH 7

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
  if (format == kAudioFormatMPEG4AAC) {
    mRecordFormat.mFormatFlags = kMPEG4Object_AAC_Main;
  }
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

static void calculateADTSHeader(char* b, UInt32 length)
{
  // From: http://wiki.multimedia.cx/index.php?title=ADTS
  b[0] = 0xff;
  b[1] = (0xf << 4) + 0x1;  //mpeg 4, no protection.
  b[2] = (0x4 << 2); // mpg4 type, frequency, private.
  b[3] = (0x1 << 6); // #channels, original, home, 2x copyright, 2xlength.
  b[4] = 0;    // length.
  b[5] = 0x1f; // vbr.
  b[6] = 0xfc; // vbr, 1 aac frame
  
  length += ADTS_HEADER_LENGTH;
  b[3] |= (length & 0x00001800) >> 11;
  b[4] |= (length & 0x000007f8) >> 3;
  b[5] |= (length & 0x00000007) << 5;
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
    for (int i = 0; i < numPkts; i++) {
      AudioStreamPacketDescription d = descriptors[i];
      NSMutableData* pkt = [[NSMutableData alloc] initWithLength:d.mDataByteSize+ADTS_HEADER_LENGTH];
      [pkt replaceBytesInRange:NSMakeRange(ADTS_HEADER_LENGTH, d.mDataByteSize) 
                     withBytes:(buffer->mAudioData + d.mStartOffset) 
                        length:(d.mDataByteSize)];
      calculateADTSHeader((void*)[pkt bytes], d.mDataByteSize);

      [writer.sink pushAudioFrame:pkt 
                         withRate:mRecordFormat.mSampleRate 
                     andFrameSize:mRecordFormat.mFramesPerPacket 
                      andChannels:mRecordFormat.mChannelsPerFrame];
     }
    
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
    OSStatus err = AudioQueueNewInput(&mRecordFormat,
                       InputBufferHandler,
                       (__bridge void*)self /* user data */,
                       NULL /* run loop */,
                       NULL /*run loop mode */,
                       0 /* flags */,
                       &mQueue);
    if (err) NSLog(@"Err adding queue input: %lu", err);

    UInt32 size = sizeof(mRecordFormat);
		AudioQueueGetProperty(mQueue,
                          kAudioQueueProperty_StreamDescription,	
                          &mRecordFormat,
                          &size);
    
		int bufferByteSize = [self ComputeRecordBufferSize:&mRecordFormat forTime:0.5];
		for (int i = 0; i < 3; ++i) {
			AudioQueueAllocateBuffer(mQueue, (bufferByteSize + ADTS_HEADER_LENGTH), &mBuffers[i]);
			AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
		}
    err = AudioQueueStart(mQueue, NULL);
    NSLog(@"Audio queue started. %lu", err);
  } else if (![self.sink isConnected] && mIsRunning) {
    mIsRunning = false;
    NSLog(@"Audio queue stopping.");
    AudioQueueStop(mQueue, true);
    AudioQueueDispose(mQueue, true);
  }
}

@end
