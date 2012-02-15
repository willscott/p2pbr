//
//  PBRNetworkManager.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"

@interface PBRNetworkManager : NSObject <AsyncSocketDelegate>

@property (strong, nonatomic) NSURL* server;
@property (strong, nonatomic) AsyncSocket* receiveSocket;
@property (strong, nonatomic) NSMutableArray* sourceHosts;
@property (strong, nonatomic) NSMutableArray* destinations;
@property (nonatomic) BOOL mode;

@property (strong,nonatomic) NSMutableData* segment;

-(id) initWithServer:(NSURL*)server;
-(void) sendData:(NSData*)data;

@end
