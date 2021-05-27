# RunLoop定义

[苹果官方文档](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html)对RunLoop的定义如下：

```
Run loops are part of the fundamental infrastructure associated with threads. A run loop is an event processing loop that you use to schedule work and coordinate the receipt of incoming events. The purpose of a run loop is to keep your thread busy when there is work to do and put your thread to sleep when there is none.

```

翻译为中文为：RunLoop是线程基础设施的一部分。RunLoop是iOS中用来接受事件、处理事件的循环。设计RunLoop的目的是让线程有事件的时候处理事件，没事件的时候处于休眠。
在iOS中RunLoop实际上是一个对象(CFRunLoopRef 和NSRunLoop)，RunLoop做的事情是处于等待消息->接受消息->处理消息这样一个循环中，直到退出循环。

# RunLoop原理

苹果官方原理图
![image](https://upload-images.jianshu.io/upload_images/22877992-6a1e5d60f9d891ab.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

从图中可以看出，RunLoop运行在线程中，接收Input Source 和 Timer Source并且进行处理。

## Input Source 和 Timer Source

两个都是 Runloop 事件的来源。
Input Source 可以分为三类

*   Port-Based Sources，系统底层的 Port 事件，例如 CFSocketRef ；
*   Custom Input Sources，用户手动创建的 Source;
*   Cocoa Perform Selector Sources， Cocoa 提供的 performSelector 系列方法，也是一种事件源;
    Timer Source指定时器事件，该事件的优先级是最低的。
    按照上面的图，事件处理优先级是Port > Custom > performSelector > Timer。
    Input Source异步投递事件到线程中，Timer Source同步投递事件到线程中。

## 获取RunLoop

RunLoop是由线程创建的，我们只能获取。通过CFRunLoopGetCurrent获取当前线程的RunLoop，子线程的RunLoop在子线程中第一次调用CFRunLoopGetCurrent创建，主线程的RunLoop在整个App第一次调用CFRunLoopGetCurrent创建，由UIApplication 的run方法调用。

## RunLoop与线程关系

RunLoop与线程是一一对应关系，一个线程对应一个RunLoop，他们的映射存储在一个字典里，key为线程，value为RunLoop。

## 线程安全

CFRunLoop系列函数是线程安全的。NSRunLoop系列函数不是线程安全的。

## 启动RunLoop

通过CFRunLoopRun系列函数启动RunLoop，启动时可以指定超时时间。RunLoop 启动前内部必须要有至少一个 Timer/Observer/Source，你可以添加一个一次性timer到RunLoop然后再调用CFRunLoopRun。

## 退出RunLoop

*   启动RunLoop时制定超时时间
*   通过 CFRunLoopStop主动退出

## RunLoop Mode

一个 RunLoop 包含若干个 Mode，每个 Mode 又包含若干个 Source/Timer/Observer。每次调用 RunLoop 的主函数时，只能指定其中一个 Mode，这个Mode被称作 CurrentMode。如果需要切换 Mode，只能退出 Loop，再重新指定一个 Mode 进入。这样做主要是为了分隔开不同组的 Source/Timer/Observer，让其互不影响。
苹果定义的Mode如下图，其中NSDefaultRunLoopMode、NSEventTrackingRunLoopMode、NSRunLoopCommonModes我们经常会用到。
![image](https://upload-images.jianshu.io/upload_images/22877992-e5391b29f7e3eea6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Source有两种类型：Source0 和 Source1。

*   Source0 （非基于port）只包含了一个回调，需要手动触发。使用时，你需要先调用 CFRunLoopSourceSignal(source)，将这个 Source 标记为待处理，然后手动调用 CFRunLoopWakeUp(runloop) 来唤醒 RunLoop，让其处理这个事件。
*   Source1 （基于port），可以主动触发。包含了一个 mach_port 和一个回调（函数指针），被用于通过内核和其他线程相互发送消息。

## RunLoop Observers

通过CFRunLoopAddObserver监控RunLoop的状态。RunLoop的状态如下：
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
kCFRunLoopEntry = (1UL << 0), // 即将进入Loop
kCFRunLoopBeforeTimers = (1UL << 1), // 即将处理 Timer
kCFRunLoopBeforeSources = (1UL << 2), // 即将处理 Source
kCFRunLoopBeforeWaiting = (1UL << 5), // 即将进入休眠
kCFRunLoopAfterWaiting = (1UL << 6), // 刚从休眠中唤醒，但是还没完全处理完事件
kCFRunLoopExit = (1UL << 7), // 即将退出Loop
};

我们可以通过Observer来监控主线程的卡顿。

## RunLoop处理事件顺序

![image](https://upload-images.jianshu.io/upload_images/22877992-d3c030c8617ee1a6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

RunLoop内部是一个 do-while 循环。当你调用 CFRunLoopRun() 时，线程就会一直停留在这个循环里；直到超时或被手动停止，该函数才会返回。RunLoop t通过调用mach_msg函数进入休眠等待唤醒状态。

# RunLoop应用

## 苹果用RunLoop实现的功能

AutoreleasePool、事件响应、手势识别、界面更新、定时器、PerformSelecter、GCD、网络请求底层等都用到了RunLoop

## 解决NSTimer事件在列表滚动时不执行问题

因为定时器默认是运行在NSDefaultRunLoopMode，在列表滚动时候，主线程会切换到UITrackingRunLoopMode，导致定时器回调得不到执行。
有两种解决方案：

*   指定NSTimer运行于 NSRunLoopCommonModes下。
*   在子线程创建和处理Timer事件，然后在主线程更新 UI。

## AutoreleasePool

### 用处

在 ARC 下，我们不需要手动管理内存，可以完全不知道 autorelease 的存在，就可以正确管理好内存，因为 Runloop 在每个 Runloop Circle 中会自动创建和释放Autorelease Pool。
当我们需要创建和销毁大量的对象时，使用手动创建的 autoreleasepool 可以有效的避免内存峰值的出现。因为如果不手动创建的话，外层系统创建的 pool 会在整个 Runloop Circle 结束之后才进行 drain，手动创建的话，会在 block 结束之后就进行 drain 操作，比如下面例子：

```
for (int i = 0; i < 100000; i++)
{
    @autoreleasepool
    {
        NSString* string = @"akon";
        NSArray* array = [string componentsSeparatedByString:string];
    }
}

```

比如SDWebImage中这段代码，由于encodedDataWithImage会把image解码成data，可能造成内存暴涨，所以加autoreleasepool避免内存暴涨

```
 @autoreleasepool {
    NSData *data = imageData;
    if (!data && image) {
                    // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
        SDImageFormat format;
        if ([SDImageCoderHelper CGImageContainsAlpha:image.CGImage]) {
            format = SDImageFormatPNG;
        } else {
            format = SDImageFormatJPEG;
        }
        data = [[SDImageCodersManager sharedManager] encodedDataWithImage:image format:format options:nil];
    }
    [self _storeImageDataToDisk:data forKey:key];
}

```

### Runloop中自动释放池创建和释放时机

苹果官方文档：

> The Application Kit creates an autorelease pool on the main thread at the beginning of every cycle of the event loop, and drains it at the end, thereby releasing any autoreleased objects generated while processing an event

-系统在Runloop开始处理一个事件时创建一个autoreleaspool。

*   系统会在处理完一个事件后释放 autoreleaspool 。
*   我们手动创建的 autoreleasepool 会在 block 执行完成之后进行 drain 操作。需要注意的是：当 block 以异常结束时，pool 不会被 drain
    Pool 的 drain 操作会把所有标记为 autorelease 的对象的引用计数减一，但是并不意味着这个对象一定会被释放掉，我们可以在 autorelease pool 中手动 retain 对象，以延长它的生命周期（在 MRC 中）。
    通过_objc_autoreleasePoolPush和_objc_autoreleasePoolPop来创建和释放自动释放池，底层是通过AutoreleasePoolPage来实现的。
*   自动释放池是由 AutoreleasePoolPage 以双向链表的方式实现的
*   当对象调用 autorelease 方法时，会将对象加入 AutoreleasePoolPage 的栈中
*   调用 AutoreleasePoolPage::pop 方法会向栈中的对象发送 release 消息
    关于自动释放池的原理，可以参考这篇文章[自动释放池的前世今生](https://www.jianshu.com/p/32265cbb2a26)

## 监控卡顿

可以通过监控runloop的 kCFRunLoopBeforeSources和kCFRunLoopAfterWaiting的事件间隔来监控卡顿。关于卡顿监控可以参考笔者的文章[卡顿监控及处理](https://xiaozhuanlan.com/topic/1293805467)

## 创建子线程执行任务

你可以创建子线程，然后在别的线程通过performSelector:onThread:withObject:waitUntilDone:路由到该子线程进行处理。

## AsyncDisplayKit

[AsyncDisplayKit](https://github.com/facebookarchive/AsyncDisplayKit)( 现在更名为Texture)，是Facebook开源的用来异步绘制UI的框架。ASDK 仿照 QuartzCore/UIKit 框架的模式，实现了一套类似的界面更新的机制：即在主线程的 RunLoop 中添加一个 Observer，监听了 kCFRunLoopBeforeWaiting 和 kCFRunLoopExit 事件，在收到回调时，遍历所有之前放入队列的待处理的任务，然后一一执行。
参考资料：
[深入理解RunLoop](https://blog.ibireme.com/2015/05/18/runloop/)
苹果官方文档[Run Loops](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html)
# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
