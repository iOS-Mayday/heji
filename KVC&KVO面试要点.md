# KVC

## 定义

*   KVC 是 Key-Value-Coding 的简称。
*   KVC 是一种可以直接通过字符串的名字 key 来访问类属性的机制，而不需要调用setter、getter方法去访问。
*   我们可以通过在运行时动态的访问和修改对象的属性。KVC 是 iOS 开发中的黑魔法之一。

## 设置值&&获取值

*   设置值

```
- (void)setValue:(id)value forKey:(NSString *)key;

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath;

// 它的默认实现是抛出异常，可以重写这个函数啥也不做来防止崩溃。
- (void)setValue:(id)value forUndefinedKey:(NSString *)key;

```

*   获取值

```
- (id)valueForKey:(NSString *)key;

- (id)valueForKeyPath:(NSString *)keyPath;

// 如果key不存在，且KVC无法搜索到任何和key有关的字段或者属性，则会调用这个方法，默认实现抛出异常。可以通过重写该方法返回nil来防止崩溃
- (id)valueForUndefinedKey:(NSString *)key;

```

## KVC设置和查找顺序

*   设置顺序
    调用- (void)setValue:(id)value forKey:(NSString *)key;时，执行操作
    1、首先搜索setter方法，有就直接赋值。
    2、如果1中的 setter 方法没有找到，再检查类方法+ (BOOL)accessInstanceVariablesDirectly
    返回 NO，则执行setValue:forUndefinedKey:
    返回 YES，则按_key，_isKey，key，isKey的顺序搜索成员名进行赋值。
    3、还没有找到的话，就调用setValue:forUndefinedKey:
*   查找顺序
    当调用valueForKey:@"key"的代码时，KVC对key的搜索方式不同于setValue"akon" forKey:@"key"，其搜索方式如下：

1、首先按get, is的顺序查找getter方法，找到的话会直接调用。如果是BOOL或者Int等值类型，会将其包装成一个NSNumber对象。
2、如果没有找到，KVC则会查找countOf、objectInAtIndex或AtIndexes格式的方法。如果countOf方法和另外两个方法中的一个被找到，那么就会返回一个可以响应NSArray所有方法的代理集合(它是NSKeyValueArray，是NSArray的子类)，调
用这个代理集合的方法，就会以countOf,objectInAtIndex或AtIndexes这几个方法组合的形式调用。还有一个可选的get:range:方法。所以你想重新定义KVC的一些功能，你可以添加这些方法，需要注意的是你的方法名要符合KVC的标准命名方法，包括方法签名。
3、如果上面的方法没有找到，那么会同时查找countOf，enumeratorOf,memberOf格式的方法。如果这三个方法都找到，那么就返回一个可以响应NSSet所的方法的代理集合，和上面一样，给这个代理集合发NSSet的消息，就会以countOf，enumeratorOf,memberOf组合的形式调用。
4、如果还没有找到，再检查类方法+ (BOOL)accessInstanceVariablesDirectly,如果返回YES(默认行为)，那么和先前的设值一样，会按_key,_isKey,key,isKey的顺序搜索成员变量名。
如果还没找到，直接调用该对象的valueForUndefinedKey:方法，该方法默认是抛出异常。

## KVC防崩溃

我们经常会使用KVC来设置属性和获取属性，但是如果对象没有按照KVC的规则声明该属性，则会造成crash，怎么全局通用地防止这类崩溃呢？
可以通过写一个NSObject分类来防崩溃。

```
@interface NSObject(AKPreventKVCCrash)

@end

@ implementation NSObject(AKPreventKVCCrash)

- (id)valueForUndefinedKey:(NSString *)key{

    return nil;
}

- (void)setNilValueForKey:(NSString *)key{

}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key{

}
@end

```

# KVO

## 定义

KVO即Key-Value Observing，翻译成键值观察。它是一种观察者模式的衍生。其基本思想是，对目标对象的某属性添加观察，当该属性发生变化时，通过触发观察者对象实现的KVO接口方法，来自动的通知观察者。

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

## 手动KVO

当我们调用addObserver KVO了一个对象的属性后，当对象的属性发生变化时，iOS会自动调用观察者的observeValueForKeyPath方法。有的时候，我们可能要在setter方法中插入一些代码，然后进行手动KVO，怎么实现呢？
通过重写类的automaticallyNotifiesObserversForKey方法，指定对应属性不要自动KOV，然后在setter方法里面手动调用willChangeValueForKey和didChangeValueForKey来实现。

```
@interface ClassA: NSObject

@property (nonatomic, assign) int age;

@end

@implementation ClassA

// for manual KVO - age
- (void)setAge:(int)theAge{

    [self willChangeValueForKey:@"age"];
    _age = theAge;
    [self didChangeValueForKey:@"age"];
}

+ (BOOL) automaticallyNotifiesObserversForKey:(NSString *)key {

    if ([key isEqualToString:@"age"]) {
        return NO;
    }

    return [super automaticallyNotifiesObserversForKey:key];
}

@end

```

## KVO和线程

KVO是同步调用，调用线程跟属性值改变的线程是相同的。

```
self.age = 10;

```

KVO 能保证所有age的观察者在 setter 方法返回前被通知到。

## KVO实现原理

苹果[官方文档](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOImplementation.html#//apple_ref/doc/uid/20002307-BAJEAIEE)对KVO的实现原理描述如下：

> Key-Value Observing Implementation Details
> Automatic key-value observing is implemented using a technique called isa-swizzling.
> The isa pointer, as the name suggests, points to the object's class which maintains a dispatch table. This dispatch table essentially contains pointers to the methods the class implements, among other data.
> When an observer is registered for an attribute of an object the isa pointer of the observed object is modified, pointing to an intermediate class rather than at the true class. As a result the value of the isa pointer does not necessarily reflect the actual class of the instance.
> You should never rely on the isa pointer to determine class membership. Instead, you should use the class method to determine the class of an object instance.

KVO的实现采用了 isa-swizzling技术。当一个类型为ClassA 的对象，被添加了观察后，系统会生成一个派生类 NSKVONotifying_ClassA 类，并将对象的isa指针指向NSKVONotifying_ClassA，也就是说这个对象的类型发生了变化。因此在向ClassA对象发送消息时候，实际上是发送到了NSKVONotifying_ClassA的方法。由于编译器对NSKVONotifying_ClassA的方法进行了 override，并添加了通知代码，因此会向注册的对象发送通知。注意派生类只重写注册了观察者的属性方法。
派生类会重写setter、class、delloc、_isKVOA

### 重写Setter

在 setter 中，会添加以下两个方法的调用。

```
- (void)willChangeValueForKey:(NSString *)key;
- (void)didChangeValueForKey:(NSString *)key;

```

然后在 didChangeValueForKey: 中，去调用：

```
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(nullable void *)context;

```

包含了新值和旧值的通知。于是实现了属性值修改的通知。
因为 KVO 的原理是修改 setter 方法，因此使用 KVO 必须调用 setter 。若直接访问属性对象则没有效果。

### 重写class

下面代码展示了对ClassA对象objA添加KVO后，objA的isa指针指向了NSKVONotifying_ClassA。
注意：[objA class]返回的是objA真正所属的类。object_getClass(objA)返回的objA的isa指针所属的类。

```
@interface ClassA: NSObject

@property (nonatomic, assign) NSInteger age;

@end

@implementation ClassA

@end

@interface ClassB: NSObject
@end

@implementation ClassB

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {

    NSLog(@"%@", change);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    ClassA* objA = [[ClassA alloc] init];
    ClassB* objB = [[ClassB alloc] init];

    [objA addObserver:objB forKeyPath:@"age" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];

    NSLog(@"%@", [objA class]); //输出ClassA
    NSLog(@"%@", object_getClass(objA));  //输出NSKVONotifying_ClassA（object_getClass方法返回isa指向）

    return YES;
}

```

### 重写delloc

观察移除后使class变回去观察前的类(通过isa指向)。比如上例的ClassA

### 重写_isKVOA

判断被观察者自己是否同时也观察了其他对象。
参考资料：
[iOS KVC和KVO详解](https://juejin.cn/post/6844903602545229831#heading-9)
[KVC和KVO的使用及原理](https://www.jianshu.com/p/66bda10168f1)

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
