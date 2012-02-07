//
//  TSSocket.m
//  p2pbr
//
//  Created by willscott@gmail.com on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TSSocket.h"

#include "avformat.h"

@interface TSSocket()

@property (nonatomic) AVFormatContext* context;
@property (nonatomic) AVStream* audioStream;

@end

@implementation TSSocket

@synthesize context = _context;
@synthesize audioStream = _audioStream;

- (void) pushVideoFrame:(NSData*)data
{
  
}

- (void) pushAudioFrame:(NSData*)data atOffset:(uint64_t)offset
{
  if (self.context == Nil) {
    return;
  }
  if (!self.audioStream) {
    AVCodec codec = *avcodec_find_decoder(CODEC_ID_AAC);
    self.audioStream = avformat_new_stream(self.context, &codec);
  }
  AVPacket pkt;
  av_init_packet(&pkt);

  pkt.data = (uint8_t *)[data bytes];
  pkt.size = [data length];
  pkt.flags |= AV_PKT_FLAG_KEY;
  pkt.stream_index = self.audioStream->index;
  pkt.dts = AV_NOPTS_VALUE;
  pkt.pts = offset;
  
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

  self.context = avformat_alloc_context();
  if (!self.context) {
    NSLog(@"Memory error allocating Muxing.");
    return FALSE;
  }
  AVOutputFormat* fmt = av_guess_format("mpegts", NULL, NULL);
  if (!fmt) {
    NSLog(@"Could not initialize mpeg-ts muxing");
    avformat_free_context(self.context);
    self.context = NULL;
    return FALSE;
  }

  self.context->oformat = fmt;
  char* filename = "udp://128.208.7.205:8080";
  strncpy(self.context->filename, filename, sizeof(filename));

  avformat_write_header(self.context, NULL);  

  return YES;
}

- (BOOL) disconnect
{
  // Don't shut down if not up.
  if (self.context == Nil) return NO;

  av_free(self.context);
  self.context = Nil;
  return YES;  
}

@end
