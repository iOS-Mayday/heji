在iOS中，block编程使用得很频繁，我们不仅要会用block，更需要理解block的底层实现原理。笔者在面试中，block问题是必问的。

# 什么是block

block是iOS中对闭包的实现，什么是闭包呢？闭包（英语：Closure），又称词法闭包（Lexical Closure）或函数闭包（function closures），是在支持头等函数的编程语言中实现词法绑定的一种技术。闭包在实现上是一个结构体，它存储了一个函数（通常是其入口地址）和一个关联的环境（相当于一个符号查找表）。环境里是若干对符号和值的对应关系，它既要包括约束变量（该函数内部绑定的符号），也要包括自由变量（在函数外部定义但在函数内被引用），有些函数也可能没有自由变量。

# block类型

block是一个OC对象，block类型有__NSStackBlock__、__NSMallocBlock__、__NSGlobalBlock__、，分别分配在栈、堆、全局存储区域中。他们都继承于NSObject。下面代码证明打印了__NSGlobalBlock__的继承链

```
void (^block)(void) =  ^{
        NSLog(@"akon");
    };

    NSLog(@"block.class = %@", [block class]);
    NSLog(@"block.class.superclass = %@", [[block class] superclass]);
    NSLog(@"block.class.superclass.superclass = %@", [[[block class] superclass] superclass]);
    NSLog(@"block.class.superclass.superclass.superclass = %@", [[[[block class] superclass] superclass] superclass]);

运行结果为：
2020-11-13 18:39:02.919351+0800 BlockTestDemo[86009:2083840] block.class = __NSGlobalBlock__
2020-11-13 18:39:02.919562+0800 BlockTestDemo[86009:2083840] block.class.superclass = NSBlock
2020-11-13 18:39:02.919713+0800 BlockTestDemo[86009:2083840] block.class.superclass.superclass = NSObject
2020-11-13 18:39:02.923424+0800 BlockTestDemo[86009:2083840] block.class.superclass.superclass.superclass = (null)

```

下面表格列出了MRC和ARC环境下block类型

## MRC下block类型

| 类型 | 环境 |
| --- | --- |
| __NSGlobalBlock__ | 只访问了静态变量（包括全局静态变量和局部静态变量）和全局变量 |
| __NSStackBlock__ | 没访问静态变量和全局变量 |
| __NSMallocBlock__ | __NSStackBlock__调用了copy |

执行如下代码，打印结果符合预期

```
 __weak typeof(self)weakSelf = self;

    static int a = 0;
    void (^block1)(void) =  ^{
        a = 1;
        b = 1; //b为全局变量

    };

    __block int c = 0;
    void (^block2)(void) =  ^{
        NSLog(@"age:%d", weakSelf.age);
        c = 1;
    };

    NSLog(@"block1.class = %@", [block1 class]);
    NSLog(@"block2.class = %@", [block2 class]);
    NSLog(@"block2 copy.class = %@", [[block2 copy] class]);

运行结果如下：
2020-11-14 22:45:54.457496+0800 BlockTestDemo[13178:426318] block1.class = __NSGlobalBlock__
2020-11-14 22:45:54.457616+0800 BlockTestDemo[13178:426318] block2.class = __NSStackBlock__
2020-11-14 22:45:54.457720+0800 BlockTestDemo[13178:426318] block2 copy.class = __NSMallocBlock__

```

## ARC下block类型

| 类型 | 环境 |
| --- | --- |
| __NSGlobalBlock__ | 只访问了静态变量（包括全局静态变量和局部静态变量）和全局变量 |
| __NSMallocBlock__ | 没访问静态变量和全局变量 |

运行上面的代码，结果如下：

```
2020-11-14 22:45:54.457052+0800 BlockTestDemo[13178:426318] block1.class = __NSGlobalBlock__
2020-11-14 22:45:54.457211+0800 BlockTestDemo[13178:426318] block2.class = __NSMallocBlock__
2020-11-14 22:45:54.457356+0800 BlockTestDemo[13178:426318] block2 copy.class = __NSMallocBlock__

```

## ARC下自动copy

*   我们看到block2为__NSMallocBlock__，这是因为编译器做了优化，在ARC下除了_NSGlobalBlock__就是__NSMallocBlock__，没有__NSStackBlock__；在MRC __NSMallocBlock__生成的条件是对block调用了copy操作。
*   在ARC环境下，编译器会根据情况自动将栈上的block复制到堆上，copy的情况如下：
    1、block作为函数返回值时
    2、 将block赋值给__strong指针时
    3、block作为Cocoa API中方法名含有usingBlock的方法参数时
    4、block作为GCD API的方法参数时
    在ARC中对__NSStackBlock__调用copy变成__NSMallocBlock__，__NSMallocBlock__调用copy还是__NSMallocBlock__，引用计数+1，_NSGlobalBlock__调用copy啥都不做。
*   copy底层原理
    1、通过_Block_object_assign来对OC对象进行强引用或弱引用
    2、通过_Block_object_dispose对OC进行清理

# block数据结构和变量捕获

## block数据结构

写下如下代码，然后在终端进入.m文件所在目录，执行命令xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc ArcClass.m 我们可以看到在当前目录生成ArcClass.cpp文件。

```
int age = 18;
void (^block)(void) =  ^{
     NSLog(@"age is %d",age);
 };

block();

```

我们可以看到上面的代码变成了

```
 int age = 18;
// block定义
    void (*block)(void) = ((void (*)())&__ArcClass__TestArc_block_impl_0((void *)__ArcClass__TestArc_block_func_0, &__ArcClass__TestArc_block_desc_0_DATA, age));
// block调用
    ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);

```

上面代码删除掉一些强制转换的代码简化如下

```
int age = 18;
// block定义
void (*block)(void) = & __ArcClass__TestArc_block_impl_0(
                        &__ArcClass__TestArc_block_func_0, 
                        & __ArcClass__TestArc_block_desc_0_DATA, 
                        age
                        );
// block调用
block->FuncPtr(block);

```

我们可以看到block是指向__ArcClass__TestArc_block_impl_0对象的指针，结构体__ArcClass__TestArc_block_impl_0定义如下：

```
struct __ArcClass__TestArc_block_impl_0 {
  struct __block_impl impl;
  struct __ArcClass__TestArc_block_desc_0* Desc;
  int age;
  __ArcClass__TestArc_block_impl_0(void *fp, struct __ArcClass__TestArc_block_desc_0 *desc, int _age, int flags=0) : age(_age) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};

```

该结构体把age直接赋值给了_age,执行的是拷贝操作。

*   结构体中第一个成员变量是struct __block_impl impl;

```
struct __block_impl {
      void *isa;
      int Flags;
      int Reserved;
      void *FuncPtr;
};       

```

__block_impl 的成员变量isa代表了该block属于啥类型，本例中为_NSConcreteStackBlock ，FuncPtr代表block的调用方法，本例中为__ArcClass__TestArc_block_func_0

*   第二个成员变量是struct __ArcClass__TestArc_block_desc_0* Desc;

```
static struct __ArcClass__TestArc_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __ArcClass__TestArc_block_desc_0_DATA = { 0, sizeof(struct __ArcClass__TestArc_block_impl_0)};

```

desc描述了__ArcClass__TestArc_block_impl_0的大小

*   结构体中第三个是成员变量age
    该结构体把age直接赋值给了_age,执行的是拷贝操作。

*   block调用实际上执行的是__ArcClass__TestArc_block_func_0方法
    下面为 block方法代码NSLog(@"age is %d",age);的实现

```
static void __ArcClass__TestArc_block_func_0(struct __ArcClass__TestArc_block_impl_0 *__cself) {

//这里访问age是bound by copy ，即拷贝。
  int age = __cself->age; // bound by copy 
         NSLog((NSString *)&__NSConstantStringImpl__var_folders_x0_cw796jjd255431nlsdwjt9840000gn_T_ArcClass_6c36ef_mi_0,age);
     }

```

从上面的分析可以看到，定义一个block的时候，底层生成了一个代表block的结构体__ArcClass__TestArc_block_impl_0，该结构体有一个__block_impl类型的impl成员变量和代表捕获变量的成员变量。其中impl的isa 代表了block的类型，FuncPtr代表了block的实际调用方法，该方法的参数为__ArcClass__TestArc_block_impl_0。

## 变量捕获

可以按照上面分析思路，得出结论

| 变量类型 | 捕获到block内部 | 变量类型 |
| --- | --- | --- |
| 局部非OC变量 | √ | 值传递 |
| 局部变量 static、OC对象 | √ | 指针传递 |
| 全局变量 | × | 直接访问 |

可以看到全局变量，b
lock内部不会直接捕获，其他变量会捕获。

# __block变量

## __block作用

*   __block只能修饰非静态局部变量，不能修饰静态变量和全局变量，否则编译器报错。
*   当需要在block内部修改一个局部变量时，需要加__block ,否则，编译不过。下面的代码，编译报错：Variable is not assignable (missing __block type specifier)。加上__block编译通过，name会变成lbj

```
 NSString* name = @"akon";
    void (^block)(void) =  ^{
        name = @"lbj";
     };

    block();

```

## 底层实现

*   类似刚才的转成cpp思路，分析得出结论如下图。总结就是对于__block变量，底层会封装成一个对象，其中通过__forwarding指向自己，来访问真实的变量。
    ![image](https://upload-images.jianshu.io/upload_images/22877992-0fb09113c7ebc460.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

*   为什么要通过__forwarding访问？
    这是因为，如果__block变量在栈上，就可以直接访问，但是如果已经拷贝到了堆上，访问的时候，还去访问栈上的，就会出问题，所以，先根据__forwarding找到堆上的地址，然后再取值

# 循环引用

## 循环引用原因

当对象A和对象B互相引用时会造成循环引用。

## 循环引用解决方案

竟然对象A和对象B互相引用会造成循环引用，那就要断开这个循环引用，可以通过__weak或者__unsafe_unretained，这两者的区别是__unsafe_unretained当引用对象变为nil时__unsafe_unretained对象不会自动置为nil，导致变为野指针，再次使用会崩溃。

### 常见循环引用及解决

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

注意有的时候我们会在block里面写成__strong typeof(weakSelf) strongSelf = weakSelf，然后再用strongSelf调用方案，这样做的原因是防止在block执行过程中weakSelf突然变成nil。
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

### 怎么检测循环引用

*   静态代码分析。 通过Xcode->Product->Anaylze分析结果来处理；
*   动态分析。用[MLeaksFinder](https://github.com/Tencent/MLeaksFinder)（只能检测OC泄露）或者Instrument或者[OOMDetector](https://github.com/Tencent/OOMDetector)（能检测OC与C++泄露）。

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
