//
//  DiskUsageInfo.m
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import "DiskUsageInfo.h"

@implementation DiskUsageInfo


+ (id)info
{
    static dispatch_once_t onceToken;
    static DiskUsageInfo *systemMemoryInfo;
    dispatch_once(&onceToken, ^{
        systemMemoryInfo = [[self alloc] init];
    });
    return systemMemoryInfo;
}


-(void)startEatingDisk:(id)sender
{
    self.paused = false;
    [self removeAll];
    [self eatDisk];
}

-(void)eatDisk
{
    //[self freeDiskspace];
    index+=1;
    NSMutableData *data = [[NSMutableData alloc] initWithLength:10*1024*1024];
    NSString* file = [NSString stringWithFormat:@"file_%d",index];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:file];
    
    NSLog(@"path=%@",path);
    [data writeToFile:path atomically:NO];
    [data release];
    [self performSelector:@selector(eatDisk) withObject:nil afterDelay:.3];
}


- (IBAction)pauseEat:(id)sender {
    self.paused = true;
    [[self class]cancelPreviousPerformRequestsWithTarget:self selector:@selector(eatDisk) object:nil];
}

- (IBAction)stopEatingDisk:(id)sender {
    [self pauseEat:self];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(eatDisk) object:nil];
}


-(void)removeAll
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    for(NSString* file in files)
    {
        NSLog(@"file=%@",file);
        NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:file];

        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
 
}



- (uint64_t)freeDiskspace
{
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll));
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %d", [error domain], [error code]);
    }
    long long totalFreeSpaceMB = (totalSpace/1024ll)/1024ll;
    if ( totalFreeSpaceMB<=50) {
        self.paused = YES;
        [self removeAll];
    }
    
    return totalFreeSpace;
}

@end
