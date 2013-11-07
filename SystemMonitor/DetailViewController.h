//
//  DetailViewController.h
//  SystemMonitor
//
//  Created by 苏 瑞强 on 13-10-12.
//  Copyright (c) 2013年 su ruiqiang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (retain, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
