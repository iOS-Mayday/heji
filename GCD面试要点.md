GCD在iOS中应该是最常使用的并发编程技术了，GCD接口设计得很简洁，使用起来也很方便，由于苹果做了高度的封装，所以很多人对GCD的原理并不是很了解，本文来总结一下GCD常用面试要点。

# 什么是GCD

GCD(Grand Central Dispatch) 是 Apple 开发的一个多核编程的较新的解决方法。它主要用于优化应用程序以支持多核处理器以及其他对称多处理系统。它是一个在线程池模式的基础上执行的并发任务。在 Mac OS X 10.6 雪豹中首次推出，也可在 iOS 4 及以上版本使用。

# 队列和任务

GCD中有两个核心概念，队列和任务。

## 队列

队列其实就是线程池，在OC中以dispatch_queue_t表示，队列分串行队列和并发队列。

## 任务

任务其实就是线程执行的代码，在OC中以Block表示。
在队列中执行任务有两种方式：同步执行和异步执行。两者的主要区别是：是否等待队列的任务执行结束，以及是否具备创建新线程的能力。

*   同步执行（sync）：
    1、同步添加任务到指定的队列中，在添加的任务执行结束之前，会一直等待，直到队列里面的任务完成之后再继续执行。
    2、只能在当前线程中执行任务，不会创建新线程。
*   异步执行（async）：
    1、异步添加任务到指定的队列中，添加完成可以继续执行后面的代码。
    2、可以在新的线程中执行任务，可能会创建新线程。

# 队列

## 创建队列

用dispatch_queue_create来创建队列,其中第一个参数label表示队列的名称，可以为NULL；第二个参数attr用来表示创建串行队列还是并发队列，DISPATCH_QUEUE_SERIAL 或者NULL表示串行队列，DISPATCH_QUEUE_CONCURRENT 表示并发队列

```
dispatch_queue_t dispatch_queue_create(const char *_Nullable label, dispatch_queue_attr_t _Nullable attr);

```

## 主队列和全局队列

主队列：主队列是串行队列，只有一个线程，那就是主线程，添加到主队列中的任务会在主线执行。通过dispatch_get_main_queue获取主队列。
全局队列：全局队列是并发队列。可以通过dispatch_get_global_queue获取不同级别的全局队列

## 如何判断当前代码运行在某个队列

通过队列的label来判断

```
self.opQueue = dispatch_queue_create(NSStringFromClass([self class]).UTF8String, DISPATCH_QUEUE_SERIAL); //创建一个opQueue，名字为类名。注意：通过类名来创建一个唯一的队列名，因为OC类名不能重复
//下面的方法用来判断当前是否在opQueue
- (BOOL)_isInOpQueue{

    NSString* currentQueueLabel = [NSString stringWithUTF8String:dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)];
    if ([currentQueueLabel isEqualToString:NSStringFromClass([self class])]) {
        return YES;
    }

    return NO;
}

```

# 同步任务、异步任务

## dispatch_sync和dispatch_async

用dispatch_sync来创建同步任务
用dispatch_async来创建异步任务
『主线程』中，『不同队列』+**『不同任务』**简单组合的区别：
![image](https://upload-images.jianshu.io/upload_images/22877992-cf988fe2ddcc0277.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

『不同队列』+『不同任务』 组合，以及 『队列中嵌套队列』 使用的区别：
![image](https://upload-images.jianshu.io/upload_images/22877992-adaafb7855899a53.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 同步任务，异步任务线程创建机制

### 同步任务+并发队列

在当前线程中执行任务，不会开启新线程，执行完一个任务，再执行下一个任务 。执行如下代码：

```
- (void)syncTaskInConcurrentQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);
    NSLog(@"begin");

    dispatch_queue_t queue = dispatch_queue_create(NSStringFromClass([self class]).UTF8String, DISPATCH_QUEUE_CONCURRENT);

    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:1];
        NSLog(@"1---%@",[NSThread currentThread]);
    });

    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:1];
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    NSLog(@"end");
}

```

```
运行结果如下：
2020-11-12 00:18:10.088131+0800 OCTestDemo[3337:38026] currentThread---<NSThread: 0x6000020ee880>{number = 1, name = main}
2020-11-12 00:18:10.088254+0800 OCTestDemo[3337:38026] begin
2020-11-12 00:18:11.089673+0800 OCTestDemo[3337:38026] 1---<NSThread: 0x6000020ee880>{number = 1, name = main}
2020-11-12 00:18:12.090277+0800 OCTestDemo[3337:38026] 2---<NSThread: 0x6000020ee880>{number = 1, name = main}
2020-11-12 00:18:12.090526+0800 OCTestDemo[3337:38026] end
可以看到，dispatch_sync调用前运行在主线程，dispatch_sync添加的两个同步任务依次执行并且都运行在主线程，end最后打印，因为要等两个同步任务执行完才能执行后面的代码。

```

### 异步任务+并发队列

特点：可以开启多个线程，任务并发执行

```
- (void)asyncTaskInConcurrentQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  
    NSLog(@"begin");

    dispatch_queue_t queue = dispatch_queue_create(NSStringFromClass([self class]).UTF8String, DISPATCH_QUEUE_CONCURRENT);

    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"1---%@",[NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    NSLog(@"end");
}

```

```
运行结果如下：
2020-11-12 00:24:55.171031+0800 OCTestDemo[3458:40785] currentThread---<NSThread: 0x60000126d340>{number = 1, name = main}
2020-11-12 00:24:55.171137+0800 OCTestDemo[3458:40785] begin
2020-11-12 00:24:55.171260+0800 OCTestDemo[3458:40785] end
2020-11-12 00:24:57.176777+0800 OCTestDemo[3458:40829] 1---<NSThread: 0x6000012341c0>{number = 3, name = (null)}
2020-11-12 00:24:57.176782+0800 OCTestDemo[3458:40831] 2---<NSThread: 0x6000012495c0>{number = 4, name = (null)}
可以看到先打印了end，因为这两个任务是异步任务，调用dispatch_async不会阻塞主线程，可以继续执行后面的代码，所以先打印了end。然后再在两个不同的线程并发执行了这两个任务。注意：现执行任务1还是任务2是不确定的。

```

### 同步任务+串行队列

特点：不会开启新线程，在当前线程执行任务。任务是串行的，执行完一个任务，再执行下一个任务。

```
- (void)syncTaskInSerialQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  
    NSLog(@"begin");

    dispatch_queue_t queue = dispatch_queue_create(NSStringFromClass([self class]).UTF8String, DISPATCH_QUEUE_SERIAL);

    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"1---%@",[NSThread currentThread]);
    });
    dispatch_sync(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    NSLog(@"end");
}

```

```
运行结果如下：
2020-11-12 00:35:08.546658+0800 OCTestDemo[3548:44335] currentThread---<NSThread: 0x600002555340>{number = 1, name = main}
2020-11-12 00:35:08.546789+0800 OCTestDemo[3548:44335] begin
2020-11-12 00:35:10.547507+0800 OCTestDemo[3548:44335] 1---<NSThread: 0x600002555340>{number = 1, name = main}
2020-11-12 00:35:12.548172+0800 OCTestDemo[3548:44335] 2---<NSThread: 0x600002555340>{number = 1, name = main}
2020-11-12 00:35:12.548399+0800 OCTestDemo[3548:44335] end

可以看到任务1和任务2是运行在主线程，因为队列是串行队列，所以任务1和任务2先后执行；因为任务1和2都是同步任务，所以等两个任务完成后才会打印end。

```

### 异步任务+串行队列

特点：会开启新线程，但是因为任务是串行的，执行完一个任务，再执行下一个任务。

```
- (void)asyncTaskInSerialQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);
    NSLog(@"begin");

    dispatch_queue_t queue = dispatch_queue_create(NSStringFromClass([self class]).UTF8String, DISPATCH_QUEUE_SERIAL);

    dispatch_async(queue, ^{
        // 追加任务 1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
    });
    dispatch_async(queue, ^{
        // 追加任务 2
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);      // 打印当前线程
    });

    NSLog(@"end");
}

```

```
运行结果如下：
2020-11-12 00:44:22.643590+0800 OCTestDemo[3645:47865] currentThread---<NSThread: 0x600003b2e900>{number = 1, name = main}
2020-11-12 00:44:22.643760+0800 OCTestDemo[3645:47865] begin
2020-11-12 00:44:22.643903+0800 OCTestDemo[3645:47865] end
2020-11-12 00:44:24.647874+0800 OCTestDemo[3645:47912] 1---<NSThread: 0x600003b448c0>{number = 3, name = (null)}
2020-11-12 00:44:26.651177+0800 OCTestDemo[3645:47912] 2---<NSThread: 0x600003b448c0>{number = 3, name = (null)}
可以看到先打印了end，然后再串行执行了任务1和任务2，任务1和任务2执行在一个新线程。因为串行队列只会创建一个线程。

```

### 同步任务+主队列

#### 在主线程中调用 『同步任务+主队列列』

因为死锁导致crash

```
- (void)syncTaskInMainQueue {

    NSLog(@"currentThread---%@",[NSThread currentThread]);
    NSLog(@"begin");

    dispatch_queue_t queue = dispatch_get_main_queue();

    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"1---%@",[NSThread currentThread]);
    });

    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    NSLog(@"end");
}

```

```
运行后发现打印完成begin后直接crash了。

```

![image](https://upload-images.jianshu.io/upload_images/22877992-56436e5065d81b4d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 在其他线程中调用『同步任务+主队列』

不会开启新线程，执行完一个任务，再执行下一个任务

```
 [NSThread detachNewThreadSelector:@selector(syncTaskInMainQueue) toTarget:self withObject:nil];

```

```
运行结果如下：
2020-11-12 00:56:57.272195+0800 OCTestDemo[3782:53141] currentThread---<NSThread: 0x600001ab5080>{number = 3, name = (null)}
2020-11-12 00:56:57.272856+0800 OCTestDemo[3782:53141] begin
2020-11-12 00:56:59.292677+0800 OCTestDemo[3782:53087] 1---<NSThread: 0x600001afcf80>{number = 1, name = main}
2020-11-12 00:57:01.294829+0800 OCTestDemo[3782:53087] 2---<NSThread: 0x600001afcf80>{number = 1, name = main}
2020-11-12 00:57:01.295815+0800 OCTestDemo[3782:53141] end
可以看到任务1和任务2先后在主线程执行，并且要等任务1和任务2执行完后才会打印end

```

### 异步任务+主队列

```
- (void)asyncTaskInMainQueue {
    NSLog(@"currentThread---%@",[NSThread currentThread]);
    NSLog(@"begin");

    dispatch_queue_t queue = dispatch_get_main_queue();

    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"1---%@",[NSThread currentThread]);
    });

    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];
        NSLog(@"2---%@",[NSThread currentThread]);
    });

    NSLog(@"end");
}

```

```
运行结果如下：
2020-11-12 01:03:02.820131+0800 OCTestDemo[3836:55469] currentThread---<NSThread: 0x600001302640>{number = 1, name = main}
2020-11-12 01:03:02.820307+0800 OCTestDemo[3836:55469] begin
2020-11-12 01:03:02.820435+0800 OCTestDemo[3836:55469] end
2020-11-12 01:03:04.835759+0800 OCTestDemo[3836:55469] 1---<NSThread: 0x600001302640>{number = 1, name = main}
2020-11-12 01:03:06.837321+0800 OCTestDemo[3836:55469] 2---<NSThread: 0x600001302640>{number = 1, name = main}
可以看到在打印完end后，依次在主线程执行任务1和任务2，这是因为任务1和任务2是异步线程并且主队列是串行队列

```

# GCD线程池

![image](https://upload-images.jianshu.io/upload_images/22877992-6172b0a6ba2c1384.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 有几个root队列？

12个。

*   userInteractive、default、unspecified、userInitiated、utility 6个，他们的overcommit版本6个。
    支持overcommit的队列在创建队列时无论系统是否有足够的资源都会重新开一个线程。
    串行队列和主队列是overcommit的，创建队列会创建1个新的线程。并行队列是非overcommit的，不一定会新建线程，会从线程池中的64个线程中获取并使用。
*   优先级 userInteractive>default>unspecified>userInitiated>utility>background
*   全局队列是root队列。

## 有几个线程池？

两个。一个是主线程池，另一个是除了主线程池之外的线程池。

## 一个队列最多支持几个线程同时工作？

64个

## 多个队列，允许最多几个线程同时工作？

64个。优先级高的队列获得的可活跃线程数多于优先级低的，但也有例外，低优先级的也能获得少量活跃线程。
参考资料：[iOS刨根问底-深入理解GCD](https://www.cnblogs.com/kenshincui/p/13272517.html)

# dispatch_once

可以用disaptch_once来执行一次性的初始化代码，比如创建单例，这个方法是线程安全的。

## 死锁问题

用disaptch_once创建单例的时候，如果出现循环引用的情况，会造成死锁。比如A->B->C->A这种调用就会死锁。
可以参考[滥用单例之dispatch_once死锁](https://satanwoo.github.io/2016/04/11/dispatch-once/)

# dispatch_after

用来延迟执行代码。类似NSTimer。需要注意的是：dispatch_after 方法并不是在指定时间之后才开始执行任务，而是在指定时间之后将任务追加到主队列中。

# dispatch_group

可以用dispatch_group来实现类似需求，当一组任务都执行完成后，然后再来执行最后的操作。比如进入一个页面同时发起两个网络请求，等两个网络请求都返回后再执行界面刷新。可以用dispatch_group + dispatch_group_enter + dispatch_group_leave + dispatch_group_notify来实现。

# dispatch_semaphore_t

## 用来计数

当创建信号量时初始化大于1，可以用来实现多线程并发。

## 用做锁，效率比较高

当创建信号量时初始化等于1，退化为锁。信号量锁的效率很高，仅次于OSSpinLock和os_unfair_lock。关于多线程同步可以见笔者另外一篇文章多线程面试要点。

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
