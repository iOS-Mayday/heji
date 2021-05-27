# 多线程

## 多线程创建方式

iOS创建多线程方式主要有NSThread、NSOperation、GCD，这三种方式创建多线程的优缺点如下：

### NSThread

*   NSThread 封装了一个线程，通过它可以方便的创建一个线程。NSThread 线程之间的并发控制，是需要我们自己来控制的。它的缺点是需要我们自己维护线程的生命周期、线程之间同步等，优点是轻量，灵活。

### NSOperation

*   NSOperation 是一个抽象类，它封装了线程的实现细节，不需要自己管理线程的生命周期和线程的同步等，需要和 NSOperationQueue 一起使用。使用 NSOperation ，你可以方便地控制线程，比如取消线程、暂停线程、设置线程的优先级、设置线程的依赖。NSOperation常用于下载库的实现，比如SDWebImage的实现就用到了NSOperation。

### GCD

*   GCD(Grand Central Dispatch) 是 Apple 开发的一个多核编程的解决方法。GCD 是一个可以替代 NSThread 的很高效和强大的技术。在平常开发过程中，我们用的最多的就是GCD。哦，对了，NSOperation是基于GCD实现的。

## 多线程同步

多线程情况下访问共享资源需要进行线程同步，线程同步一般都用锁实现。从操作系统层面，锁的实现有临界区、事件、互斥量、信号量等。这里讲一下iOS中多线程同步的方式。

### atomic

属性加上atomic关键字，编译器会自动给该属性生成代码用以多线程访问同步，它并不能保证使用属性的过程是线程安全的。一般我们在定义属性的时候用nonatomic，避免性能损失。

### [@synchronized](https://xiaozhuanlan.com/u/1294451781)

@synchronized指令是一个对象锁，用起来非常简单。使用obj为该锁的唯一标识，只有当标识相同时，才为满足互斥，如果线程1和线程2中的@synchronized后面的obj不相同，则不会互斥。@synchronized其实是对pthread_mutex递归锁的封装。
@synchronized优点是我们不需要在代码中显式的创建锁对象，使用简单; 缺点是@synchronized会隐式的添加一个异常处理程序，该异常处理程序会在异常抛出的时候自动的释放互斥锁，从而带来额外开销。

### NSLock

最简单的锁，调用lock获取锁，unlock释放锁。如果其它线程已经调用lock获取了锁，当前线程调用lock方法会阻塞当前线程，直到其它线程调用unlock释放锁为止。NSLock使用简单，在项目中用的最多。

### NSRecursiveLock

递归锁主要用来解决同一个线程频繁获取同一个锁而不造成死锁的问题。注意lock和unlock调用必须配对。

### NSConditionLock

条件锁，可以设置自定义条件来获取锁。比如生产者消费者模型可以用条件锁来实现。

### NSCondition

条件，操作系统中信号量的实现，方法- (void)wait和- (BOOL)waitUntilDate:(NSDate *)limit用来等待锁直至锁有信号；方法- (void)signal和- (void)broadcast使condition有信号，通知等待condition的线程，变成非阻塞状态。

### dispatch_semaphore_t

信号量的实现，可以实现控制GCD队列任务的最大并发量，类似于NSOperationQueue的maxConcurrentOperationCount属性。

### pthread_mutex

mutex叫做”互斥锁”，等待锁的线程会处于休眠状态。使用pthread_mutex_init创建锁，使用pthread_mutex_lock和pthread_mutex_unlock加锁和解锁。注意：mutex可以通过PTHREAD_MUTEX_RECURSIVE创建递归锁，防止重复获取锁导致死锁

```
 //创建锁，注意：mutex可以通过PTHREAD_MUTEX_RECURSIVE创建递归锁，防止重复获取锁导致死锁
 pthread_mutexattr_t recursiveAttr;
 pthread_mutexattr_init(&recursiveAttr);
 pthread_mutexattr_settype(&recursiveAttr, PTHREAD_MUTEX_RECURSIVE);
 pthread_mutex_init(self.mutex, &recursiveAttr);
 pthread_mutexattr_destroy(&recursiveAttr);

pthread_mutex_lock(&self.mutex)
//访问共享数据代码
pthread_mutex_unlock(&self.mutex)

```

### OSSpinLock

OSSpinLock 是自旋锁，等待锁的线程会处于忙等状态。一直占用着 CPU。自旋锁就好比写了个 while，whil(被加锁了) ; 不断的忙等，重复这样。OSSpinLock是不安全的锁（会造成优先级反转），什么是优先级反转，举个例子：
有线程1和线程2,线程1的优先级比较高，那么cpu分配给线程1的时间就比较多，自旋锁可能发生优先级反转问题。如果优先级比较低的线程2先加锁了，紧接着线程1进来了，发现已经被加锁了，那么线程1忙等，while（未解锁）; 不断的等待，由于线程1的优先级比较高，CPU就一直分配之间给线程1，就没有时间分配给线程2，就有可能导致线程2的代码就没有办法往下走，就会造成线程2没有办法解锁，所以这个锁就不安全了。
建议不要使用OSSpinLock，用os_unfair_lock来代替。

```
//初始化
OSSpinLock lock = OS_SPINLOCK_INIT;
//加锁
OSSpinLockLock(&lock);
//解锁
OSSpinLockUnlock(&lock);

```

### os_unfair_lock

os_unfair_lock用于取代不安全的OSSpinLock，从iOS10开始才支持 从底层调用看，等待os_unfair_lock锁的线程会处于休眠状态，并非忙等

```
//初始化
os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
//加锁
os_unfair_lock_lock(&lock);
//解锁
os_unfair_lock_unlock(&lock);

```

### 性能

性能从高到低排序
1、os_unfair_lock
2、OSSpinLock
3、dispatch_semaphore
4、pthread_mutex
5、NSLock
6、NSCondition
7、pthread_mutex(recursive)
8、NSRecursiveLock
9、NSConditionLock
10、@synchronized

# JSON Model互转

## 项目中JSON Model转换方式

平常开发过程中，经常需要进行JSON与Model互转，尤其是接口数据转换。我们可以手动解析，也可以用MJExtension、YYModel这些第三方库，用第三方库最大的好处他可以自动给你转换并且处理类型不匹配等异常情况，从而避免崩溃。

## MJExtension实现原理

```
假定后台返回的字典dic为：
{
"name":"akon",
"address":"shenzhen",
}

我们自定义了一个类UserModel
@interface UserModel : NSObject

@property (nonatomic, strong)NSString* name;
@property (nonatomic, strong)NSString* address;

@end

```

*   MJExtension是如何做属性映射的？
    MJExtension在遍历dic属性时，比如遍历到name属性时，先去缓存里查找这个类是否有这个属性，有就赋值akon。没有就遍历UserModel的属性列表，把这个类的属性列表加入到缓存中，查看这个类有没有定义name属性，如果有，就把akon赋给这个属性，否则不赋值。
*   MJExtension是如何给属性赋值的？
    利用KVC机制，在查找到UserModel有name的属性，使用[self setValue:@"akon" forKey:@"name"]进行赋值。
*   如何获取类的属性列表？
    通过class_copyPropertyList方法
*   如何遍历成员变量列表？
    通过class_copyIvarList方法

# 数据存储方式

## iOS常见数据存储方式及使用场景

iOS中可以采用NSUserDefaults、Archive、plist、数据库等方式等来存储数据，以上存储方式使用的业务场景如下：

*   NSUserDefaults一般用来存储一些简单的App配置。比如存储用户姓名、uid这类轻量的数据。
*   Archive可以用来存储model，如果一个model要用Archive存储，需要实现NSCoding协议。
*   plist存储方式。像NSString、NSDictionary等类都可以直接存调用writeToFile:atomically:方法存储到plist文件中。
    -数据库存储方式。大量的数据存储，比如消息列表、网络数据缓存，需要采用数据库存储。可以用FMDB、CoreData、WCDB、YYCache来进行数据库存储。建议使用[WCDB](https://github.com/Tencent/wcdb)来进行数据库存储,因为WCDB是一个支持orm，支持加密，多线程安全的高性能数据库。

## 数据库操作

笔者在面试中，一般会问下面试者数据库的操作，以此开考察一下面试者对于数据库操作的熟练程度。

*   考察常用crud语句书写。
    创建表、给表增加字段、插入、删除、更新、查询SQL怎么写。尤其是查询操作，可以考察order by， group by ，distinct， where匹配以及联表查询等技巧。
*   SQL语句优化技巧。如索引、事务等常用优化技巧。
*   怎么分库、分表？
*   FMDB或者WCDB（orm型）实现原理。
*   怎么实现数据库版本迁移？

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
