//
//  PBRNetworkManager.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

@interface PBRNetworkManager : NSObject <GCDAsyncSocketDelegate>

@property (strong, nonatomic) NSURL* server;
@property (strong, nonatomic) GCDAsyncSocket* receiveSocket;
@property (strong, nonatomic) NSMutableArray* sourceHosts;
@property (strong, nonatomic) NSMutableArray* destinations;
@property (nonatomic) BOOL mode;

@property (strong,nonatomic) NSMutableData* segment;

-(id) initWithServer:(NSURL*)server;
-(void) connectTo:(NSString*)host onPort:(NSInteger)port;
-(void) sendData:(NSData*)data andThen:(void (^)(BOOL success))block;
-(NSString*)receiveAddress;

@end
