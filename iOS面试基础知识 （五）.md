# 混编技术

移动开发已经进入大前端时代。对于混编技术，笔者一般在面试中也会问，通常会问h5混编、rn、weex、flutter等相关方面的问题，以考察面试者对于混编技术的了解程度。

## H5混编实现

相对于rn、weex等混编技术，在App里面内嵌H5实现成本较低，所以目前市面上H5混编仍是主流，笔者在面试中一般会问H5与App怎么通信。概括来说，主要有如下集中方式：

### 伪协议实现

伪协议指的是自己自定义的url协议，通过webview的代理拦截到url的加载，识别出伪协议，然后调用native的方法。伪协议可以这样定义：AKJS://functionName?param1=value1&param2=value2。 其中AKJS代表我们自己定义的协议，functionName代表要调用的App方法，?后面代表传入的参数。
一、UIWebView通过UIWebViewDelegate的代理方法-webView: shouldStartLoadWithRequest:navigationType:进行伪协议拦截。
二、WKWebView通过WKNavigationDelegate代理方法实现- webView:decidePolicyForNavigationAction:decisionHandler:进行伪协议拦截。
此种实现方式优点是简单。
缺点有：

*   由于url长度大小有限制，导致传参大小有限制，比如h5如果要传一个图片的base64字符串过来，这种方式就无能为力了。
*   需要在代理拦截方法里面写一系列if else处理，难以维护。
*   如果App要兼容UIWebView和WKWebView，需要有两套实现，难以维护。

### JSContext

为了解决伪协议实现的缺点，我们可以往webview里面注入OC对象，不过这种方案只能用于UIWebView中。此种方式的实现步骤如下：
一、在webViewDidFinishLoad方法中通过JSContext注入JS对象

```
self.jsContext = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
self.jsContext[@"AK_JSBridge"] = self.bridgeAdapter; //往JS中注入OC对象

```

二、OC对象实现JSExport协议，这样JS就可以调用OC对象的方法了

```
@interface AKBridgeAdapter : NSOject< JSExport >
- (void)getUID;  // 获取用户ID

```

此种方案的优点是JS可以直接调用对象的方法，通过提供对象这种方式，代码优雅；缺点是只能用于UIWebView、不能用于WKWebView。

### WKScriptMessageHandler

WKWebView可以通过提供实现了WKScriptMessageHandler协议的类来实现JS调用OC，实现步骤如下：
一、往webview注入OC对象。

```
[self.configuration.userContentController addScriptMessageHandler:self.adapter name:@"AK_JSBridge"]

```

二、实现- userContentController:didReceiveScriptMessage:获取方法调用名和参数

```
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dicMessage = message.body;

        NSString *funcName = [dicMessage stringForKey:@"funcName"];
        NSString *parameter = [dicMessage stringForKey:@"parameter"];
       //进行逻辑处理
    }
}

```

此种方案的优点是实现简单，缺点是不支持UIWebView。

### 第三方库WKWebViewJavascriptBridge

该库是iOS使用最广泛的JSBridge库，该库通过伪协议+JS消息队列实现了JS与OC交互，此种方案兼容UIWebView和WKWebView。

## RN、Weex、Flutter混编技术

RN（React Native）是facebook开发的跨三端（iOS、Android、H5）开源框架，目前在业界使用最广泛；Weex是阿里开源的类似RN的大前端开发框架，国内有些公司在使用；Flutter是Google开发的，作为后旗之秀，目前越来越流行。
笔者一般在面试中会问一下这类框架是怎么实现页面渲染，怎么实现调用OC的，以考察面试者是否了解框架实现原理。

# 组件化

任何一个对技术有追求的团队，都会做组件化，组件化的目标是模块解耦、代码复用。

## 组件代码管理方式

目前业内一般采用pod私有库的方式来管理自己的组件。

## 组件通信方式

### MGJRouter

[MGJRouter](https://github.com/meili/MGJRouter)通过注册url的方式来实现方法注册和调用

```
[MGJRouter registerURLPattern:@"mgj://category/travel" toHandler:^(NSDictionary *routerParameters) {
    NSLog(@"routerParameters[MGJRouterParameterUserInfo]:%@", routerParameters[MGJRouterParameterUserInfo]);
    // @{@"user_id": @1900}
}];

[MGJRouter openURL:@"mgj://category/travel" withUserInfo:@{@"user_id": @1900} completion:nil];

```

该种方案的缺点有：

*   url定义由于是字符串，有可能造成重复。
*   参数传入不能直接传model，而是需要传字典，如果方法实现方修改一个字段的类型但没有通知调用方，调用方无法直接知道，有可能导致崩溃。
*   通过字典传参不直观，调用方需要知道字段的名字才能获取字段值，如果字段名不定义为宏，到处拷贝字段名造成难以维护。

### CTMediator

[CTMediator](https://github.com/casatwy/CTMediator)通过CTMediator的类别来实现方法调用。
一、组件提供方实现Target、Action。

```
@interface Target_A : NSObject

- (UIViewController *)Action_nativeFetchDetailViewController:(NSDictionary *)params;

@end

- (UIViewController *)Action_nativeFetchDetailViewController:(NSDictionary *)params
{
    // 因为action是从属于ModuleA的，所以action直接可以使用ModuleA里的所有声明
    DemoModuleADetailViewController *viewController = [[DemoModuleADetailViewController alloc] init];
    viewController.valueLabel.text = params[@"key"];
    return viewController;
}

```

二、组件提供方实现CTMediator类别暴露接口给使用方。

```
@interface CTMediator (CTMediatorModuleAActions)

- (UIViewController *)CTMediator_viewControllerForDetail;

@end

- (UIViewController *)CTMediator_viewControllerForDetail
{
    UIViewController *viewController = [self performTarget:kCTMediatorTargetA
                                                    action:kCTMediatorActionNativFetchDetailViewController
                                                    params:@{@"key":@"value"}
                                         shouldCacheTarget:NO
                                        ];
    if ([viewController isKindOfClass:[UIViewController class]]) {
        // view controller 交付出去之后，可以由外界选择是push还是present
        return viewController;
    } else {
        // 这里处理异常场景，具体如何处理取决于产品
        return [[UIViewController alloc] init];
    }
}

```

此种方案的优点是通过Targrt-Action实现了组件之间的解耦，通过暴露方法给组件使用方，避免了url直接传递字典带来的问题。
缺点是：

*   CTMediator类别实现由于需要通过performTarget方式来实现，需要写一堆方法名、方法参数名字字符串，影响阅读；
*   没有组件管理器概念，组件直接的互相调用都是通过直接引用CTMediator类别来实现，没有实现真正的解耦。

### BeeHive

[BeeHive](https://github.com/alibaba/BeeHive)通过url来实现页面路由，通过Protocol来实现方法调用。
一、注册service

```
[[BeeHive shareInstance] registerService:@protocol(HomeServiceProtocol) service:[BHViewController class]];

```

二、调用service

```
id< HomeServiceProtocol > homeVc = [[BeeHive shareInstance] createService:@protocol(HomeServiceProtocol)];

// use homeVc do invocation

```

笔者推荐使用BeeHive这种方式来做组件化，基于Protocol（面向接口）的编程方式能让组件提供方清晰地提供接口声明给使用方；能充分利用编辑器特性，比如如果接口删除了一个参数，能通过编译器编不过来告诉调用方接口发生了变化。

# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[**1012951431**](https://links.jianshu.com/go?to=https%3A%2F%2Fjq.qq.com%2F%3F_wv%3D1027%26k%3D5JFjujE)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
