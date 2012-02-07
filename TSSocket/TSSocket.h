//
//  TSSocket.h
//  p2pbr
//
//  Created by willscott@gmail.com on 2/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TSSocketDelegate;

@interface TSSocket : NSObject

- (id) initWithDelegate:(id <TSSocketDelegate>) delegate;

- (void) pushAudioFrame:(NSData*)data tag:(long)tag;
- (void) pushVideoFrame:(NSData*)data tag:(long)tag;


@end

@interface TSSocket (AsyncSocket)

- (BOOL) connectToHost:(NSString *)host onPort:(UInt16)port error:(NSError **)errPtr;
- (BOOL) isConnected;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol TSSocketDelegate
@optional

/**
 * Called when the AV frame with the given tag has been sent.
 **/
- (void)onTSSocket:(TSSocket *)sock didSendFrameWithTag:(long)tag;

/**
 * Called if an error occurs while trying to send a frame.
 * This could be due to a timeout, or something more serious such as the data being too large to fit in a sigle packet.
 **/
- (void)onTSSocket:(TSSocket *)sock didNotSendFrameWithTag:(long)tag dueToError:(NSError *)error;

/**
 * Called when the socket has received a frame.
 * 
 * If you ever need to ignore a received packet, simply return NO,
 * and TSSocket will continue as if the packet never arrived.
 * 
 * Under normal circumstances, you simply return YES from this method.
 **/
- (BOOL)onTSSocket:(TSSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port;

/**
 * Called if an error occurs while trying to receive a requested frame.
 * This is generally due to a timeout, but could potentially be something else if some kind of OS error occurred.
 **/
- (void)onTSSocket:(TSSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error;

/**
 * Called when the socket is closed.
 * A socket is only closed if you explicitly call one of the close methods.
 **/
- (void)onTSSocketDidClose:(TSSocket *)sock;

@end