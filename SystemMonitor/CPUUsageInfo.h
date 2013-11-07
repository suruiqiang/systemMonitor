//
//  CPUInfo.h
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CPUUsageInfo : NSObject

+ (id)info;

- (NSArray *) cpuUsage;

@end
