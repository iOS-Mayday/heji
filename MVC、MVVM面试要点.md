# MVC

MVC

## 定义

MVC模式（Model–View–Controller）是软件工程中的一种软件架构模式，把软件系统分为三个基本部分：模型（Model）、视图（View）和控制器（Controller）。
在iOS中，MVC通信模式如下所示：
![](https://upload-images.jianshu.io/upload_images/22877992-2110caa320a00a75.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


*   VC持有Model和View，Model和View不直接交互。
*   当用户点击View时，通知VC，需要更新Model时由VC来更新Model。
*   当Model发生变化时候，利用KVO等技术通知VC，由VC来更新View。

## Massive ViewController

如果我们把所有的业务逻辑都写在VC里面，不做好拆分，很容易造成VC臃肿。这个时候需要为VC瘦身，而MVVM就是为了解决VC过于庞大引入的设计模式。

## 怎么为VC瘦身

1、一个干净的VC应该只做如下事：

*   在初始化时，构造相应的 View 和 Model。
*   监听 Model 层的事件，将 Model 层的数据传递到 View 层。
*   监听 View 层的事件，并且将 View 层的事件转发到 Model 层。
*   其他的事情可以由若干个Manager来完成。

2、那么在iOS中，我们有那些常用的瘦身手段呢？

*   网络层。定义网络请求类 ，一个网络请求代表一个类。网络请求类负责发网络请求以及把响应数据解析为model，model以及response通过block方式回调给调用方。这里的调用方大部分时候是VC。
*   数据存储层。定义数据存储Manager，用来加载数据和缓存数据。
*   定义数据转换层。负责数据转换，比如Model跟View Model的转换。
*   可以通过类别的方式给VC做好功能的划分，比如定义TableView分类用来处理UITableViewDelegate && UITableViewDataSource代理方法；定义Network分类用来处理网络逻辑。

推荐大家每个业务模块至少建立Model、View、VC、Network、Cache五个文件夹来分类代码，并且遵循上面原则来给VC瘦身。

# MVVM

## 定义

![](https://upload-images.jianshu.io/upload_images/22877992-b16875587e6e47c7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


*   View、VC可以持有View Model，反之不行；View Model可以持有Model，反之不行。 View Model相当于MVC中的VC作用，用来连接View、VC 和Model。
*   当Model更新时，通知View Model，View Model再通知VC或者View，来更新View；
*   当用户点击View时候，通知View Model，View Model通知Model来更新Model。

## 应用

实现MVVM的关键是如何做数据通知，在iOS中可以用KVO来实现。业内一般用ReactiveCocoa来实现数据绑定及通知。

# 选择MVC还是MVVM？

无论是MVC还是MVVM，我们的本质都是想对VC进行瘦身。
用MVVM的话，分层更加清晰，不过要引入ReactiveCocoa，ReactiveCocoa比较重，学习成本比较高，最重要的是用的是block，调试起来比较麻烦，目前业内用得不是特别多。
笔者推荐用MVC，按照上面介绍的VC瘦身方案来使用，这样轻量点。

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
