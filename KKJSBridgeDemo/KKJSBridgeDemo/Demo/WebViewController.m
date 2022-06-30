//
//  WebViewController.m
//  KKJSBridge
//
//  Created by karos li on 2019/8/29.
//  Copyright © 2019 karosli. All rights reserved.
//

#import "WebViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <KKJSBridge/KKJSBridge.h>
#import "ModuleContext.h"
#import "ModuleA.h"
#import "ModuleB.h"
#import "ModuleC.h"
#import "ModuleDefault.h"

@interface WebViewController () <KKWebViewDelegate, WKUIDelegate>

@property (nonatomic, strong, readwrite) KKWebView *webView;
@property (nonatomic, copy, readwrite) NSString *url;
@property (nonatomic, strong) KKJSBridgeEngine *jsBridgeEngine;

@end

@implementation WebViewController

+ (void)load {
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [self prepareWebView];
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }];
}

+ (void)prepareWebView {
    // 预先缓存一个 webView
    [KKWebView configCustomUAWithType:KKWebViewConfigUATypeAppend UAString:@"KKJSBridge/1.0.0"];
    [[KKWebViewPool sharedInstance] makeWebViewConfiguration:^(WKWebViewConfiguration * _Nonnull configuration) {
        // 必须前置配置，否则会造成属性不生效的问题
        configuration.allowsInlineMediaPlayback = YES;
        configuration.preferences.minimumFontSize = 12;
    }];
    [[KKWebViewPool sharedInstance] enqueueWebViewWithClass:KKWebView.class];
    KKJSBridgeConfig.ajaxDelegateManager = (id<KKJSBridgeAjaxDelegateManager>)self; // 请求外部代理处理，可以借助 AFN 网络库来发送请求
}

- (void)dealloc {
    [[KKWebViewPool sharedInstance] enqueueWebView:self.webView];
    NSLog(@"WebViewController dealloc");
}

#pragma mark - 初始化
- (instancetype)initWithUrl:(NSString *)url {
    if (self = [super initWithNibName:nil bundle:nil]) {
        _url = [url copy];
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithUrl:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithUrl:nil];
}

- (void)commonInit {
    _webView = [[KKWebViewPool sharedInstance] dequeueWebViewWithClass:KKWebView.class webViewHolder:self];
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
    _jsBridgeEngine = [KKJSBridgeEngine bridgeForWebView:self.webView];
    _jsBridgeEngine.config.enableAjaxHook = YES;
    _jsBridgeEngine.bridgeReadyCallback = ^(KKJSBridgeEngine * _Nonnull engine) {
        NSString *event = @"customEvent";
        NSDictionary *data = @{
            @"action": @"testAction",
            @"data": @YES
        };
        [engine dispatchEvent:event data:data];
    };
    
    [self compatibleWebViewJavascriptBridge];
    [self registerModule];
    [self loadRequest];
}

- (void)compatibleWebViewJavascriptBridge {
    NSString *jsString = [[NSString alloc] initWithContentsOfFile:[[NSBundle bundleForClass:self.class] pathForResource:@"WebViewJavascriptBridge" ofType:@"js"] encoding:NSUTF8StringEncoding error:NULL];
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:jsString injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [self.webView.configuration.userContentController addUserScript:userScript];
}

- (void)registerModule {
    ModuleContext *context = [ModuleContext new];
    context.vc = self;
    context.scrollView = self.webView.scrollView;
    context.name = @"上下文";
    
    // 注册 默认模块
    [self.jsBridgeEngine.moduleRegister registerModuleClass:ModuleDefault.class];
    // 注册 模块A
    [self.jsBridgeEngine.moduleRegister registerModuleClass:ModuleA.class];
    // 注册 模块B 并带入上下文
    [self.jsBridgeEngine.moduleRegister registerModuleClass:ModuleB.class withContext:context];
    // 注册 模块C
    [self.jsBridgeEngine.moduleRegister registerModuleClass:ModuleC.class];
}

#pragma mark - KKJSBridgeAjaxDelegateManager
+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request callbackDelegate:(NSObject<KKJSBridgeAjaxDelegate> *)callbackDelegate {
    return [[self ajaxSesstionManager] dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        // 处理响应数据
        [callbackDelegate JSBridgeAjax:callbackDelegate didReceiveResponse:response];
        if ([responseObject isKindOfClass:NSData.class]) {
            [callbackDelegate JSBridgeAjax:callbackDelegate didReceiveData:responseObject];
        } else if ([responseObject isKindOfClass:NSDictionary.class]) {
            NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseObject options:0 error:nil];
            [callbackDelegate JSBridgeAjax:callbackDelegate didReceiveData:responseData];
        } else {
            NSData *responseData = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];
            [callbackDelegate JSBridgeAjax:callbackDelegate didReceiveData:responseData];
        }
        if (responseObject) {
            error = nil;
        }
        [callbackDelegate JSBridgeAjax:callbackDelegate didCompleteWithError:error];
    }];
}

+ (AFHTTPSessionManager *)ajaxSesstionManager {
    static AFHTTPSessionManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        instance.requestSerializer = [AFHTTPRequestSerializer serializer];
        instance.responseSerializer = [AFHTTPResponseSerializer serializer];
    });
    
    return instance;
}

#pragma mark - 声明周期
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    /*
     解决调用系统相机等产生白屏，导致内存紧张，WebContent Process 被系统挂起，此时不会执行webViewWebContentProcessDidTerminate:函数
     */
    if (!self.webView.title) {
        [self.webView reload];
    }
}

#pragma mark - 安装视图
- (void)setupView {
    if (@available(iOS 11.0, *)) {
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"<返回" style:UIBarButtonItemStyleDone target:self action:@selector(onClickBack)];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.webView];
    self.webView.frame = [UIScreen mainScreen].bounds;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSMutableArray *constraints = [NSMutableArray array];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    if (@available(iOS 11.0, *)) {
        [constraints addObject:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    } else {
        [constraints addObject:[NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.topLayoutGuide attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    }
    [self.view addConstraints:constraints];
}

- (void)onClickBack {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - 请求
- (void)loadRequest {
    if (!self.url) {
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.url]];
    [self.webView loadRequest:request];
}

#pragma mark - WKNavigationDelegate
// 在发送请求之前，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if ([navigationAction.request.URL.absoluteString containsString:@"https://__bridge_loaded__"]) {// 防止 WebViewJavascriptBridge 注入
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
   
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 页面跳转完成时调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    self.navigationItem.title = webView.title;
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    /*
     解决内存过大引起的白屏问题
     */
    [self.webView reload];
}


#pragma mark -
#pragma mark WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"这是一个来自VC的弹框" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
        completionHandler();
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
