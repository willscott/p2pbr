//
//  PBRControlPacket.h
//  p2pbr
//
//  Created by willscott@gmail.com on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PBRControlPacket : NSObject

+ (NSUInteger)packetLength;

@property NSUInteger length;
@property (strong, nonatomic) NSDate* stamp;

- (id)initWithPayload:(NSData*)data;
- (id)initFromWire:(NSData*)data;
- (NSData*) data;

@end
