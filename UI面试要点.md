# 事件分发机制及响应者链

## 事件分发机制

iOS 检测到手指触摸 (Touch) 操作时会将其打包成一个 UIEvent 对象，并放入当前活动Application的事件队列，UIApplication 会从事件队列中取出触摸事件并传递给单例的 UIWindow 来处理，UIWindow 对象首先会使用 hitTest:withEvent:方法寻找此次Touch操作初始点所在的视图(View)，即需要将触摸事件传递给其处理的视图，这个过程称之为 hit-test view。
hitTest:withEvent:方法的处理流程如下:

*   首先调用当前视图的 pointInside:withEvent: 方法判断触摸点是否在当前视图内；
*   若返回 NO, 则 hitTest:withEvent: 返回 nil，若返回 YES, 则向当前视图的所有子视图 (subviews) 发送 hitTest:withEvent: 消息，所有子视图的遍历顺序是从最顶层视图一直到到最底层视图（后加入的先遍历），直到有子视图返回非空对象或者全部子视图遍历完毕；
*   若第一次有子视图返回非空对象，则 hitTest:withEvent: 方法返回此对象，处理结束；
*   如所有子视图都返回空，则 hitTest:withEvent: 方法返回自身 (self)。
    流程图如下：
    ![image](https://upload-images.jianshu.io/upload_images/22877992-3e8f1c8219c10fa1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 响应者链原理

iOS的事件分发机制是为了找到第一响应者，事件的处理机制叫做响应者链原理。
所有事件响应的类都是 UIResponder 的子类，响应者链是一个由不同对象组成的层次结构，其中的每个对象将依次获得响应事件消息的机会。当发生事件时，事件首先被发送给第一响应者，第一响应者往往是事件发生的视图，也就是用户触摸屏幕的地方。事件将沿着响应者链一直向下传递，直到被接受并做出处理。一般来说，第一响应者是个视图对象或者其子类对象，当其被触摸后事件被交由它处理，如果它不处理，就传递给它的父视图（superview）对象（如果存在）处理，如果没有父视图，事件就会被传递给它的视图控制器对象 ViewController（如果存在），接下来会沿着顶层视图（top view）到窗口（UIWindow 对象）再到程序（UIApplication 对象）。如果整个过程都没有响应这个事件，该事件就被丢弃。一般情况下，在响应者链中只要有对象处理事件，事件就停止传递。
一个典型的事件响应路线如下：
First Responser --> 父视图-->VC->The Window --> The Application --> nil（丢弃）
我们可以通过 [responder nextResponder] 找到当前 responder 的下一个 responder，持续这个过程到最后会找到 UIApplication 对象。

# VC生命周期

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

# 列表优化技巧

## cell重用

*   cell重用原理
    它的原理是，根据cell高度和tableView高度，确定界面上能显示几个cell。例如界面上只能显示5个cell，那么这5个cell都是单独创建的而不是根据重用标识符去缓存中找到的。当你开始滑动tableView时，第1个cell开始渐渐消失，第6个cell开始显示的时候，会创建第6个cell，而不是用第1个cell去显示在第6个cell位置，因为有可能第1个cell显示了一半，而第6个cell也显示了一半，这个时候第一个cell还没有被放入缓存中，缓存中没有可利用的cell。所以实际上创建了6个cell。当滑动tableView去显示第7个cell的时候，这时缓存中已经有第一个cell，那么系统会直接从缓存中拿出来而不是创建，这样就算有100个cell的数据需要显示，实际也只消耗6个cell的内存。
*   根据cell的布局差异用不同的重用ID来进行cell的重用。

## cell布局优化

*   cell布局嵌套不要过深，尽量一级。
*   在cell初始化的时候创建好子view，尽量不要动态调整子view。
*   尽量不要用约束。
*   减少view个数。多用drawRect绘制元素，替代用view显示。

## cell高度提前计算或者缓存

*   cell高度提前计算。比如在获取到model的时候提前计算好cell高度。
*   高度缓存。高度算好。可以用第三方开源库[UITableView-FDTemplateLayoutCell](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/)

## 局部更新

刷新列表的时候不要直接用reloadData。可以考虑局部更新。比如删除列表的某一行，可以调用deleteRowsAtIndexPathss删除这个cell，并且把该cell绑定的model从model数组删除。

## 按需加载

比如滚动不加载图片，停止滚动时候加载可见cell的图片。

## 避免离屏渲染

避免使用阴影、圆角、clearColor、alpha等造成离屏渲染的操作，考虑替代方案。

### 什么是离屏渲染？

如果要在显示屏上显示内容，我们至少需要一块与屏幕像素数据量一样大的frame buffer，作为像素数据存储区域，而这也是GPU存储渲染结果的地方。如果有时因为面临一些限制，无法把渲染结果直接写入frame buffer，而是先暂存在另外的内存区域，之后再写入frame buffer，那么这个过程被称之为离屏渲染。
![image](https://upload-images.jianshu.io/upload_images/22877992-f58e8a8dc7472ed6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

*   在 OpenGL 中，GPU 屏幕渲染有以下两种方式：
    一、On-Screen Rendering
    即当前屏幕渲染，在用于显示的屏幕缓冲区中进行，不需要额外创建新的缓存，也不需要开启新的上下文，所以性能较好，但是受到缓存大小限制等因素，一些复杂的操作无法完成。
    二、Off-Screen Rendering
    即离屏渲染，指的是在GPU的当前屏幕缓冲区外开辟新的缓冲区进行操作。
    相比于当前屏幕渲染，离屏渲染的代价是很高的，主要体现在如下两个方面：
    1、创建新的缓冲区
    2、上下文切换。离屏渲染的整个过程，需要多次切换上下文环境：先从当前屏幕切换到离屏，等待离屏渲染结束后，将离屏缓冲区的渲染结果显示到到屏幕上，这又需要将上下文环境从离屏切换到当前屏幕。
*   CPU 渲染和离屏渲染的区别
    由于GPU的浮点运算能力比CPU强，CPU渲染的效率可能不如离屏渲染。但如果仅仅是实现一个简单的效果，直接使用 CPU 渲染的效率又可能比离屏渲染好，毕竟普通的离屏渲染要涉及到缓冲区创建和上下文切换等耗时操作。对一些简单的绘制过程来说，这个过程有可能用CoreGraphics，全部用CPU来完成反而会比GPU做得更好。一个常见的 CPU 渲染的例子是：重写 drawRect 方法，并且使用任何 Core Graphics 的技术进行了绘制操作，就涉及到了 CPU 渲染。整个渲染过程由 CPU 在 App 内同步地完成，渲染得到的bitmap最后再交由GPU用于显示。总之，具体使用 CPU 渲染还是使用 GPU 离屏渲染更多的时候需要进行性能上的具体比较才可以。
*   iOS 9.0 之前UIimageView跟UIButton设置圆角都会触发离屏渲染。
    iOS 9.0 之后UIButton设置圆角会触发离屏渲染，而UIImageView里png图片设置圆角不会触发离屏渲染了，如果设置其他阴影效果之类的还是会触发离屏渲染的。

### 造成离屏渲染原因

*   shouldRasterize（光栅化）。
*   masks（遮罩）。
*   shadows（阴影）。
*   edge antialiasing（抗锯齿）。
*   group opacity（不透明）
*   clearColor、alpha等操作。

### 解决方案

*   clearColor可以通过直接设置颜色来解决。
*   alpha为0时候用hidden替换。
*   圆角、边框解决方案：1、UIBezierPath 2、使用Core Graphics为UIView加圆角 3、直接处理图片为圆角 4、后台处理圆角
*   阴影解决方案：shadowPath替换。
*   尝试开启CALayer.shouldRasterize。
*   对于不透明的View，设置opaque为YES，这样在绘制该View时，就不需要考虑被View覆盖的其他内容（尽量设置Cell的view为opaque，避免GPU对Cell下面的内容也进行绘制）

## 图片子线程预加载及预处理

*   图片子线程异步下载。
*   图片子线程处理。比如对于圆角图片，可以让后台传圆角图片，也可以在子线程生成圆角图片，也可以用UIBezierPath生成圆角；在子线程缩放图片然后加载到图片控件上。
*   图片按需下载。只下载显示的cell的图片。

## 异步绘制

*   在子线程绘制好内容，主线程更新。
*   考虑用 [texture](https://github.com/texturegroup/texture/)来做异步绘制。

## 分页加载

当有大量数据时采用分页加载。

参考资料：
[iOS 保持界面流畅的技巧](https://blog.ibireme.com/2015/11/12/smooth_user_interfaces_for_ios/)
# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
