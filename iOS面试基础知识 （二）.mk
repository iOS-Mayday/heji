
# 一、类别

OC不像C++等高级语言能直接继承多个类，不过OC可以使用类别和协议来实现多继承。

## 1、类别加载时机

在App加载时，Runtime会把Category的实例方法、协议以及属性添加到类上；把Category的类方法添加到类的metaclass上。

## 2、类别添加属性、方法

1）在类别中不能直接以@property的方式定义属性，OC不会主动给类别属性生成setter和getter方法；需要通过objc_setAssociatedObject来实现。

```
@interface TestClass(ak)

@property(nonatomic,copy) NSString *name;

@end

@implementation TestClass (ak)

- (void)setName:(NSString *)name{

    objc_setAssociatedObject(self,  "name", name, OBJC_ASSOCIATION_COPY);
}

- (NSString*)name{
    NSString *nameObject = objc_getAssociatedObject(self,  "name");
    return nameObject;
}

```

2）类别同名方法覆盖问题

*   如果类别和主类都有名叫funA的方法，那么在类别加载完成之后，类的方法列表里会有两个funA；
*   类别的方法被放到了新方法列表的前面，而主类的方法被放到了新方法列表的后面，这就造成了类别方法会“覆盖”掉原来类的同名方法，这是因为运行时在查找方法的时候是顺着方法列表的顺序查找的，它只要一找到对应名字的方法，就会停止查找，殊不知后面可能还有一样名字的方法；
*   如果多个类别定义了同名方法funA,具体调用哪个类别的实现由编译顺序决定，后编译的类别的实现将被调用。
*   在日常开发过程中，类别方法重名轻则造成调用不正确，重则造成crash，我们可以通过给类别方法名加前缀避免方法重名。

关于类别更深入的解析可以参见美团的技术文章[深入理解Objective-C：Category](https://tech.meituan.com/2015/03/03/diveintocategory.html)

# 二、协议

## 定义

iOS中的协议类似于Java、C++中的接口类，协议在OC中可以用来实现多继承和代理。

## 方法声明

协议中的方法可以声明为@required（要求实现，如果没有实现，会发出警告，但编译不报错）或者@optional（不要求实现，不实现也不会有警告）。
笔者经常会问面试者如下两个问题：
-怎么判断一个类是否实现了某个协议？很多人不知道可以通过conformsToProtocol来判断。
-假如你要求业务方实现一个delegate，你怎么判断业务方有没有实现dalegate的某个方法？很多人不知道可以通过respondsToSelector来判断。

# 三、通知中心

iOS中的通知中心实际上是观察者模式的一种实现。

## postNotification是同步调用还是异步调用？

同步调用。当调用addObserver方法监听通知，然后调用postNotification抛通知，postNotification会在当前线程遍历所有的观察者，然后依次调用观察者的监听方法，调用完成后才会去执行postNotification后面的代码。

## 如何实现异步监听通知？

通过addObserverForName:object:queue:usingBlock来实现异步通知。

# 四、KVC

## KVC查找顺序

1）调用setValue:forKey时候，比如[obj setValue:@"akon" forKey:@"key"]时候，会按照_key，_iskey，key，iskey的顺序搜索成员并进行赋值操作。如果都没找到，系统会调用该对象的setValue:forUndefinedKey方法，该方法默认是抛出异常。
2）当调用valueForKey:@"key"的代码时，KVC对key的搜索方式不同于setValue"akon" forKey:@"key"，其搜索方式如下：

*   首先按get, is的顺序查找getter方法，找到的话会直接调用。如果是BOOL或者Int等值类型，会将其包装成一个NSNumber对象。
*   如果没有找到，KVC则会查找countOf、objectInAtIndex或AtIndexes格式的方法。如果countOf方法和另外两个方法中的一个被找到，那么就会返回一个可以响应NSArray所有方法的代理集合(它是NSKeyValueArray，是NSArray的子类)，调
    用这个代理集合的方法，就会以countOf,objectInAtIndex或AtIndexes这几个方法组合的形式调用。还有一个可选的get:range:方法。所以你想重新定义KVC的一些功能，你可以添加这些方法，需要注意的是你的方法名要符合KVC的标准命名方法，包括方法签名。
    -如果上面的方法没有找到，那么会同时查找countOf，enumeratorOf,memberOf格式的方法。如果这三个方法都找到，那么就返回一个可以响应NSSet所的方法的代理集合，和上面一样，给这个代理集合发NSSet的消息，就会以countOf，enumeratorOf,memberOf组合的形式调用。
*   如果还没有找到，再检查类方法+ (BOOL)accessInstanceVariablesDirectly,如果返回YES(默认行为)，那么和先前的设值一样，会按_,_is,,is的顺序搜索成员变量名。
*   如果还没找到，直接调用该对象的valueForUndefinedKey:方法，该方法默认是抛出异常。

## KVC防崩溃

我们经常会使用KVC来设置属性和获取属性，但是如果对象没有按照KVC的规则声明该属性，则会造成crash，怎么全局通用地防止这类崩溃呢？
可以通过写一个NSObject分类来防崩溃。

```
@interface NSObject(AKPreventKVCCrash)

@end

@ implementation NSObject(AKPreventKVCCrash)

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{    
}

- (id)valueForUndefinedKey:(NSString *)key{

    return nil;
}

@end

```

# 五、KVO

## 定义

KVO(Key-Value Observing)，键值观察。它是一种观察者模式的衍生。其基本思想是，对目标对象的某属性添加观察，当该属性发生变化时，通过触发观察者对象实现的KVO接口方法，来自动的通知观察者。

## 注册、移除KVO

通过如下两个方案来注册、移除KVO

```
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context;
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;

```

通过observeValueForKeyPath来获取值的变化。

```
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context

```

我们可以通过facebook开源库[KVOController](https://github.com/facebook/KVOController)方便地进行KVO。

## KVO实现

苹果官方文档对KVO实现介绍如下：

> Key-Value Observing Implementation Details
> Automatic key-value observing is implemented using a technique called isa-swizzling.
> The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.
> When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.
> You should never rely on the isa pointer to determine class membership. Instead, you should use the class method to determine the class of an object instance.

即当一个类型为 ObjectA 的对象，被添加了观察后，系统会生成一个派生类 NSKVONotifying_ObjectA 类，并将对象的isa指针指向新的类，也就是说这个对象的类型发生了变化。因此在向ObjectA对象发送消息时候，实际上是发送到了派生类对象的方法。由于编译器对派生类的方法进行了 override，并添加了通知代码，因此会向注册的对象发送通知。注意派生类只重写注册了观察者的属性方法。

关于kvc和kvo更深入的详解参考[iOS KVC和KVO详解](https://juejin.im/post/6844903602545229831)

# 六、autorelasepool

## 用处

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

## Runloop中自动释放池创建和释放时机

*   系统在 Runloop 中创建的 autoreleaspool 会在 Runloop 一个 event 结束时进行释放操作。
*   我们手动创建的 autoreleasepool 会在 block 执行完成之后进行 drain 操作。需要注意的是：
    当 block 以异常结束时，pool 不会被 drain
    Pool 的 drain 操作会把所有标记为 autorelease 的对象的引用计数减一，但是并不意味着这个对象一定会被释放掉，我们可以在 autorelease pool 中手动 retain 对象，以延长它的生命周期（在 MRC 中）。

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
