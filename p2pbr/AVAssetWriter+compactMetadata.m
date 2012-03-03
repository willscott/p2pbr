//
//  AVAssetWriter+compactMetadata.m
//  p2pbr
//
//  Created by willscott@gmail.com on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AVAssetWriter+compactMetadata.h"

@implementation AVAssetWriter (compactMetadata)

- (void) setCommonMetadata:(NSDictionary*)metadata
{
  NSMutableArray* dest = [NSMutableArray arrayWithArray:self.metadata];
  for (NSString* key in metadata) {
    AVMutableMetadataItem* item = [AVMutableMetadataItem metadataItem];
    item.keySpace = AVMetadataKeySpaceCommon;
    item.key = key;
    item.value = [metadata objectForKey:key];
    [dest addObject:item];
  }
  self.metadata = dest;
}

@end
