//
//  MasterViewController.h
//  SystemMonitor
//
//  Created by 苏 瑞强 on 13-10-12.
//  Copyright (c) 2013年 su ruiqiang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Recycle.h"

@class DetailViewController;

@interface MasterViewController : UITableViewController
{
    NSMutableArray* array;
    BOOL shouldStop;
    UIScrollView* scrollView;
    Recycle* cycle;
}
@property (retain, nonatomic) DetailViewController *detailViewController;
@property(nonatomic,assign)BOOL paused;
@property (retain, nonatomic)NSMutableArray* array;

@end
