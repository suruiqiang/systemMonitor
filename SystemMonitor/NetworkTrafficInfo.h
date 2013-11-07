//
//  NetworkInfo.h
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetworkTrafficInfo : NSObject

+ (id)info;

- (NSArray *) networkTraffic;

@end
