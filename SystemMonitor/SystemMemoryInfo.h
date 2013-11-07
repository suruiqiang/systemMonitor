//
//  MemoryInfo.h
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SystemMemoryInfo : NSObject

+ (id)info;

- (uint64_t)totalMemory;
- (uint64_t)freeMemory;
- (uint64_t)usedMemory;
- (uint64_t)activeMemory;
- (uint64_t)inactiveMemory;
- (uint64_t)wiredMemory;
- (BOOL)print;

-(void)recycleMemory;
@end
