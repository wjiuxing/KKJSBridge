//
//  KKJSBridgeConfig.m
//  KKJSBridge
//
//  Created by karos li on 2019/7/25.
//  Copyright © 2019 karosli. All rights reserved.
//

#import "KKJSBridgeConfig.h"
#import "KKJSBridgeJSExecutor.h"
#import "KKJSBridgeEngine.h"

#if defined (KKUnity) || defined (KKAjaxProtocolHook)
#import "NSURLProtocol+KKJSBridgeWKWebView.h"
#endif

static id<KKJSBridgeAjaxDelegateManager> globalAjaxDelegateManager;

@interface KKJSBridgeConfig()

@property (nonatomic, weak) KKJSBridgeEngine *engine;

@end

@implementation KKJSBridgeConfig

- (instancetype)initWithEngine:(KKJSBridgeEngine *)engine {
    if (self = [super init]) {
        _engine = engine;
        _enableCookieSetHook = YES;
        _enableCookieGetHook = YES;
    }
    
    return self;
}

#pragma mark - public
- (void)setEnableAjaxHook:(BOOL)enableAjaxHook {
    _enableAjaxHook = enableAjaxHook;
    
#ifdef KKUnity
    switch (KKJSBridgeConfig.program) {
        case KKWebViewProgramAjaxProtocolHook: {
            if (enableAjaxHook) {
                [NSURLProtocol KKJSBridgeRegisterScheme:@"https"];
                [NSURLProtocol KKJSBridgeRegisterScheme:@"http"];
                [_customSchemes enumerateObjectsUsingBlock:^(NSString * _Nonnull scheme, NSUInteger idx, BOOL * _Nonnull stop) {
                    [NSURLProtocol KKJSBridgeRegisterScheme:scheme];
                }];
            } else {
                [NSURLProtocol KKJSBridgeUnregisterScheme:@"https"];
                [NSURLProtocol KKJSBridgeUnregisterScheme:@"http"];
                [_customSchemes enumerateObjectsUsingBlock:^(NSString * _Nonnull scheme, NSUInteger idx, BOOL * _Nonnull stop) {
                    [NSURLProtocol KKJSBridgeUnregisterScheme:scheme];
                }];
            }
        } break;
            
        default:
            break;
    }
#elifdef KKAjaxProtocolHook
    if (enableAjaxHook) {
        [NSURLProtocol KKJSBridgeRegisterScheme:@"https"];
        [NSURLProtocol KKJSBridgeRegisterScheme:@"http"];
    } else {
        [NSURLProtocol KKJSBridgeUnregisterScheme:@"https"];
        [NSURLProtocol KKJSBridgeUnregisterScheme:@"http"];
    }
#endif
    
    NSString *script = [NSString stringWithFormat:@"window.KKJSBridgeConfig.enableAjaxHook(%@)", [NSNumber numberWithBool:enableAjaxHook]];
    [self evaluateConfigScript:script];
}

- (void)setEnableCookieSetHook:(BOOL)enableCookieSetHook {
    _enableCookieSetHook = enableCookieSetHook;
    
    NSString *script = [NSString stringWithFormat:@"window.KKJSBridgeConfig.enableCookieSetHook(%@)", [NSNumber numberWithBool:enableCookieSetHook]];
    [self evaluateConfigScript:script];
}

- (void)setEnableCookieGetHook:(BOOL)enableCookieGetHook {
    _enableCookieGetHook = enableCookieGetHook;
    
    NSString *script = [NSString stringWithFormat:@"window.KKJSBridgeConfig.enableCookieGetHook(%@)", [NSNumber numberWithBool:enableCookieGetHook]];
    [self evaluateConfigScript:script];
}

#pragma mark - public static
+ (void)setAjaxDelegateManager:(id<KKJSBridgeAjaxDelegateManager>)ajaxDelegateManager {
    globalAjaxDelegateManager = ajaxDelegateManager;
}

+ (id<KKJSBridgeAjaxDelegateManager>)ajaxDelegateManager {
    return globalAjaxDelegateManager;
}

static NSArray<Class> *_protocolClasses;
+ (NSArray<Class> *)protocolClasses
{
    return _protocolClasses;
}

+ (void)setProtocolClasses:(NSArray<Class> *)protocolClasses
{
    _protocolClasses = [protocolClasses copy];
}

static NSArray<NSString *> *_customSchemes;
+ (NSArray<NSString *> *)customSchemes
{
    return _customSchemes;
}

+ (void)setCustomSchemes:(NSArray<NSString *> *)customSchemes
{
    _customSchemes = [customSchemes copy];
}

#if defined (KKUnity) || defined (KKAjaxProtocolHook)
static KKWebViewProgram globalWebViewProgram = KKWebViewProgramAjaxProtocolHook;
#else
static KKWebViewProgram globalWebViewProgram = KKWebViewProgramAjaxHook;
#endif

+ (KKWebViewProgram)program
{
    return globalWebViewProgram;
}

+ (void)setProgram:(KKWebViewProgram)program
{
#ifdef KKUnity
    globalWebViewProgram = program;
#endif
}

static BOOL (^_synCallValidationBlock)(NSURL *);
+ (BOOL (^)(NSURL *))syncCallValidation
{
    return _synCallValidationBlock;
}

+ (void)setSyncCallValidation:(BOOL (^)(NSURL *))syncCallValidationBlock
{
    _synCallValidationBlock = syncCallValidationBlock;
}

#pragma mark - private
- (void)evaluateConfigScript:(NSString *)script {
    if (self.engine.isBridgeReady) {
        [KKJSBridgeJSExecutor evaluateJavaScript:script inWebView:self.engine.webView completionHandler:nil];
    } else {
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [self.engine.webView.configuration.userContentController addUserScript:userScript];
    }
}

@end

