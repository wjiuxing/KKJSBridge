//
//  KKJSBridgeMessageDispatcher.m
//  KKJSBridge
//
//  Created by karos li on 2019/7/22.
//  Copyright © 2019 karosli. All rights reserved.
//

#import "KKJSBridgeMessageDispatcher.h"
#import <objc/message.h>
#import "KKJSBridgeJSExecutor.h"
#import "KKJSBridgeEngine.h"
#import "KKJSBridgeMessage.h"
#import "KKJSBridgeModuleRegister.h"
#import "KKJSBridgeLogger.h"

typedef void (^KKJSBridgeMessageCallback)(NSDictionary *responseData);

@interface KKJSBridgeMessageDispatcher()

@property (nonatomic, weak) KKJSBridgeEngine *engine;

@end

@implementation KKJSBridgeMessageDispatcher

- (instancetype)initWithEngine:(KKJSBridgeEngine *)engine {
    if (self = [super init]) {
        _engine = engine;
    }
    
    return self;
}

- (KKJSBridgeMessage *)convertMessageFromMessageJson:(NSDictionary *)json {
    KKJSBridgeMessage *message = [KKJSBridgeMessage new];
    message.module = json[@"module"];
    message.method = json[@"method"];
    message.data = json[@"data"];
    message.callbackId = json[@"callbackId"];
    message.callback = json[@"callback"];
    
    return message;
}

- (void)dispatchCallbackMessage:(KKJSBridgeMessage *)message {
    // 收到消息表示已经准备好了
    if (!self.engine.bridgeReady) {
        self.engine.bridgeReady = YES;
        if (self.engine.bridgeReadyCallback) {
            self.engine.bridgeReadyCallback(self.engine);
        }
    }
    
    NSString *moduleName = message.module;
    NSString *methodName = message.method;
    if (!moduleName || !methodName) {
#ifdef DEBUG
        NSLog(@"KKJSBridge Error: module or method is not found");
#endif
        return;
    }
    
    KKJSBridgeModuleMetaClass *metaClass = [self.engine.moduleRegister getModuleMetaClassByModuleName:moduleName];
    if (!metaClass) {
#ifdef DEBUG
        NSLog(@"KKJSBridge Error: module %@ is not registered", moduleName);
#endif
        return;
    }
    
    Class nativeClass = metaClass.moduleClass;
    Class<KKJSBridgeModule> moduleClass = nativeClass;
    
    // 方法调用映射，只做一层映射，不会递归处理
    if ([moduleClass respondsToSelector:@selector(methodInvokeMapper)]) {
        NSDictionary *methodMapper = [moduleClass methodInvokeMapper];
        NSString *value = methodMapper[methodName];
        if ([value containsString:@"."]) {
            NSArray<NSString *> *components = [value componentsSeparatedByString:@"."];
            if (components.count == 2) {
                if (components.firstObject.length > 0) {
                    moduleName = components.firstObject;
                    
                    metaClass = [self.engine.moduleRegister getModuleMetaClassByModuleName:moduleName];
                    if (!metaClass) {
#ifdef DEBUG
                        NSLog(@"KKJSBridge Error: module %@ is not registered", moduleName);
#endif
                        return;
                    }
                    
                    nativeClass = metaClass.moduleClass;
                    moduleClass = nativeClass;
                }
                
                methodName = components[1];
            }
        } else if (value.length > 0) {
            methodName = value;
        }
    }
    
    // 模块初始化
    id instance = [self.engine.moduleRegister generateInstanceFromMetaClass:metaClass];
    if (nil == instance) {
        return;
    }
    
    // 模块方法调用与回调处理
    NSString *apiMethodName = [NSString stringWithFormat:@"%@:params:responseCallback:", methodName];
    SEL apiMethodNameSEL = NSSelectorFromString(apiMethodName);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([instance respondsToSelector:apiMethodNameSEL]) { // 在调用实际 API
        SEL fixSEL = @selector(fixParametersIfNeededForMethod:message:);
        if ([instance respondsToSelector:fixSEL]) {
            BOOL executable = ((BOOL *(*)(id, SEL, NSString *, KKJSBridgeMessage *))objc_msgSend)(instance, fixSEL, methodName, message);
            if (!executable) {
                return;
            }
        }
        
        KKJSBridgeMessageCallback callback = nil;
        if (message.callbackId) { // 当存在 callback 时，才需要把处理结果交给 H5
            callback = ^(NSDictionary *responseData) {
                KKJSBridgeMessage *callbackMessageResponse = [KKJSBridgeMessage new];
                callbackMessageResponse.messageType = KKJSBridgeMessageTypeCallback;
                callbackMessageResponse.callbackId = message.callbackId;
                callbackMessageResponse.data = responseData;
                [KKJSBridgeLogger log:@"Send out" module:moduleName method:methodName data:responseData];
                [self dispatchMessageResponse:callbackMessageResponse];
            };
        } else if (message.callback) {
            callback = message.callback;
        }
        
        NSDictionary *params = message.data;
        [KKJSBridgeLogger log:@"Receive" module:moduleName method:methodName data:params];
        
        dispatch_block_t operation = ^{
            CFTimeInterval start = CFAbsoluteTimeGetCurrent();
            ((void (*)(id, SEL, KKJSBridgeEngine *, NSDictionary *, KKJSBridgeMessageCallback))objc_msgSend)(instance, apiMethodNameSEL, self.engine, params, callback);
#ifdef DEBUG
            CFTimeInterval end = CFAbsoluteTimeGetCurrent();
            CFTimeInterval duration = (end - start) * 1000.0;
            if (duration > 16) {
                NSLog(@"KKJSBridge Warnning: %@:%@ took '%f' ms.", moduleName, methodName, duration);
            }
#endif
        };
        
        // 获取方法调用 Queue
        NSOperationQueue *methodInvokeQueue;
        if ([instance respondsToSelector:@selector(methodInvokeQueue)]) {
            methodInvokeQueue = [instance methodInvokeQueue];
        }
        
        if (nil == methodInvokeQueue) {
            operation();
        } else {
            [methodInvokeQueue addOperationWithBlock:operation];
        }
    } else {
#ifdef DEBUG
        NSLog(@"KKJSBridge Error: method %@ is not defined in module %@", methodName, moduleName);
#endif
    }
#pragma clang diagnostic pop
}

- (void)dispatchEventMessage:(NSString *)eventName data:(NSDictionary * _Nullable)data {
    KKJSBridgeMessage *eventMessageResponse = [KKJSBridgeMessage new];
    eventMessageResponse.messageType = KKJSBridgeMessageTypeEvent;
    eventMessageResponse.eventName = eventName;
    eventMessageResponse.data = data;
    [KKJSBridgeLogger log:@"dispatch event" module:nil method:eventName data:data];
    [self dispatchMessageResponse:eventMessageResponse];
}

- (void)dispatchMessageResponse:(KKJSBridgeMessage *)message {
    NSMutableDictionary *messageJson = [NSMutableDictionary dictionary];
    messageJson[@"messageType"] = message.messageType == KKJSBridgeMessageTypeCallback ? @"callback" : @"event";
    messageJson[@"callbackId"] = message.callbackId;
    messageJson[@"eventName"] = message.eventName;
    messageJson[@"data"] = message.data;
    
    [KKJSBridgeJSExecutor evaluateJavaScriptFunction:@"window.KKJSBridge._handleMessageFromNative" withJson:messageJson inWebView:self.engine.webView completionHandler:^(id _Nullable result, NSError * _Nullable error) {
#ifdef DEBUG
        if (error) {
            NSLog(@"KKJSBridge Error: evaluate JavaScript error %@", error);
        }
#endif
    }];
}

@end
