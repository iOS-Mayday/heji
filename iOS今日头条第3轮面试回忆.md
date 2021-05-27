![](https://upload-images.jianshu.io/upload_images/22877992-1b039c0757d5f2c8.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


> 今日头条的iOS高级开发岗第三面，下面记录这次面试的回忆以作日后复习。

### 一、自我介绍

> 简单介绍一下你自己吧

*   解析：简单介绍下自己的名字，教育背景，现在的工作，做过的项目

### 二、自我介绍衍生的口头问题

> 讲讲下你在你项目中做过的优化或者技术难点

*   解析：介绍了自己封装的一个集picker，文本域的灵活展开的表视图。这个视图的数据源是json，怎么转成模型数组的？这个cell有哪些类型？展示的怎么区分这些cell？这里面有用过复用机制吗？这些cell有实现过多重继承吗？
*   题外话：这种问题最好各人自己找问题讲讲，不多，提前准备一个你项目中非常擅长并熟悉的点，即可。

### 三、编程题：实现以下功能

> 1) 编写一个自定义类：Person，父类为NSObject

*   解析：头文件这样写 `@interface Person:NSObject`

> 2) 该类有两个属性，外部只读的属性`name`，还有一个属性`age`

*   解析：`name`的修饰符`nonatomic`，`strong`，`readonly`。`age`的修饰符`nonatomic`，`copy`。

> 3) 为该类编写一个初始化方法 `initWithName:(NSString *)nameStr`，并依据该方法参数初始化`name`属性。

*   解析：头文件声明该方法，实现文件实现该方法

> 4) 如果两个Person类的name相等，则认为两个Person相等

*   解析：重写`isEqual`，这里面涉及到了哈希函数在iOS中的应用。

### 四、由编程题衍生的口头题目

#### 4.1

> **题目：** 怎样实现外部只读的属性，让它不被外部篡改

解析：

*   头文件用readonly修饰并声明该属性。正常情况下，属性默认是readwrite，可读写，如果我们设置了只读属性，就表明不能使用setter方法。在.m文件中不能使用`self.ivar = @"aa";` 只能使用实例变量`_ivar = @"aa";`，而外界想要修改只读属性的值，需要用到kvc赋值`[object setValue:@"mm" forKey:@"ivar"];`。

*   实现文件里面声明私有属性，并在头文件在protocol里面规定该属性就可以了，外部通过protocol获取，这样还可以达到隐藏成员的效果。

#### 4.2

> **题目：** nonatomic是非原子操作符，为什么要这样，atomic为什么不行？有人说能atomic耗内存，你觉得呢？保读写安全吗，能保证线程安全吗？有的人说atomic并不能保证线程安全，你觉得他们的出发点是什么，你认同这个说法吗？

*   关于为什么用nonatomic

如果该对象无需考虑多线程的情况，请加入这个属性修饰，这样会让编译器少生成一些互斥加锁代码，可以提高效率。

而atomic这个属性是为了保证程序在多线程情况下，编译器会自动生成一些互斥加锁代码，避免该变量的读写不同步问题。

atomic 和 nonatomic 的区别在于，系统自动生成的 getter/setter 方法不一样。如果你自己写 getter/setter，那 atomic/nonatomic/retain/assign/copy 这些关键字只起提示作用，写不写都一样。

*   关于atomic语nonatomic的实现

> [苹果的官方文档](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjectiveC/Chapters/ocProperties.html) 有解释，下面我们举例子解释一下背后的原理。

*   至于 nonatomic 的实现

```
//@property(nonatomic, retain) UITextField *userName;
//系统生成的代码如下：

- (UITextField *) userName {
    return userName;
}

- (void) setUserName:(UITextField *)userName_ {
    [userName_ retain];
    [userName release];
    userName = userName_;
}

```

*   而 atomic 版本的要复杂一些：

```
//@property(retain) UITextField *userName;
//系统生成的代码如下：

- (UITextField *) userName {
    UITextField *retval = nil;
    @synchronized(self) {
        retval = [[userName retain] autorelease];
    }
    return retval;
}

- (void) setUserName:(UITextField *)userName_ {
    @synchronized(self) {
      [userName release];
      userName = [userName_ retain];
    }
}

```

简单来说，就是 atomic 会加一个锁来保障多线程的读写安全，并且引用计数会 +1，来向调用者保证这个对象会一直存在。假如不这样做，如有另一个线程调 setter，可能会出现线程竞态，导致引用计数降到0，原来那个对象就释放掉了。

*   关于atomic和线程安全

atomic修饰的属性只能说是**读/写安全**的，但并不是**线程安全**的，因为别的线程还能进行读写之外的其他操作。线程安全需要开发者自己来保证。

*   关于修饰符失效

因为atomic修饰的属性靠编译器自动生成的get和set方法实现原子操作，如果重写了任意一个，atomic关键字的特性将失效

#### 4.3

> **题目：** 你在初始化的方法中为什么将参数赋给_name，为什么这样写就能访问到属性声明的示例变量？

*   xcode4 之后，编辑器添加了自动同步补全功能，只需要在 h 文件中定义 property，在编译期m文件会自动补全出 `@synthesize name = _name` 的代码，不再需要手写，避免了“体力代码”的手动编码

#### 4.4

> **题目：** 初始化方法中的_name是在什么时候生成的?分配内存的时候吗？还是初始化的时候？

*   成员变量存储在堆中(当前对象对应的堆得存储空间中) ，不会被系统自动释放，只能有程序员手动释放。

*   编译的时候自动的为name属性生成一个实例变量_name

*   如果m中什么都不写，xcode会默认在编译期为 market 属性，补全成 [@synthesize](https://xiaozhuanlan.com/u/synthesize) market = _market，实例变量名为 _market；

*   如果m中指定了 [@synthesize](https://xiaozhuanlan.com/u/synthesize) market，xcode会认为你手动指定了实例变量名为 market ，编译期补全成：@synthesize market = market，实例变量名为 market。

#### 4.5

> **题目：** 作为return的self是在上面时候生成的？

*   是在alloc时候分配内存，在init初始化的。

*   一种典型带成员变量初始化参数的代码为：

```
- (instancetype)initWithDistance:(float)distance maskAlpha:(float)alpha scaleY:(float)scaleY direction:(CWDrawerTransitionDirection)direction backImage:(UIImage *)backImage {
    if (self = [super init]) {
        _distance = distance;
        _maskAlpha = alpha;
        _direction = direction;
        _backImage = backImage;
        _scaleY = scaleY;
    }
    return self;
}

```

#### 4.6

> **题目：** 为什么用copy，哪些情况下用copy，为什么用copy?

*   可变的类，例如NSArray、NSDictionary、NSString最好用copy来修饰，它们都有对应的Mutable类型。
*   copy修饰属性的本质是为了专门设置属性的setter方法，例如，`setName:`传进一个nameStr参数，那么有了copy修饰词后，传给对应的成员变量_name的其实是`[nameStr copy];`。
*   为什么要这样？如果不用copy会有什么问题？例如，`strong`修饰的NSString类型的name属性，传一个NSMutableString：

```
NSMutableString *mutableString = [NSMutableString stringWithFormat:@"111"];
self.myString = mutableString;

```

在`strong`修饰下，把可变字符串mutableString赋值给myString后，改变mutableString的值导致了`myString`值的改变。而`copy`修饰下，却不会有这种变化。

在`strong`修饰下，可变字符串赋值给myString后，两个对象都指向了相同的地址。而`copy`修饰下，myString和mutableString指向了不同地址。这也是为什么strong修饰下，修改mutableString引起myString变化，而copy修饰下则不会。

*   总之，当修饰可变类型的属性时，如NSMutableArray、NSMutableDictionary、NSMutableString，用strong。当修饰不可变类型的属性时，如NSArray、NSDictionary、NSString，用copy。

#### 4.7

> **题目：** 分类中添加实例变量和属性分别会发生什么，编译时就报错吗，还是什么时候会发生问题？为什么

*   编译的时候，不能添加实例变量，否则报错。

*   编译的时候可以添加属性，但是一旦在创建对象后为属性赋值或者使用这个属性的时候，程序就崩溃了，奔溃的原因也很简单，就是找不到属性的set/get方法。

*   那我们就按照这个流程来，在类别中为属性添加set/get方法，在set方法里面赋值的时候找不到赋值的对象，也就是说系统没有为我们生成带下划线的成员变量，没生成我们就自己加。但是通过传统实例变量的方式，一加就报错。看来这才是类别不能扩展属性的根本原因。

![image](https://upload-images.jianshu.io/upload_images/22877992-b0c0827770d2387e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

*   那么怎么办？通过runtime的关联对象。

### 五、另外聊到的实际开发问题

1) 你平时有做过优化内存的哪些工作？怎样避免内存消耗的大户？

*   可以参考这个[https://www.2cto.com/kf/201505/401059.html](https://www.2cto.com/kf/201505/401059.html)
*   关于TableView的优化可以参考[https://www.jianshu.com/p/9cd9382c0a5b](https://www.jianshu.com/p/9cd9382c0a5b)

2) 你怎样实现线程安全的？这些线程安全的办法和atomic有什么不一样？atomic的实现机制是怎样

*   可以参考YYKit的多线程安全机制，它是用MUTEX实现线程锁的[https://github.com/ibireme/YYKit](https://github.com/ibireme/YYKit)
*   关于锁的实现原理可参考[https://www.jianshu.com/p/a33959324cc7](https://www.jianshu.com/p/a33959324cc7)
*   其它办法，例如队列
*   关于atomic的实现机制前面有讨论，就是加锁。
*   如果不加atomic会怎么样呢？当内存长度大于地址总线的时候，例如在64位系统下内存中读取无法像bool等纯量类型原子性完成，可能会在读取的时候发生写入，从造成异常情况。atomic还会使用memory barrier能够保证内存操作的顺序，按照我们代码的书写顺序来。

# 资料推荐
如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。
![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
