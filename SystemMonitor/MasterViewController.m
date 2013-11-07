//
//  MasterViewController.m
//  SystemMonitor
//
//  Created by 苏 瑞强 on 13-10-12.
//  Copyright (c) 2013年 su ruiqiang. All rights reserved.
//

#import "MasterViewController.h"
#import "SystemMemoryInfo.h"
#import "DetailViewController.h"
#import "DiskUsageInfo.h"
#import "Recycle.h"
#import "CPUUsageInfo.h"
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>

@interface MasterViewController () {
    NSMutableArray *_objects;
}
@end

@implementation MasterViewController
@synthesize array;

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];
}






- (void)viewDidLoad
{
    [super viewDidLoad];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMenory:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[DiskUsageInfo info] freeDiskspace];
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
  //  [self destroyAndEatAllMemory];
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(startEatingCache:)];
    self.navigationItem.rightBarButtonItem = addButton;
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"receive Memory");
    report_memory();
    
    [self pauseEat:self];
    [self.array removeAllObjects];
    self.array = nil;
//    [cycle cancel];
//    [cycle.array removeAllObjects];
//    cycle.array = nil;

    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



-(void)destoryMemory
{
    
    cycle = [[Recycle alloc] init];
    [cycle main];
    return;
    [[SystemMemoryInfo info] print];
    scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 100, 320, 300)];
    scrollView.backgroundColor = [UIColor whiteColor];
    [scrollView setContentSize:CGSizeMake(320*100, 400)];
    [self.view addSubview:scrollView];
    [scrollView release];
    report_memory();

    if (array==nil) {
            array = [[NSMutableArray alloc] init];
    }
 
    for(int m=0;m<100;m++)
    {
        @autoreleasepool{
            for (int i = 0; i < 100; i++){
                UIImage *image = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DSC_0107" ofType:@"jpg"]];
                if (shouldStop) {
                    NSLog(@"跳出");
                    break;
                }
                NSLog(@"i=%d",i);
                //        CGRect bounds = CGRectMake(0, 0, 400, 400);
                //        UIGraphicsBeginImageContext(bounds.size);
                //        [image drawInRect:bounds];
                //        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
                //        UIGraphicsEndImageContext();
                //        [array addObject:newImage];
                UIImageView* aimageView = [[UIImageView alloc] initWithImage:image];
                [image release];
                aimageView.frame = CGRectMake(i*320, 0, 320, 480);
               // [scrollView addSubview:aimageView];
               //
                [array addObject:aimageView];
                [aimageView release];
            }
            
        }
        report_memory();

        }
        [[SystemMemoryInfo info] print];
}


-(IBAction)startEatingCache:(id)sender
{
    [[DiskUsageInfo info] startEatingDisk:nil];
}


-(IBAction)startEatingMemory:(id)sender
{
    [[SystemMemoryInfo info] print];
    if(array == nil){
        array = [[NSMutableArray alloc] init];
    }
    self.paused = false;
    [self eatMemory];
}

- (IBAction)pauseEat:(id)sender {
    self.paused = true;
    [[self class]cancelPreviousPerformRequestsWithTarget:self selector:@selector(eatMemory) object:nil];
}

- (IBAction)stopEatingMemory:(id)sender {
    [self pauseEat:self];
    
    [array removeAllObjects];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(eatMemory) object:nil];
}


-(void)eatMemory
{
    report_memory();
    
    unsigned long dinnerLength = 2*1024 * 1024;
    char *dinner = malloc(sizeof(char) * dinnerLength);
    for (int i=0; i < dinnerLength; i++)
    {
        //write to each byte ensure that the memory pages are actually allocated
        dinner[i] = '0';
    }
    NSData *plate = [NSData dataWithBytesNoCopy:dinner length:dinnerLength freeWhenDone:YES];
    [array addObject:plate];
    
    
    [self performSelector:@selector(eatMemory) withObject:nil afterDelay:.3];
}




- (void)destroyAndEatAllMemory {
    array = [[NSMutableArray array] retain];
    for (int i = 0; i < 100; i++) {
        double delayInSeconds = 0.1f;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            UIImage *image = [[UIImage alloc] initWithContentsOfFile:@"DSC_0107.jpg"];
            CGRect bounds = CGRectMake(0, 0, 400, 400);
            UIGraphicsBeginImageContext(bounds.size);
            [image drawInRect:bounds];
            UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            [array addObject:newImage];
               report_memory();
        });
    }
}

- (void)insertNewObject:(id)sender
{
    //[[SystemMemoryInfo info] recycleMemory];
    [self destoryMemory];
    return;
    for(int i=0;i<100;i++)
    {
        NSMutableData *data = [[NSMutableData alloc] initWithLength:100*1024*1024];
        NSString* file = [NSString stringWithFormat:@"file_%d",i];
        NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:file];
        [data writeToFile:path atomically:NO];
        [data release];
        NSLog(@"i=%d",i);
    }


    return;
    if (!_objects) {
        _objects = [[NSMutableArray alloc] init];
    }
    [_objects insertObject:[NSDate date] atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}


-(void)cleanUp:(id)sender
{
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"file"];

    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    NSDate *object = _objects[indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_objects removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        NSDate *object = _objects[indexPath.row];
        self.detailViewController.detailItem = object;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSDate *object = _objects[indexPath.row];
        [[segue destinationViewController] setDetailItem:object];
    }
}

@end
