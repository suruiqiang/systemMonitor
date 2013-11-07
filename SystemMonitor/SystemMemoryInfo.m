//
//  MemoryInfo.m
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import "SystemMemoryInfo.h"
#include <mach/mach.h>
#include <mach/mach_host.h>

void report_memory(void)
{
	struct task_basic_info info;
	mach_msg_type_number_t size = sizeof(info);
	kern_return_t kerr = task_info(mach_task_self(),
								   TASK_BASIC_INFO,
								   (task_info_t)&info,
								   &size);
	if( kerr == KERN_SUCCESS )
    {
		//printf("Memory vm : %u\n",info.virtual_size);
		//printf("Memory in use (in bytes): %u b\n", info.resident_size);
		//printf("Memory in use (in k-bytes): %f k\n", info.resident_size / 1024.0);
		printf("Memory in use (in m-bytes): %f m\n", info.resident_size / (1024.0 * 1024.0));
	}
    else
    {
		printf("Error with task_info(): %s\n", mach_error_string(kerr));
	}
}
@implementation SystemMemoryInfo
{
    uint64_t _memoryActiveBytes;
    uint64_t _memoryInactiveBytes;
    uint64_t _memoryWiredBytes;
    uint64_t _memoryFreeBytes;
    uint64_t _memoryUsedBytes;
    uint64_t _memoryTotalBytes;
    uint64_t _memoryPageSize;
}

+ (id)info
{
    static dispatch_once_t onceToken;
    static SystemMemoryInfo *systemMemoryInfo;
    dispatch_once(&onceToken, ^{
        systemMemoryInfo = [[self alloc] init];
    });
    return systemMemoryInfo;
}

- ( void )updateInfo
{
    @synchronized( self )
    {
        mach_port_t             hostPort;
        mach_msg_type_number_t  hostSize;
        vm_size_t               pageSize;
        vm_statistics_data_t    vmStat;
        
        hostPort = mach_host_self();
        hostSize = sizeof( vm_statistics_data_t ) / sizeof( integer_t );
        
        host_page_size( hostPort, &pageSize );
        
        if( host_statistics( hostPort, HOST_VM_INFO, ( host_info_t )&vmStat, &hostSize ) != KERN_SUCCESS )
        {
            return;
        }
        
        _memoryPageSize        = pageSize;
        _memoryActiveBytes     = vmStat.active_count   * _memoryPageSize;
        _memoryInactiveBytes   = vmStat.inactive_count * _memoryPageSize;
        _memoryWiredBytes      = vmStat.wire_count     * _memoryPageSize;
        _memoryFreeBytes       = vmStat.free_count     * _memoryPageSize;
        _memoryUsedBytes       = _memoryActiveBytes + _memoryInactiveBytes + _memoryWiredBytes;
        _memoryTotalBytes      = _memoryUsedBytes + _memoryFreeBytes;
    }
}

- ( uint64_t )totalMemory
{
    [ self updateInfo ];
    
    return _memoryTotalBytes;
}

- ( uint64_t )activeMemory
{
    [ self updateInfo ];
    
    return _memoryActiveBytes;
}

- ( uint64_t )inactiveMemory
{
    [ self updateInfo ];
    
    return _memoryInactiveBytes;
}

- ( uint64_t )wiredMemory
{
    [ self updateInfo ];
    
    return _memoryWiredBytes;
}

- ( uint64_t )freeMemory
{
    [ self updateInfo ];
    
    return _memoryFreeBytes;
}

- ( uint64_t )usedMemory
{
    [ self updateInfo ];
    
    return _memoryUsedBytes;
}

- (BOOL)print
{
    [self updateInfo];
    NSLog(@"totalMemory=%lld",[[SystemMemoryInfo info] totalMemory]/(1024*1024));
    NSLog(@"freeMemory=%lld",[[SystemMemoryInfo info] freeMemory]/(1024*1024));
    
    NSLog(@"usedMemory=%lld",[[SystemMemoryInfo info] usedMemory]/(1024*1024));
    NSLog(@"activeMemory=%lld",[[SystemMemoryInfo info] activeMemory]/(1024*1024));
    NSLog(@"inactiveMemory=%lld",[[SystemMemoryInfo info] inactiveMemory]/(1024*1024));
    NSLog(@"wiredMemory=%lld",[[SystemMemoryInfo info] wiredMemory]/(1024*1024));
    return YES;
}

-(void)recycleMemory
{

    NSMutableArray* array = [[NSMutableArray alloc] init];
    for(int i=0; i<20; i++)
    {
        CGSize imageSize = CGSizeMake(320, 480);
        UIColor *fillColor = [UIColor blackColor];
        UIGraphicsBeginImageContextWithOptions(imageSize, YES, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [fillColor setFill];
        CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        
       // UIImage* image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DSC_0107" ofType:@"jpg"]];
        UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
        imageView.frame = CGRectMake(0, 0, 320, 480);
        [array addObject:imageView];
       // [imageView release];
  //      NSMutableData* data = [[NSMutableData alloc] initWithLength:1024*1024*20];
//        [array addObject:image];
        //[data release];
        sleep(1);
       // [self print];
        report_memory();
    }
    NSLog(@"after cycle");
        [array release];
    sleep(5);


    [self print];

}

@end
