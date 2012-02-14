//
//  TSSocket.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TSSocket.h"
#include "avformat.h"

const NSString * TSSocketStatusDidChange = @"TSSocketStatusChanged";

@interface TSSocket()

@property (nonatomic) AVFormatContext* context;
@property (nonatomic) AVStream* audioStream;
@property BOOL headerWritten;

@end

@implementation TSSocket

@synthesize context = _context;
@synthesize audioStream = _audioStream;
@synthesize headerWritten = _headerWritten;

- (void) pushVideoFrame:(NSData*)data
{
  
}

- (void) pushAudioFrame:(NSData*)data
               fromTime:(const AudioTimeStamp*)time
               withRate:(int)rate
           andFrameSize:(int)frameSize
            andChannels:(int)channels
{
  if (self.context == Nil) {
    return;
  }
  if (!self.headerWritten) {
    // Finish Audio Stream Codec setup.
    AVCodecContext* codec = self.audioStream->codec;
    codec->codec_id = CODEC_ID_AAC;
    codec->codec_type = AVMEDIA_TYPE_AUDIO;
    codec->sample_rate = rate;
    codec->frame_size = frameSize;
    codec->channels = channels;
    if (time) {
      codec->time_base = av_d2q(time->mRateScalar, INT_MAX);
    }

    char* filename = "udp://128.208.7.74:8080";
    if(avio_open(&self.context->pb, filename, AVIO_FLAG_WRITE) < 0) {
      NSLog(@"Error Opening UDP Connection.");
      return;
    }
    avformat_write_header(self.context, NULL);
    self.headerWritten = YES;
  }
  if (!self.audioStream) {
    AVCodec* codec = avcodec_find_decoder(CODEC_ID_AAC);
    if (!codec) {
      NSLog(@"LibAV Doesn't Understand AAC.");
      return;
    }
    self.audioStream = avformat_new_stream(self.context, codec);
  }
  AVPacket pkt;
  av_init_packet(&pkt);

  pkt.data = (uint8_t*)[data bytes];
  pkt.size = [data length];
  pkt.flags |= AV_PKT_FLAG_KEY;
  pkt.stream_index = self.audioStream->index;
  pkt.dts = AV_NOPTS_VALUE;
  if (time) {
    pkt.pts = time->mHostTime;
  } else {
    pkt.pts = AV_NOPTS_VALUE;
  }
  
  if (av_interleaved_write_frame(self.context, &pkt) != 0) {
    NSLog(@"Error writing Audio Frame");
  }
}

- (BOOL) isConnected
{
  return self.context != Nil;
}

- (BOOL) connect
{
  // Don't initialize if already active.
  if (self.context != Nil) {
    return FALSE;
  }  
  av_register_all();
  avformat_network_init();

  self.context = avformat_alloc_context();
  if (!self.context) {
    NSLog(@"Memory error allocating Muxing.");
    return FALSE;
  }
  
  av_dict_set(&self.context->metadata, "title", "p2pbr", 0);
  av_dict_set(&self.context->metadata, "service_provider", "p2pbr", 0);

  AVOutputFormat* fmt = av_guess_format("mpegts", NULL, NULL);
  if (!fmt) {
    NSLog(@"Could not initialize mpeg-ts muxing");
    avformat_free_context(self.context);
    self.context = NULL;
    return FALSE;
  }

  self.context->oformat = fmt;
  char* filename = "udp://128.208.7.74:8080";
  strncpy(self.context->filename, filename, sizeof(filename));

  // Audio Input
  if (!self.audioStream) {
    self.audioStream = avformat_new_stream(self.context, NULL);
    self.audioStream->id = 1;
  }

  self.headerWritten = NO;

  [[NSNotificationCenter defaultCenter] postNotificationName:(NSString*)TSSocketStatusDidChange object:self];
  return YES;
}

- (BOOL) disconnect
{
  // Don't shut down if not up.
  if (self.context == Nil) return NO;

  av_free(self.context);
  self.context = Nil;

  [[NSNotificationCenter defaultCenter] postNotificationName:(NSString*)TSSocketStatusDidChange object:self];
  return YES;  
}

@end
