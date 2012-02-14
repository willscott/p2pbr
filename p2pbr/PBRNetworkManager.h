//
//  PBRNetworkManager.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncUdpSocket.h"

@interface PBRNetworkManager : NSObject <AsyncUdpSocketDelegate>

@property (strong, nonatomic) NSURL* server;
@property (strong, nonatomic) NSMutableArray* sources;
@property (strong, nonatomic) NSMutableArray* destinations;

-(id) initWithServer:(NSURL*)server;
-(void) sendData:(NSData*)data;

@end
