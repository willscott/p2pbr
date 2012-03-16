//
//  PBRControlPacket.m
//  p2pbr
//
//  Created by willscott@gmail.com on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRControlPacket.h"

@implementation PBRControlPacket
@synthesize length = _length;
@synthesize stamp = _stamp;

static char* noncestr = "p2pbr!";

+ (NSUInteger) packetLength
{
  return strlen(noncestr) + sizeof(NSUInteger) + sizeof(NSTimeInterval);
}

- (id)initWithPayload:(NSData*)data
{
  self = [self init];
  if (self) {
    self.length = [data length];
    self.stamp = [NSDate date];
  }
  return self;
}

- (id)initFromWire:(NSData *)data
{
  self = [self init];
  if (self) {
    if ([data length] == [PBRControlPacket packetLength]) {
      if (strncmp(noncestr, [data bytes], strlen(noncestr)) == 0)
      {
        NSUInteger len;
        bcopy([data bytes] + strlen(noncestr), &len, sizeof(len));
        self.length = len;
        NSTimeInterval time;
        bcopy([data bytes] + strlen(noncestr) + sizeof(len), &time, sizeof(time));
        self.stamp = [NSDate dateWithTimeIntervalSince1970:time];
      }
    }
  }
  return self;
}

- (NSData*) data
{
  /* header looks like:
   * ["p2pbr", [payload length], [t-stamp]]
   */
  NSData* nonce = [NSData dataWithBytesNoCopy:noncestr length:strlen(noncestr) freeWhenDone:NO];
  NSMutableData* payload = [NSMutableData dataWithData:nonce];
  NSUInteger length = self.length;
  [payload appendBytes:(void*)&length length:sizeof(NSUInteger)];
  NSTimeInterval seconds = [self.stamp timeIntervalSince1970];
  [payload appendBytes:&seconds length:sizeof(NSTimeInterval)];
  return payload;
}



@end
