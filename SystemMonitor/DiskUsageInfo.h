//
//  DiskUsageInfo.h
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DiskUsageInfo : NSObject
{
    int index;
}
@property(nonatomic,assign)BOOL paused;

+ (id)info;
- (uint64_t)freeDiskspace;

-(void)startEatingDisk:(id)sender;
@end
