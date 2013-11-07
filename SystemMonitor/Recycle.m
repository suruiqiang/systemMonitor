//
//  Recycle.m
//  SystemMonitor
//
//  Created by 苏 瑞强 on 13-10-12.
//  Copyright (c) 2013年 su ruiqiang. All rights reserved.
//

#import "Recycle.h"
#import "SystemMemoryInfo.h"

@implementation Recycle
@synthesize array;

-(void)main
{
    if([self isCancelled]) return;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [[SystemMemoryInfo info] print];
    report_memory();
    
    if (array==nil) {
        array = [[NSMutableArray alloc] init];
    }
    
    for(int m=0;m<100;m++)
    {
        @autoreleasepool{
            for (int i = 0; i < 100; i++){
                UIImage *image = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DSC_0107" ofType:@"jpg"]];
               // NSLog(@"i=%d",i);
                UIImageView* aimageView = [[UIImageView alloc] initWithImage:image];
                [image release];
                aimageView.frame = CGRectMake(i*320, 0, 320, 480);
                [array addObject:aimageView];
                [aimageView release];
            }
        }
        report_memory();
    }
    
    [[SystemMemoryInfo info] print];

    [pool release];
    
    [array removeAllObjects];
}



@end
