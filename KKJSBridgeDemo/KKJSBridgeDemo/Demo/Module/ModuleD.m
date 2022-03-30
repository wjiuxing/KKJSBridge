//
//  ModuleD.m
//  KKJSBridgeDemo
//
//  Created by wjx on 2020/2/27.
//  Copyright © 2020 karosli. All rights reserved.
//

#import "ModuleD.h"
#import <KKJSBridge/KKJSBridge.h>
#import <KKJSBridge/KKJSBridgeMessage.h>
#import <objc/message.h>
#import "KKJSBridgeMessageSignature.h"
#import "KKJSBridgeLogger.h"

@interface ModuleD() <KKJSBridgeModule>

@end

@implementation ModuleD

+ (nonnull NSString *)moduleName
{
    return @"d";
}

+ (nonnull NSDictionary<NSString *, NSString *> *)methodInvokeMapper
{
    return @{@"fuck": @"d.raped"};
}

/// 将  {0: 'someTitle', 1: 'someUrl} 转成 {title: 'someTitle', url: 'someUrl'}，这里给强迫癌晚期患者提供一个方法签名。
- (BOOL)fixParametersIfNeededForMethod:(NSString *)method message:(KKJSBridgeMessage *)message;
{
    SEL getter = NSSelectorFromString(method);
    if (![self.class respondsToSelector:getter]) {
        // 有 callback 的是同步交互，如果此交互没有实现方法签名，默认为不需要同步返回结果，应尽早释放 callback
        if (nil != message.callback) {
            message.callback(nil);
            message.callback = nil;
        }
        return YES;
    }
    
    KKJSBridgeMessageSignature *signature = ((KKJSBridgeMessageSignature *(*)(id, SEL))objc_msgSend)(self.class, getter);
    
    // 同步交互，且不要求同步返回结果的，尽早消耗掉 callback，能尽早结束 IPC，
    // 避免出现 [IPC] Connection::waitForSyncReply: Timed-out while waiting for reply, id = xx
    if (nil != message.callback
        && !signature.resultReturnedByCallback) {
        message.callback(nil);
        message.callback = nil;
    }
    
    // 验证 self.context.delegate 是否实现 signature.delegateSEL
    // 如果 signature.delegateSEL 不为空且 self.context.delegate 没有实现，那么就没有必要继续派发
    BOOL delegateIsReady = YES;
    if (nil != signature.delegateSEL) {
        if ([self respondsToSelector:@selector(context)]) {
            id context = ((id (*)(id, SEL))objc_msgSend)(self, @selector(context));
            if ([context respondsToSelector:@selector(delegate)]) {
                id delegate = ((id (*)(id, SEL))objc_msgSend)(context, @selector(delegate));
                delegateIsReady = [delegate respondsToSelector:signature.delegateSEL];
            } else {
                delegateIsReady = NO;
            }
        } else {
            delegateIsReady = NO;
        }
    }
    
    if (!delegateIsReady) {
        NSString *log = [@"find delegate does not implementation SEL: " stringByAppendingFormat:@" %@ but Receive", NSStringFromSelector(signature.delegateSEL)];
        [KKJSBridgeLogger log:log module:self.class.moduleName method:method data:message.data];
        
        if (nil != message.callback) {
            message.callback(nil);
            message.callback = nil;
        }
        
        return NO;
    }
    
    NSDictionary *params = message.data;
    if (0 == params.count
        || 0 == signature.parameters.count) {
        return YES;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [signature.parameters enumerateObjectsUsingBlock:^(KKJSBridgeMessageSignatureParameter * _Nonnull parameter, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *fuckKey = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        id value = params[fuckKey];
        if (parameter.JSON) {
            NSError *error = nil;
            id tmp = [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
            if (nil != tmp && nil == error) {
                value = tmp;
            }
        }
        parameters[parameter.name] = value;
    }];
    
    message.data = parameters;
    
    return YES;
}

/// 以索引为 key 传来的 JOSN，这感觉就像被强奸了一样。
/// 取 raped:params:responseCallback: 方法的第一标签做为 getter 方法的名字，返回方法签名。
+ (KKJSBridgeMessageSignature *)raped
{
    return [KKJSBridgeMessageSignature signatureWithParameters:@[
        [KKJSBridgeMessageSignatureParameter parameterWithName:@"title"],
        [KKJSBridgeMessageSignatureParameter parameterWithName:@"content"],
        [KKJSBridgeMessageSignatureParameter parameterWithName:@"url"],
        [KKJSBridgeMessageSignatureParameter parameterWithName:@"userInfo" JSON:YES],
        [KKJSBridgeMessageSignatureParameter parameterWithName:@"array" JSON:YES]
    ] resultReturnedByCallback:YES];
}

- (void)raped:(KKJSBridgeEngine *)engine params:(NSDictionary *)params responseCallback:(void (^)(NSDictionary *responseData))responseCallback
{
    nil == responseCallback ?: responseCallback(params);
}

@end
