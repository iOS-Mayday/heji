![](https://upload-images.jianshu.io/upload_images/22877992-e09b99c41e14307d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
作者：akon
原文地址：https://xiaozhuanlan.com/topic/6721950348
# 一、Runtime原理

Runtime是iOS核心运行机制之一，iOS App加载库、加载类、执行方法调用，全靠Runtime，这一块的知识个人认为是最基础的，基本面试必问。

## 1、Runtime消息发送机制

1）iOS调用一个方法时，实际上会调用objc_msgSend(receiver, selector, arg1, arg2, ...)，该方法第一个参数是消息接收者，第二个参数是方法名，剩下的参数是方法参数；
2）iOS调用一个方法时，会先去该类的方法缓存列表里面查找是否有该方法，如果有直接调用，否则走第3）步；
3）去该类的方法列表里面找，找到直接调用，把方法加入缓存列表；否则走第4）步；
4）沿着该类的继承链继续查找，找到直接调用，把方法加入缓存列表；否则消息转发流程；
**很多面试者大体知道这个流程，但是有关细节不是特别清楚。**

*   问他/她objc_msgSend第一个参数、第二个参数、剩下的参数分别代表什么，不知道；
*   很多人只知道去方法列表里面查找，不知道还有个方法缓存列表。
    **通过这些细节，可以了解一个人是否真正掌握了原理，而不是死记硬背。**

## 2、Runtime消息转发机制

如果在消息发送阶段没有找到方法，iOS会走消息转发流程，流程图如下所示：
![image](https://upload-images.jianshu.io/upload_images/22877992-3ba3d2a9cf5744d8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1）动态消息解析。检查是否重写了resolveInstanceMethod 方法，如果返回YES则可以通过class_addMethod 动态添加方法来处理消息，否则走第2）步；
2）消息target转发。forwardingTargetForSelector 用于指定哪个对象来响应消息。如果返回nil 则走第3）步；
3）消息转发。这步调用 methodSignatureForSelector 进行方法签名，这可以将函数的参数类型和返回值封装。如果返回 nil 执行第四步；否则返回 methodSignature，则进入 forwardInvocation ，在这里可以修改实现方法，修改响应对象等，如果方法调用成功，则结束。否则执行第4）步；
4）报错 unrecognized selector sent to instance。
**很多人知道这四步，但是笔者一般会问：**

*   怎么在项目里全局解决"unrecognized selector sent to instance"这类crash？本人发现很多人回答不出来，说明面试者肯定是在死记硬背，你都知道因为消息转发那三步都没处理才会报错，为什么不知道在消息转发里面处理呢？
*   如果面试者知道可以在消息转发里面处理，防止崩溃，再问下面试者，你项目中是在哪一步处理的，看看其是否有真正实践过？

# 二、load与initialize

## 1、load与initialize调用时机

+load在main函数之前被Runtime调用，+initialize 方法是在类或它的子类收到第一条消息之前被调用的，这里所指的消息包括实例方法和类方法的调用。

## 2、load与initialize在分类、继承链的调用顺序

*   load方法的调用顺序为：
    子类的 +load 方法会在它的所有父类的 +load 方法之后执行，而分类的 +load 方法会在它的主类的 +load 方法之后执行。
    如果子类没有实现 +load 方法，那么当它被加载时 runtime 是不会去调用父类的 +load 方法的。同理，当一个类和它的分类都实现了 +load 方法时，两个方法都会被调用。
*   initialize的调用顺序为：
    +initialize 方法的调用与普通方法的调用是一样的，走的都是消息发送的流程。如果子类没有实现 +initialize 方法，那么继承自父类的实现会被调用；如果一个类的分类实现了 +initialize 方法，那么就会对这个类中的实现造成覆盖。
*   怎么确保在load和initialize的调用只执行一次
    由于load和initialize可能会调用多次，所以在这两个方法里面做的初始化操作需要保证只初始化一次，用dispatch_once来控制

**笔者在面试过程中发现很多人对于load与initialize在分类、继承链的调用顺序不清楚。对怎么保证初始化安全也不清楚**

# 三、RunLoop原理

RunLoop苹果原理图
![image](https://upload-images.jianshu.io/upload_images/22877992-6631cbb8316a0845.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

图中展现了 Runloop 在线程中的作用：从 input source 和 timer source 接受事件，然后在线程中处理事件。

## 1、RunLoop与线程关系

*   一个线程是有一个RunLoop还是多个RunLoop？ 一个；
*   怎么启动RunLoop？主线程的RunLoop自动就开启了，子线程的RunLoop通过Run方法启动。

## 2、Input Source 和 Timer Source

两个都是 Runloop 事件的来源，其中 Input Source 又可以分为三类

*   Port-Based Sources，系统底层的 Port 事件，例如 CFSocketRef ，在应用层基本用不到;
*   Custom Input Sources，用户手动创建的 Source;
*   Cocoa Perform Selector Sources， Cocoa 提供的 performSelector 系列方法，也是一种事件源;
    Timer Source指定时器事件，该事件的优先级是最低的。
    本人一般会问定时器事件的优先级是怎么样的，大部分人回答不出来。

## 3、解决NSTimer事件在列表滚动时不执行问题

因为定时器默认是运行在NSDefaultRunLoopMode，在列表滚动时候，主线程会切换到UITrackingRunLoopMode，导致定时器回调得不到执行。
有两种解决方案：

*   指定NSTimer运行于 NSRunLoopCommonModes下。
*   在子线程创建和处理Timer事件，然后在主线程更新 UI。

# 四、事件分发机制及响应者链

## 1、事件分发机制

iOS 检测到手指触摸 (Touch) 操作时会将其打包成一个 UIEvent 对象，并放入当前活动Application的事件队列，UIApplication 会从事件队列中取出触摸事件并传递给单例的 UIWindow 来处理，UIWindow 对象首先会使用 hitTest:withEvent:方法寻找此次Touch操作初始点所在的视图(View)，即需要将触摸事件传递给其处理的视图，这个过程称之为 hit-test view。
hitTest:withEvent:方法的处理流程如下:

*   首先调用当前视图的 pointInside:withEvent: 方法判断触摸点是否在当前视图内；
*   若返回 NO, 则 hitTest:withEvent: 返回 nil，若返回 YES, 则向当前视图的所有子视图 (subviews) 发送 hitTest:withEvent: 消息，所有子视图的遍历顺序是从最顶层视图一直到到最底层视图（后加入的先遍历），直到有子视图返回非空对象或者全部子视图遍历完毕；
*   若第一次有子视图返回非空对象，则 hitTest:withEvent: 方法返回此对象，处理结束；
*   如所有子视图都返回空，则 hitTest:withEvent: 方法返回自身 (self)。
    流程图如下：
    ![image](https://upload-images.jianshu.io/upload_images/22877992-cf81122420919881.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 2、响应者链原理

iOS的事件分发机制是为了找到第一响应者，事件的处理机制叫做响应者链原理。
所有事件响应的类都是 UIResponder 的子类，响应者链是一个由不同对象组成的层次结构，其中的每个对象将依次获得响应事件消息的机会。当发生事件时，事件首先被发送给第一响应者，第一响应者往往是事件发生的视图，也就是用户触摸屏幕的地方。事件将沿着响应者链一直向下传递，直到被接受并做出处理。一般来说，第一响应者是个视图对象或者其子类对象，当其被触摸后事件被交由它处理，如果它不处理，就传递给它的父视图（superview）对象（如果存在）处理，如果没有父视图，事件就会被传递给它的视图控制器对象 ViewController（如果存在），接下来会沿着顶层视图（top view）到窗口（UIWindow 对象）再到程序（UIApplication 对象）。如果整个过程都没有响应这个事件，该事件就被丢弃。一般情况下，在响应者链中只要由对象处理事件，事件就停止传递。
一个典型的事件响应路线如下：
First Responser --> 父视图-->The Window --> The Application --> nil（丢弃）
我们可以通过 [responder nextResponder] 找到当前 responder 的下一个 responder，持续这个过程到最后会找到 UIApplication 对象。

# 五、内存泄露检测与循环引用

## 1、造成内存泄露原因

*   在用C/C++时，创建对象后未销毁，比如调用malloc后不free、调用new后不delete；
*   调用CoreFoundation里面的C方法后创建对对象后不释放。比如调用CGImageCreate不调用CGImageRelease；
*   循环引用。当对象A和对象B互相持有的时候，就会产生循环引用。常见产生循环引用的场景有在VC的cellForRowAtIndexPath方法中cell block引用self。

## 2、常见循环引用及解决方案

1） 在VC的cellForRowAtIndexPath方法中cell的block直接引用self或者直接以_形式引用属性造成循环引用。

```
 cell.clickBlock = ^{
        self.name = @"akon";
    };

cell.clickBlock = ^{
        _name = @"akon";
    };

```

解决方案：把self改成weakSelf；

```
__weak typeof(self)weakSelf = self;
    cell.clickBlock = ^{
        weakSelf.name = @"akon";
    };

```

2）在cell的block中直接引用VC的成员变量造成循环引用。

```
//假设 _age为VC的成员变量
@interface TestVC(){

    int _age;

}
cell.clickBlock = ^{
       _age = 18;
    };

```

解决方案有两种：

*   用weak-strong dance

```
__weak typeof(self)weakSelf = self;
cell.clickBlock = ^{
      __strong typeof(weakSelf) strongSelf = weakSelf;
       strongSelf->age = 18;
    };

```

*   把成员变量改成属性

```
//假设 _age为VC的成员变量
@interface TestVC()

@property(nonatomic, assign)int age;

@end

__weak typeof(self)weakSelf = self;
cell.clickBlock = ^{
       weakSelf.age = 18;
    };

```

3）delegate属性声明为strong，造成循环引用。

```
@interface TestView : UIView

@property(nonatomic, strong)id<TestViewDelegate> delegate;

@end

@interface TestVC()<TestViewDelegate>

@property (nonatomic, strong)TestView* testView;

@end

 testView.delegate = self; //造成循环引用

```

解决方案：delegate声明为weak

```
@interface TestView : UIView

@property(nonatomic, weak)id<TestViewDelegate> delegate;

@end

```

4）在block里面调用super，造成循环引用。

```
cell.clickBlock = ^{
       [super goback]; //造成循环应用
    };

```

解决方案，封装goback调用

```
__weak typeof(self)weakSelf = self;
cell.clickBlock = ^{
       [weakSelf _callSuperBack];
    };

- (void) _callSuperBack{
    [self goback];
}

```

5）block声明为strong
解决方案：声明为copy
6）NSTimer使用后不invalidate造成循环引用。
解决方案：

*   NSTimer用完后invalidate；
*   NSTimer分类封装

```
+ (NSTimer *)ak_scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                                         block:(void(^)(void))block
                                       repeats:(BOOL)repeats{

    return [self scheduledTimerWithTimeInterval:interval
                                         target:self
                                       selector:@selector(ak_blockInvoke:)
                                       userInfo:[block copy]
                                        repeats:repeats];
}

+ (void)ak_blockInvoke:(NSTimer*)timer{

    void (^block)(void) = timer.userInfo;
    if (block) {
        block();
    }
}

--

```

*   用[YYWeakProxy](https://github.com/ibireme/YYKit/blob/master/YYKit/Utility/YYWeakProxy.m)来创建定时器

## 3、怎么检测循环引用

*   静态代码分析。 通过Xcode->Product->Anaylze分析结果来处理；
*   动态分析。用[MLeaksFinder](https://github.com/Tencent/MLeaksFinder)（只能检测OC泄露）或者Instrument或者[OOMDetector](https://github.com/Tencent/OOMDetector)（能检测OC与C++泄露）。

# 六、VC生命周期

考察viewDidLoad、viewWillAppear、ViewDidAppear等方法的执行顺序。
假设现在有一个 AViewController(简称 Avc) 和 BViewController (简称 Bvc)，通过 navigationController 的push 实现 Avc 到 Bvc 的跳转，调用顺序如下：
1、A viewDidLoad 
2、A viewWillAppear 
3、A viewDidAppear 
4、B viewDidLoad 
5、A viewWillDisappear 
6、B viewWillAppear 
7、A viewDidDisappear 
8、B viewDidAppear
如果再从 Bvc 跳回 Avc，调用顺序如下：
1、B viewWillDisappear 
2、A viewWillAppear 
3、B viewDidDisappear 
4、A viewDidAppear

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
