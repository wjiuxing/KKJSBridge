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
+ (void)fixParamtersForMethod:(NSString *)method message:(KKJSBridgeMessage *)message
{
    SEL getter = NSSelectorFromString(method);
    if (![self respondsToSelector:getter]) {
        // 有 callback 的是同步交互，如果此交互没有实现方法签名，默认为不需要同步返回结果，应尽早释放 callback
        if (nil != message.callback) {
            message.callback(nil);
            message.callback = nil;
        }
        return;
    }
    
    KKJSBridgeMessageSignature *signature = ((KKJSBridgeMessageSignature *(*)(id, SEL))objc_msgSend)(self, getter);
    
    // 同步交互，且不要求同步返回结果的，尽早消耗掉 callback，能尽早结束 IPC，
    // 避免出现 [IPC] Connection::waitForSyncReply: Timed-out while waiting for reply, id = xx
    if (nil != message.callback
        && (nil == signature
            || !signature.requiredResultBySyncCallback)) {
        message.callback(nil);
        message.callback = nil;
    }
    
    NSDictionary *params = message.data;
    if (0 == params.count
        || nil == signature
        || 0 == signature.paramters.count) {
        return;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [signature.paramters enumerateObjectsUsingBlock:^(KKJSBridgeMessageSignatureParamter * _Nonnull paramter, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *fuckKey = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        id value = params[fuckKey];
        if (paramter.JSON) {
            NSError *error = nil;
            id tmp = [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&error];
            if (nil != tmp && nil == error) {
                value = tmp;
            }
        }
        parameters[paramter.name] = value;
    }];
    
    message.data = parameters;
}

/// 以索引为 key 传来的 JOSN，这感觉就像被强奸了一样。
/// 取 raped:params:responseCallback: 方法的第一标签做为 getter 方法的名字，返回方法签名。
+ (KKJSBridgeMessageSignature *)raped
{
    return [KKJSBridgeMessageSignature signatureWithParamters:@[
        [KKJSBridgeMessageSignatureParamter parameterWithName:@"title"],
        [KKJSBridgeMessageSignatureParamter parameterWithName:@"content"],
        [KKJSBridgeMessageSignatureParamter parameterWithName:@"url"],
        [KKJSBridgeMessageSignatureParamter parameterWithName:@"userInfo" JSON:YES],
        [KKJSBridgeMessageSignatureParamter parameterWithName:@"array" JSON:YES]
    ] requiredResultBySyncCallback:YES];
}

- (void)raped:(KKJSBridgeEngine *)engine params:(NSDictionary *)params responseCallback:(void (^)(NSDictionary *responseData))responseCallback
{
    nil == responseCallback ?: responseCallback(params);
}

@end
