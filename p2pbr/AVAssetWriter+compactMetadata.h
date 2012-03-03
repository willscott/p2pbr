//
//  AVAssetWriter+compactMetadata.h
//  p2pbr
//
//  Created by willscott@gmail.com on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVAssetWriter (compactMetadata)

- (void) setCommonMetadata:(NSDictionary*)metadata;

@end
