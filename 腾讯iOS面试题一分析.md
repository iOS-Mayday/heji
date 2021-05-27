# 网络相关：
###1. 项目使用过哪些网络库？用过ASIHttp库嘛
AFNetworking、ASIHttpRequest、Alamofire(swift)
1、AFN的底层实现基于OC的NSURLConnection和NSURLSession
2、ASI的底层实现基于纯C语言的CFNetwork框架
3、因为NSURLConnection和NSURLSession是在CFNetwork之上的一层封装，因此ASI的运行性能高于AFN
### 2. 断点续传怎么实现的？
需要怎么设置断点续传就是从文件上次中断的地方开始重新下载或上传数据。要实现断点续传 , 服务器必须支持（这个很重要，一个巴掌是拍不响的，如果服务器不支持，那么客户端写的再好也没用）。总结：断点续传主要依赖于 HTTP 头部定义的 Range 来完成。有了 Range，应用可以通过 HTTP 请求获取失败的资源，从而来恢复下载该资源。当然并不是所有的服务器都支持 Range，但大多数服务器是可以的。Range 是以字节计算的，请求的时候不必给出结尾字节数，因为请求方并不一定知道资源的大小。
```
// 1 指定下载文件地址 URLString
 // 2 获取保存的文件路径 filePath
 // 3 创建 NSURLRequest
 NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLString]];
 unsigned long long downloadedBytes = 0;
 
 if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
 // 3.1 若之前下载过 , 则在 HTTP 请求头部加入 Range
  // 获取已下载文件的 size
  downloadedBytes = [self fileSizeForPath:filePath];
 
  // 验证是否下载过文件
  if (downloadedBytes > 0) {
    // 若下载过 , 断点续传的时候修改 HTTP 头部部分的 Range
    NSMutableURLRequest *mutableURLRequest = [request mutableCopy];
    NSString *requestRange =
    [NSString stringWithFormat:@"bytes=%llu-", downloadedBytes];
    [mutableURLRequest setValue:requestRange forHTTPHeaderField:@"Range"];
    request = mutableURLRequest;
  }
 }
 // 4 创建 AFHTTPRequestOperation
 AFHTTPRequestOperation *operation
 = [[AFHTTPRequestOperation alloc] initWithRequest:request];
 
 // 5 设置操作输出流 , 保存在第 2 步的文件中
 operation.outputStream = [NSOutputStream
 outputStreamToFileAtPath:filePath append:YES];
 
 // 6 设置下载进度处理 block
 [operation setDownloadProgressBlock:^(NSUInteger bytesRead,
 long long totalBytesRead, long long totalBytesExpectedToRead) {
 // bytesRead 当前读取的字节数
 // totalBytesRead 读取的总字节数 , 包含断点续传之前的
 // totalBytesExpectedToRead 文件总大小
 }];
 
 // 7 设置 success 和 failure 处理 block
 [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation
 *operation, id responseObject) {
 
 } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
 
 }];
 
 // 8 启动 operation
 [operation start];
```

### 3. HTTP请求 什么时候用post、get、put ？GET方法：对这个资源的查操作
- 1、GET参数通过URL传递，POST放在Request body中。
- 2、GET请求会被浏览器主动cache，而POST不会，除非手动设置。
- 3、GET请求参数会被完整保留在浏览器历史记录里，而POST中的参数不会被保留。
- 4、Get 请求中有非 ASCII 字符，会在请求之前进行转码，POST不用，因为POST在Request body中，通过 MIME，也就可以传输非 ASCII 字符。
- 5、 一般我们在浏览器输入一个网址访问网站都是GET请求
- 6、HTTP的底层是TCP/IP。HTTP只是个行为准则，而TCP才是GET和POST怎么实现的基本。GET/POST都是TCP链接。GET和POST能做的事情是一样一样的。但是请求的数据量太大对浏览器和服务器都是很大负担。所以业界有了不成文规定，（大多数）浏览器通常都会限制url长度在2K个字节，而（大多数）服务器最多处理64K大小的url。
- 7、GET产生一个TCP数据包；POST产生两个TCP数据包。对于GET方式的请求，浏览器会把http header和data一并发送出去，服务器响应200（返回数据）；而对于POST，浏览器先发送header，服务器响应100 continue，浏览器再发送data，服务器响应200 ok（返回数据）。
- 8、在网络环境好的情况下，发一次包的时间和发两次包的时间差别基本可以无视。而在网络环境差的情况下，两次包的TCP在验证数据包完整性上，有非常大的优点。但并不是所有浏览器都会在POST中发送两次包，Firefox就只发送一次。

PUT和POS都有更改指定URI的语义.但PUT被定义为idempotent的方法，POST则不是.idempotent的方法:如果一个方法重复执行

多次，产生的效果是一样的，那就是idempotent的。也就是说：
PUT请求：如果两个请求相同，后一个请求会把第一个请求覆盖掉。（所以PUT用来改资源）
Post请求：后一个请求不会把第一个请求覆盖掉。（所以Post用来增资源）
### 4. HTTP建立断开连接的时候为什么要 三次握手、四次挥手？
因为当Server端收到Client端的SYN连接请求报文后，可以直接发送SYN+ACK报文。其中ACK报文是用来应答的，SYN报文是用来同步的。
```
client请求连接，Serve发送确认连接，client回复确认连接 ==>连接建立
```
但是关闭连接时，当Server端收到FIN报文时，很可能并不会立即关闭SOCKET，所以只能先回复一个ACK报文，告诉Client端，"你发的FIN报文我收到了"。只有等到我Server端所有的报文都发送完了，我才能发送FIN报文，因此不能一起发送。故需要四步握手。
 注意：
client两个等待，FIN_Wait 和 Time_WaitTIME_WAIT状态需要经过2MSL(最大报文段生存时间)才能返回到CLOSE状态>。虽然按道理，四个报文都发送完毕，我们可以直接进入CLOSE状态了，但是我们必须假象网络是不可靠的，有可以最后一个ACK丢失。所以TIME_WAIT状态就是用来重发可能丢失的ACK报文。
`client请求断开，Server收到断开请求，server发送断开，client回复断开确认 ==>连接断`
### 5. 项目中的数据存储都有哪些，iOS中有哪些数据存储方法，什么时候用？
- 1、文件
- 2、NSUserDefaults
- 3、数据库4、KeyChain5、iCloud

文件

- 1、沙盒
- 2、Plist
- 3、NSKeyedArchiver归档 / NSKeyedUnarchiver解档

NSUserDefaults
数据库

- 1、SQLite3
- 2、FMDB
- 3、Core Data

### 6、MVVM如何实现绑定？

MVVM 的实现可以采用KVO进行数据绑定，也可以采用RAC。其实还可以采用block、代理（protocol）实现。
MVVM比起MVC最大的好处就是可以实现自动绑定，将数据绑定在UI组件上，当UI中的值发生变化时，那么它对应的模型中也跟随着发生变化，这就是双向绑定机制，原因在于它在视图层和数据模型层之间实现了一个绑定器，绑定器可以管理两个值，它一直监听组件UI的值，只要发生变化，它将会把值传输过去改变model中的值。绑定器比较灵活，还可以实现单向绑定。
实际开发中的做法：
- 1、让Controller拥有View和ViewModel属性，VM拥有Model属性；Controller或者View来接收ViewModel发送的Model改变的通知
-  2、用户的操作点击或者Controller的视图生命周期里面让ViewModel去执行请求，请求完成后ViewModel将返回数据模型化并保存，从而更新了Model；Controller和View是属于V部分，即实现V改变M（V绑定M）。如果不需要请求，这直接修改Model就是了。
-  3、第2步中的Model的改变，VM是知道的（因为持有关系），只需要Model改变后发一个通知；Controller或View接收到通知后（一般是Controller先接收再赋值给View），根据这个新Model去改变视图就完成了M改变V（M绑定V） 。使用RAC（RactiveCocoa）框架实现绑定可以简单到一句话概括：ViewModel中创建好请求的信号RACSignal, Controller中订阅这个信号，在ViewModel完成请求后订阅者调用sendNext:方法，Controller里面订阅时写的block就收到回调了。
###  7、block 和 通知的区别
通知： 
一对多
Block：
- 通常拿来OC中的block和swift中的闭包来比较.
- block注重的是过程
- block会开辟内存，消耗比较大，delegate则不会
- block防止循环引用，要用弱引用

Delegate：
代理注重的是过程，是一对一的，对于一个协议就只能用一个代理，更适用于多个回调方法（3个以上），block则适用于1，2个回调时

### 8、进程间通信方式？线程间通信？
- 1、URL scheme
 这个是iOS APP通信最常用到的通信方式，APP1通过openURL的方法跳转到APP2，并且在URL中带上想要的参数，有点类似HTTP的get请求那样进行参数传递。这种方式是使用最多的最常见的，使用方法也很简单只需要源APP1在info.plist中配置LSApplicationQueriesSchemes,指定目标App2的scheme；然后再目标App2的info.plist 中配置好URLtypes，表示该App接受何种URL scheme的唤起。
- 2、Keychain
 iOS 系统的keychain是一个安全的存储容器，它本质上就是一个sqlite数据库，它的位置存储在/private/var/Keychains/keychain-2.db,不过它索八坪村的所有数据都是经过加密的，可以用来为不同的APP保存敏感信息，比如用户名，密码等。iOS系统自己也用keychain来保存VPN凭证和WiFi密码。它是独立于每个APP的沙盒之外的，所以即使APP被删除之后，keychain里面的信息依然存在
###  3、UIPasteBoard
是剪切板功能，因为iOS 的原生空间UItextView，UItextfield，UIwebView ，我们在使用时如果长按，就回出现复制、剪切、选中、全选、粘贴等功能，这个就是利用系统剪切板功能来实现的。

### 4、UIDocumentInteractionController
 uidocumentinteractioncontroller 主要是用来实现同设备上APP之间的贡献文档，以及文档预览、打印、发邮件和复制等功能。
###  5、Local socket
 原理：一个APP1在本地的端口port1234 进行TCP的bind 和 listen，另外一个APP2在同一个端口port1234发起TCP的connect连接，这样就可以简历正常的TCP连接，进行TCP通信了，然后想传什么数据就可以传什么数据了
###  6、AirDrop
 通过 Airdrop实现不同设备的APP之间文档和数据的分享
###  7、UIActivityViewController
 iOS SDK 中封装好的类在APP之间发送数据、分享数据和操作数据
###  8、APP Groups
 APP group用于同一个开发团队开发的APP之间，包括APP和extension之间共享同一份读写空间，进行数据共享。同一个团队开发的多个应用之间如果能直接数据共享，大大提高用户体验
- 线程间通信的体现
1 .一个线程传递数据给另一个线程
2 .在一个线程中执行完特定任务后，转到另一个线程继续执行任务复制
- 代码线程间通信常用的方法
1. `NSThread`可以先将自己的当前线程对象注册到某个全局的对象中去，这样相互之间就可以获取对方的线程对象，然后就可以使用下面的方法进行线程间的通信了，由于主线程比较特殊，所以框架直接提供了在主线程执行的方法>
```
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;

- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(nullable id)arg 
waitUntilDone:(BOOL)wait NS_AVAILABLE(10_5, 2_0);
```
**2. `GCD`一个线程传递数据给另一个线程，如**
```
{   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSLog(@"donwload---%@", [NSThread currentThread]);
        
        // 1.子线程下载图片 //耗时操作
        NSURL *url = [NSURL URLWithString:@"http://d.jpg"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        UIImage *image = [UIImage imageWithData:data];
        
        // 2.回到主线程设置图片
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSLog(@"setting---%@ %@", [NSThread currentThread], image);
            
            [self.button setImage:image forState:UIControlStateNormal];
        });
    });
```
### 9、如何检测应用卡顿问题？
NSRunLoop调用方法主要就是在kCFRunLoopBeforeSources和kCFRunLoopBeforeWaiting之间,还有kCFRunLoopAfterWaiting之后,也就是如果我们发现这两个时间内耗时太长,那么就可以判定出此时主线程卡顿。
### 10、发布出去的版本，怎么收集crash ？不使用bugly等第三方怎么手机


# 资料推荐

如果你正在跳槽或者正准备跳槽不妨动动小手，添加一下咱们的交流群[931542608](https://jq.qq.com/?_wv=1027&k=0674hVXZ)来获取一份详细的大厂面试资料为你的跳槽多添一份保障。

![](https://upload-images.jianshu.io/upload_images/22877992-0bfc037cc50cae7d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
