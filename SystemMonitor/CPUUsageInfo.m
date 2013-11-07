//
//  CPUInfo.m
//  SystemMonitor
//
//  Created by Barney on 8/23/13.
//  Copyright (c) 2013 pvllnspk. All rights reserved.
//

#import "CPUUsageInfo.h"
#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>


/*
 Process info functions
 
 Copyright (c) 2003 - 2006 Night Productions, by Darkshadow.  All Rights Reserved.
 http://www.nightproductions.net/developer.htm
 darkshadow@nightproductions.net
 
 May be used freely, but keep my name/copyright in the header.
 
 There is NO warranty of any kind, express or implied; use at your own risk.
 Responsibility for damages (if any) to anyone resulting from the use of this
 code rests entirely with the user.
 
 --> getProcessInfoByPID(int pidNum) - returns a dictionary of info on the process.  Contains:
 Key:			    Value:
 DSProcessName		    NSString of the process's name
 DSProcessPIDNumber	    NSNumber (int) of the process's ID
 DSProcessStartTime	    NSDate of when the process started
 DSProcessFlags		    NSArray of strings, each a different flag.
 DSProcessFlagValue	    NSNumber (unsigned long) of the flag value.
 DSProcessStatus		    NSString of the process's status
 DSProcessStatusValue	    NSNumber (unsigned long) of the status value.
 DSProcessSystemPriority     NSNumber (int) of the process's system priority
 DSProcessNiceValue	    NSNumber (int) of the process's nice value.
 DSProcessParentPID	    NSNumber (int) of the process's parent PID
 DSProcessOwner		    NSString of the process's owner
 DSProcessArguments	    NSString of the process's arguments
 DSProcessEnvironment	    NSArray of strings, each a different environment setting
 
 *Note: You must have sufficient privs to read the process args & env.  Really, unless
 you are root, you only have sufficient privs to read the args & env of procs
 owned by whoever is running the code.
 
 --> getProcessInfoByName(NSString *name) - returns an array of dictionaries, each a different
 process.  See above for the contents of the dictionary.
 *Note: works something like grep - it'll match any process name that contains *name*.
 i.e. 'in' will match init, mach_init, and any other process that contains 'in'.
 --> allProcessesInfo(void) - returns an array of dictionaries, each a different process.
 See above for the contents of the dictionary.
 --> allProcesses(void) - returns an array of strings, each a different process name.
 --> isProcessRunningByPID(int pidNum) - returns YES or NO, depending if the given PID is
 running.
 --> isProcessRunningByName(NSString *name) - returns YES or NO, depending if the given
 process is running.
 *Note: matches *exactly* - it'll match only a process name that IS *name*.
 returns YES on first found match.
 
 -------------------------------------------------------
 
 * Sometime around the end of 2003 / beginning of 2004 - initial release
 * December 15, 2004 - Fixed a bug that had isProcessRunningByPid() always returning TRUE.
 * April 02, 2006 - Fixed a few memory leaks, changed the implementation of some of the
 internal code to be quicker, cleaned up the code a bit, fixed a bug where
 I was returning a _released_ object - I'm sad to admit that, but even more sad still that
 it actually worked prior to Tiger....
 */

#import <unistd.h>
#import <string.h>
#import <sys/sysctl.h>
#import <sys/time.h>
#import <sys/types.h>
#import <pwd.h>





@implementation CPUUsageInfo
{
    processor_info_array_t _cpuInfo, _prevCpuInfo;
    mach_msg_type_number_t _numCpuInfo, _numPrevCpuInfo;
    unsigned _numCPUs;
    NSLock *_CPUUsageLock;
    
    NSMutableArray *_cores;
}


//返回所有正在运行的进程的 id，name，占用cpu，运行时间
//使用函数int	sysctl(int *, u_int, void *, size_t *, void *, size_t)
- (NSArray *)runningProcesses
{
	//指定名字参数，按照顺序第一个元素指定本请求定向到内核的哪个子系统，第二个及其后元素依次细化指定该系统的某个部分。
	//CTL_KERN，KERN_PROC,KERN_PROC_ALL 正在运行的所有进程
	int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL ,0};
    
    size_t miblen = 4;
	//值-结果参数：函数被调用时，size指向的值指定该缓冲区的大小；函数返回时，该值给出内核存放在该缓冲区中的数据量
	//如果这个缓冲不够大，函数就返回ENOMEM错误
    size_t size;
	//返回0，成功；返回-1，失败
    int st = sysctl(mib, miblen, NULL, &size, NULL, 0);
    
    struct kinfo_proc * process = NULL;
    struct kinfo_proc * newprocess = NULL;
    do
	{
		size += size / 10;
        newprocess = realloc(process, size);
        if (!newprocess)
		{
			if (process)
			{
                free(process);
				process = NULL;
            }
            return nil;
        }
        
        process = newprocess;
        st = sysctl(mib, miblen, process, &size, NULL, 0);
    } while (st == -1 && errno == ENOMEM);
    
    if (st == 0)
	{
        if (size % sizeof(struct kinfo_proc) == 0)
		{
            int nprocess = size / sizeof(struct kinfo_proc);
            if (nprocess)
			{
                NSMutableArray * array = [[NSMutableArray alloc] init];
                for (int i = nprocess - 1; i >= 0; i--)
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					NSString * processID = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_pid];
                    NSString * processName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
					NSString * proc_CPU = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_estcpu];
					double t = [[NSDate date] timeIntervalSince1970] - process[i].kp_proc.p_un.__p_starttime.tv_sec;
					NSString * proc_useTiem = [[NSString alloc] initWithFormat:@"%f",t];
                    
					//NSLog(@"process.kp_proc.p_stat = %c",process.kp_proc.p_stat);
                    
					NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
					[dic setValue:processID forKey:@"ProcessID"];
					[dic setValue:processName forKey:@"ProcessName"];
					[dic setValue:proc_CPU forKey:@"ProcessCPU"];
					[dic setValue:proc_useTiem forKey:@"ProcessUseTime"];
                    
					[processID release];
                    [processName release];
					[proc_CPU release];
					[proc_useTiem release];
                    [array addObject:dic];
                    [dic release];
                    
					[pool release];
                }
                
                free(process);
				process = NULL;
				NSLog(@"array = %@",array);
                
				return array;
            }
        }
    }
    
    return nil;
}




+ (id)info
{
    static dispatch_once_t onceToken;
    static CPUUsageInfo *CPUInfo;
    dispatch_once(&onceToken, ^{
        CPUInfo = [[self alloc] init];
    });
    return CPUInfo;
}

-(id)init
{
    if ((self = [super init]))
    {
        int mib[2U] = { CTL_HW, HW_NCPU };
        size_t sizeOfNumCPUs = sizeof(_numCPUs);
        int status = sysctl(mib, 2U, &_numCPUs, &sizeOfNumCPUs, NULL, 0U);
        if (status) _numCPUs = 1;
        _CPUUsageLock = [[NSLock alloc] init];
        
        _cores = [NSMutableArray array];
    }
    return self;
}

- ( void )updateInfo
{
    [_cores removeAllObjects];
    
    natural_t numCPUsU = 0U;
    kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &_cpuInfo, &_numCpuInfo);
    
    if(err == KERN_SUCCESS)
    {
        [_CPUUsageLock lock];
        
        for(unsigned i = 0U; i < _numCPUs; ++i)
        {
            float inUse, total;
            if(_prevCpuInfo)
            {
                inUse = (
                         (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER]   - _prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER])
                         + (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] - _prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM])
                         + (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE]   - _prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE])
                         );
                
                total = inUse + (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] - _prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE]);
                
            } else
            {
                inUse = _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] + _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] + _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
                total = inUse + _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
            }
            
            [_cores addObject:[NSNumber numberWithFloat: inUse / total ]];
        }
        
        [_CPUUsageLock unlock];
        
        if(_prevCpuInfo) {
            size_t prevCpuInfoSize = sizeof(integer_t) * _numPrevCpuInfo;
            vm_deallocate(mach_task_self(), (vm_address_t)_prevCpuInfo, prevCpuInfoSize);
        }
        
        _prevCpuInfo = _cpuInfo;
        _numPrevCpuInfo = _numCpuInfo;
        
        _cpuInfo = NULL;
        _numCpuInfo = 0U;
    } else
    {
        NSLog(@"Error!");
    }
}

- (NSArray *) cpuUsage
{
    [self updateInfo];
    
    return _cores;
}





@end



/*
 
 #ifndef P_SINTR
 #define P_SINTR NSNotFound
 #endif
 
 #ifndef P_LP64
 #define P_LP64 NSNotFound
 #endif
 
 #ifndef P_CONTINUED
 #define P_CONTINUED NSNotFound
 #endif
 
 #ifndef P_AFFINITY
 #define P_AFFINITY NSNotFound
 #endif
 
 #ifndef P_TRANSLATED
 #define P_TRANSLATED NSNotFound
 #endif
 
 #if P_INMEM == 0
 #define MY_INMEM NSNotFound
 #else
 #define MY_INMEM P_INMEM
 #endif
 
 #if P_FSTRACE == 0
 #define MY_FSTRACE NSNotFound
 #else
 #define MY_FSTRACE P_FSTRACE
 #endif
 
 #if P_SSTEP == 0
 #define MY_SSTEP NSNotFound
 #else
 #define MY_SSTEP P_SSTEP
 #endif
 
 
 NSString *DSProcessName = @"Process Name";
 NSString *DSProcessPIDNumber = @"Process PID Number";
 NSString *DSProcessStartTime = @"Process Start Time";
 NSString *DSProcessFlags = @"Process Flags";
 NSString *DSProcessFlagValue = @"Process Flag Value";
 NSString *DSProcessStatus = @"Process Status";
 NSString *DSProcessStatusValue = @"Process Status Value";
 NSString *DSProcessSystemPriority = @"Process System Priority";
 NSString *DSProcessNiceValue = @"Process Nice Value";
 NSString *DSProcessParentPID = @"Process Parent PID";
 NSString *DSProcessOwner = @"Process Owner";
 NSString *DSProcessArguments = @"Process Arguments";
 NSString *DSProcessEnvironment = @"Process Environment";
 

void args(pid_t pidNum, NSMutableArray **procArgs, NSMutableArray **procEnv)
{
    int mib[3], maxarg = 0, numArgs = 0, j = 0, argDone = 0;
    size_t size = 0;
    char *args = NULL, *startPtr = NULL, *stringPtr = NULL, *procPtr[ARG_MAX] = {NULL};
    NSMutableArray *argPtr = *procArgs;
    NSMutableArray *envPtr = *procEnv;
    
    if ( *procArgs == nil ) {
        *procArgs = [[NSMutableArray alloc] initWithCapacity:5];
        argPtr = *procArgs;
    }
    
    if ( *procEnv == nil ) {
        *procEnv = [[NSMutableArray alloc] initWithCapacity:5];
        envPtr = *procEnv;
    }
    
    procPtr[0] = NULL;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    size = sizeof(maxarg);
    if ( sysctl(mib, 2, &maxarg, &size, NULL, 0) == -1 ) {
        goto ERROR;
    }
    
    args = (char *)malloc( maxarg );
    if ( args == NULL ) {
        goto ERROR;
    }
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pidNum;
    
    size = (size_t)maxarg;
    if ( sysctl(mib, 3, args, &size, NULL, 0) == -1 ) {
        free( args );
        goto ERROR;
    }
    
    memcpy( &numArgs, args, sizeof(numArgs) );
    stringPtr = args + sizeof(numArgs);
    
    startPtr = stringPtr;
    
    for ( j = 0; stringPtr < &args[size]; *stringPtr++ ) {
        if ( *stringPtr == '\0' ) {
            if ( (startPtr != NULL) && (*startPtr != '\0') ) {
                procPtr[j] = malloc( strlen(startPtr) + 1 );
                strcpy( procPtr[j], startPtr );
                while ( ((*stringPtr == '\0') && (stringPtr < &args[size])) ) {
                    *stringPtr++;
                }
                startPtr = stringPtr;
                j++;
            }
        }
    }
    
    j=1;
    while ( (procPtr[j] != NULL) ) {
        if ( (strchr(procPtr[j], '=')) != NULL ) {
            char *p = NULL;
            if ( ((p = strrchr(procPtr[j], '-')) != NULL) ) {
                *p--;
                if ( *p == '-' ) {
                    [argPtr addObject:[NSString stringWithUTF8String:procPtr[j]]];
                } else {
                    argDone = 1;
                    [envPtr addObject:[NSString stringWithUTF8String:procPtr[j]]];
                }
            } else {
                argDone = 1;
                [envPtr addObject:[NSString stringWithUTF8String:procPtr[j]]];
            }
        } else if ( !argDone ) {
            [argPtr addObject:[NSString stringWithUTF8String:procPtr[j]]];
        } else {
            [envPtr addObject:[NSString stringWithUTF8String:procPtr[j]]];
        }
        j++;
    }
    
    if ( [argPtr count] == 0 ) {
        [argPtr addObject:@"None"];
    }
    if ( [envPtr count] == 0 ) {
        [envPtr addObject:@"None"];
    }
    
    free( args );
    
    startPtr = NULL;
    stringPtr = NULL;
    
    j = 0;
    while ( (procPtr[j] != NULL) ) {
        free( procPtr[j] );
        j++;
    }
    
    return;
    
ERROR:
    [argPtr addObject:@"Not Available"];
    [envPtr addObject:@"Not Available"];
    return;
}


NSString *nameForProcessWithPID(pid_t pidNum)
{
    NSString *returnString = nil;
    int mib[4], maxarg = 0, numArgs = 0;
    size_t size = 0;
    char *args = NULL, *namePtr = NULL, *stringPtr = NULL;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    size = sizeof(maxarg);
    if ( sysctl(mib, 2, &maxarg, &size, NULL, 0) == -1 ) {
        return nil;
    }
    
    args = (char *)malloc( maxarg );
    if ( args == NULL ) {
        return nil;
    }
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pidNum;
    
    size = (size_t)maxarg;
    if ( sysctl(mib, 3, args, &size, NULL, 0) == -1 ) {
        free( args );
        return nil;
    }
    
    memcpy( &numArgs, args, sizeof(numArgs) );
    stringPtr = args + sizeof(numArgs);
    
    if ( (namePtr = strrchr(stringPtr, '/')) != NULL ) {
        *namePtr++;
        returnString = [[NSString alloc] initWithUTF8String:namePtr];
    } else {
        returnString = [[NSString alloc] initWithUTF8String:stringPtr];
    }
    
    return [returnString autorelease];
}


NSDictionary *getProcessInfoByPID(int procPid)
{
    NSMutableDictionary *returnDict = [[NSMutableDictionary alloc] initWithCapacity:11];
    struct kinfo_proc *kp;
    int mib[4], nentries;
    size_t bufSize = 0;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = procPid;
    
    if ( sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0 ) {
        return [returnDict autorelease];
    }
    
    kp= (struct kinfo_proc *)malloc( bufSize );
    if ( kp == NULL ) {
        return [returnDict autorelease];
    }
    if ( sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0 ) {
        free( kp );
        return [returnDict autorelease];
    }
    
    nentries = bufSize / sizeof(struct kinfo_proc);
    
    if ( nentries == 0 ) {
        free( kp );
        return [returnDict autorelease];
    }
    
    {
        int procFlag = (int)(kp->kp_proc.p_flag);
        char procStat = (char)(kp->kp_proc.p_stat);
        pid_t procPid = (pid_t)(kp->kp_proc.p_pid);
        u_char procPriority = (u_char)(kp->kp_proc.p_priority);
        char procNice = (kp->kp_proc.p_nice);
        NSString *procName = nameForProcessWithPID( kp->kp_proc.p_pid );
        pid_t procParentPid = (pid_t)(kp->kp_eproc.e_ppid);
        time_t procStartTime = (kp->kp_proc.p_starttime.tv_sec);
        uid_t userId = (kp->kp_eproc.e_ucred.cr_uid);
        NSDate *theDate = [NSDate dateWithTimeIntervalSince1970:procStartTime];
        struct passwd *pw;
        NSMutableArray *procArgs = nil, *procEnv = nil;
        NSMutableString *procStats = [[NSMutableString alloc] initWithCapacity:10];
        NSMutableArray *procFlags = [[NSMutableArray alloc] initWithCapacity:3];
        NSString *procArgsStr = nil;
        
        pw = getpwuid( userId );
        
        args( procPid, &procArgs, &procEnv );
        
        procArgsStr = [procArgs componentsJoinedByString:@" "];
        
        if ( (procStat & SIDL) == SIDL )
            [procStats appendString:@"Process being created by fork "];
        if ( (procStat & SRUN) == SRUN )
            [procStats appendString:@"Currently runnable "];
        if ( (procStat & SSLEEP) == SSLEEP )
            [procStats appendString:@"Sleeping on an address "];
        if ( (procStat & SSTOP) == SSTOP )
            [procStats appendString:@"Process debugging or suspension "];
        if ( (procStat & SZOMB) == SZOMB )
            [procStats appendString:@"Awaiting collection by parent "];
	    
        if ( ([procStats length] == 0) && (procStat > 0) ) {
            [procStats appendString:@"Unknown state"];
        } else if ( [procStats length] == 0 ) {
            [procStats appendString:@"None available"];
        }
        
        if ( procFlag == 0 )
            goto ENDFLAGS;
        if ( (procFlag & P_ADVLOCK) == P_ADVLOCK )
            [procFlags addObject:@"Process may hold POSIX advisory lock"];
        if ( (procFlag & P_CONTROLT) == P_CONTROLT )
            [procFlags addObject:@"Process has a controlling terminal"];
        if ( (procFlag & MY_INMEM) == MY_INMEM )
            [procFlags addObject:@"Process loaded into memory"];
        if ( (procFlag & P_NOCLDSTOP) == P_NOCLDSTOP )
            [procFlags addObject:@"No SIGCHLD when child(ren) stop"];
        if ( (procFlag & P_PPWAIT) == P_PPWAIT )
            [procFlags addObject:@"Parent waiting for child(ren) exec/exit"];
        if ( (procFlag & P_PROFIL) == P_PROFIL )
            [procFlags addObject:@"Process has started profiling"];
        if ( (procFlag & P_SELECT) == P_SELECT )
            [procFlags addObject:@"Selecting; wakeup/waiting danger"];
        if ( (procFlag & P_CONTINUED) == P_CONTINUED )
            [procFlags addObject:@"Process was stopped and continued"];
        if ( (procFlag & P_SINTR) == P_SINTR )
            [procFlags addObject:@"Process in interruptible sleep"];
        if ( (procFlag & P_SUGID) == P_SUGID )
            [procFlags addObject:@"Process has set group id privileges"];
        if ( (procFlag & P_SYSTEM) == P_SYSTEM )
            [procFlags addObject:@"System process: no signals, stats, or swap"];
        if ( (procFlag & P_TIMEOUT) == P_TIMEOUT )
            [procFlags addObject:@"Process is timing out during sleep"];
        if ( (procFlag & P_TRACED) == P_TRACED )
            [procFlags addObject:@"Debugged process being traced"];
        if ( (procFlag & P_WEXIT) == P_WEXIT )
            [procFlags addObject:@"Process working on exit"];
        if ( (procFlag & P_EXEC) == P_EXEC )
            [procFlags addObject:@"Process called exec"];
        if ( (procFlag & P_OWEUPC) == P_OWEUPC )
            [procFlags addObject:@"Owe process an addupc() call at next ast."];
        if ( (procFlag & P_AFFINITY) == P_AFFINITY )
            [procFlags addObject:@"P_AFFINITY"];
        if ( (procFlag & P_TRANSLATED) == P_TRANSLATED )
            [procFlags addObject:@"P_TRANSLATED or P_CLASSIC"];
        if ( (procFlag & MY_FSTRACE) == MY_FSTRACE )
            [procFlags addObject:@"Process tracing via filesystem"];
        if ( (procFlag & MY_SSTEP) == MY_SSTEP )
            [procFlags addObject:@"Process needs single-step fixup"];
        if ( (procFlag & P_REBOOT) == P_REBOOT )
            [procFlags addObject:@"Process called reboot()"];
        if ( (procFlag & P_TBE) == P_TBE )
            [procFlags addObject:@"Process is TBE"];
        if ( (procFlag & P_NOSHLIB) == P_NOSHLIB )
            [procFlags addObject:@"Process is not using shared libs"];
        if ( (procFlag & P_FORCEQUOTA) == P_FORCEQUOTA )
            [procFlags addObject:@"Forced quota for root"];
        if ( (procFlag & P_NOCLDWAIT) == P_NOCLDWAIT )
            [procFlags addObject:@"No zombies when child processes exit"];
        if ( (procFlag & P_NOREMOTEHANG) == P_NOREMOTEHANG )
            [procFlags addObject:@"No hang on remote filesystem operations"];
        
    ENDFLAGS:
        if ( ([procFlags count] == 0) && procFlag > 0 ) {
            [procFlags addObject:@"Unknown flag"];
        } else if ( [procFlags count] == 0 ) {
            [procFlags addObject:@"No flags"];
        }
        
        if ( procName == nil ) {
            procName = [NSString stringWithUTF8String:(kp->kp_proc.p_comm)];
        }
        
        [returnDict setObject:procName forKey:DSProcessName];
        [returnDict setObject:[NSNumber numberWithInt:procPid] forKey:DSProcessPIDNumber];
        [returnDict setObject:theDate forKey:DSProcessStartTime];
        [returnDict setObject:procFlags forKey:DSProcessFlags];
        [returnDict setObject:procStats forKey:DSProcessStatus];
        [returnDict setObject:[NSNumber numberWithInt:procPriority] forKey:DSProcessSystemPriority];
        [returnDict setObject:[NSNumber numberWithInt:procNice] forKey:DSProcessNiceValue];
        [returnDict setObject:[NSNumber numberWithInt:procParentPid] forKey:DSProcessParentPID];
        [returnDict setObject:[NSString stringWithUTF8String:(pw != NULL) ? pw->pw_name : "UNKNOWN USER"] forKey:DSProcessOwner];
        [returnDict setObject:procArgsStr forKey:DSProcessArguments];
        [returnDict setObject:procEnv forKey:DSProcessEnvironment];
        [returnDict setObject:[NSNumber numberWithUnsignedLong:procFlag] forKey:DSProcessFlagValue];
        [returnDict setObject:[NSNumber numberWithUnsignedLong:procStat] forKey:DSProcessStatusValue];
        
        [procArgs release];
        [procEnv release];
        [procFlags release];
        [procStats release];
    }
    
    free( kp );
    
    return [returnDict autorelease];
}

NSArray *getProcessInfoByName(NSString *name)
{
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    char getProcName[255] = {0};
    struct kinfo_proc *kp;
    int mib[4], nentries, i;
    size_t bufSize = 0;
    
    strcpy( getProcName, [name UTF8String] );
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_ALL;
    mib[3] = 0;
    
    if ( sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0 ) {
        return [returnArray autorelease];
    }
    
    kp= (struct kinfo_proc *)malloc( bufSize );
    if ( kp == NULL ) {
        return [returnArray autorelease];
    }
    if ( sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0 ) {
        free( kp );
        return [returnArray autorelease];
    }
    
    nentries = bufSize / sizeof(struct kinfo_proc);
    
    if ( nentries == 0 ) {
        free( kp );
        return [returnArray autorelease];
    }
    
    for ( i = nentries; --i >= 0; ) {
        NSAutoreleasePool *forPool = [[NSAutoreleasePool alloc] init];
        NSString *realProcName = nameForProcessWithPID( ((&kp[i])->kp_proc.p_pid) );
        char *proc = ((&kp[i])->kp_proc.p_comm);
        if ( realProcName != nil ) {
            NSRange containsRange = [realProcName rangeOfString:name options:NSCaseInsensitiveSearch];
            
            if ( containsRange.location != NSNotFound ) {
                [returnArray addObject:getProcessInfoByPID( ((&kp[i])->kp_proc.p_pid) )];
            }
        } else if ( strcasestr(proc, getProcName) != NULL ) {
            [returnArray addObject:getProcessInfoByPID( ((&kp[i])->kp_proc.p_pid) )];
        }
        [forPool release];
    }
    
    free( kp );
    
    return [returnArray autorelease];
}

NSArray *allProcessesInfo(void)
{
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    struct kinfo_proc *kp;
    int mib[4], nentries, i;
    size_t bufSize = 0;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_ALL;
    mib[3] = 0;
    
    if ( sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0 ) {
        return [returnArray autorelease];
    }
    
    kp = (struct kinfo_proc *)malloc( bufSize );
    if ( kp == NULL ) {
        return [returnArray autorelease];
    }
    if ( sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0 ) {
        free( kp );
        return [returnArray autorelease];
    }
    
    nentries = bufSize / sizeof(struct kinfo_proc);
    
    if ( nentries == 0 ) {
        free( kp );
        return [returnArray autorelease];
    }
    
    for ( i = (nentries - 1); --i >= 0; ) {
        [returnArray addObject:getProcessInfoByPID( ((&kp[i])->kp_proc.p_pid) )];
    }
    
    free( kp );
    
    return [returnArray autorelease];
}

NSArray *allProcesses(void)
{
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    struct kinfo_proc *kp;
    int mib[4], nentries, i;
    size_t bufSize = 0;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_ALL;
    mib[3] = 0;
    
    if ( sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0 ) {
        return [returnArray autorelease];
    }
    
    kp = (struct kinfo_proc *)malloc( bufSize );
    if ( kp == NULL ) {
        return [returnArray autorelease];
    }
    if ( sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0 ) {
        free( kp );
        return [returnArray autorelease];
    }
    
    nentries = bufSize / sizeof(struct kinfo_proc);
    
    if ( nentries == 0 ) {
        free( kp );
        return [returnArray autorelease];
    }
    
    for ( i = (nentries - 1); --i >= 0; ) {
        NSAutoreleasePool *forPool = [[NSAutoreleasePool alloc] init];
        NSString *realName = nameForProcessWithPID( ((&kp[i])->kp_proc.p_pid) );
        if ( realName != nil ) {
            [returnArray addObject:realName];
        } else {
            [returnArray addObject:[NSString stringWithUTF8String:((&kp[i])->kp_proc.p_comm)]];
        }
        [forPool release];
    }
    
    free( kp );
    
    return [returnArray autorelease];
}

BOOL isProcessRunningByPID(int pidNum)
{
    struct kinfo_proc *kp;
    int mib[4], nentries;
    size_t bufSize = 0;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = pidNum;
    
    if ( sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0 ) {
        return NO;
    }
    
    kp = (struct kinfo_proc *)malloc( bufSize );
    if ( kp == NULL ) {
        return NO;
    }
    if ( sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0 ) {
        free( kp );
        return NO;
    }
    
    nentries = bufSize / sizeof(struct kinfo_proc);
    
    if ( nentries == 0 ) {
        free( kp );
        return NO;
    }
    
    free( kp );
    
    return YES;
}

BOOL isProcessRunningByName(NSString *name)
{
    char getProcName[255] = {0};
    struct kinfo_proc *kp;
    int mib[4], nentries, i;
    size_t bufSize = 0;
    
    strcpy( getProcName, [name UTF8String] );
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_ALL;
    mib[3] = 0;
    
    if ( sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0 ) {
        return NO;
    }
    
    kp = (struct kinfo_proc *)malloc( bufSize );
    if ( kp == NULL ) {
        return NO;
    }
    if ( sysctl(mib, 4, kp, &bufSize, NULL, 0) < 0 ) {
        free( kp );
        return NO;
    }
    
    nentries = bufSize / sizeof(struct kinfo_proc);
    
    if ( nentries == 0 ) {
        free( kp );
        return NO;
    }
    
    for ( i = nentries; --i >= 0; ) {
        NSAutoreleasePool *forPool = [[NSAutoreleasePool alloc] init];
        NSString *realName = nameForProcessWithPID( ((&kp[i])->kp_proc.p_pid) );
        char *proc = ((&kp[i])->kp_proc.p_comm);
        
        if ( [realName isEqualToString:name] ) {
            free( kp );
            return YES;
        } else if ( !strcmp(proc, getProcName) ) {
            free( kp );
            return YES;
        }
        [forPool release];
    }
    
    free( kp );
    
    return NO;
}


 */