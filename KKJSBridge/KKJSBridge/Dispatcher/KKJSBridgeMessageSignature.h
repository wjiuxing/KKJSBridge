//
//  KKJSBridgeMessageSignature.h
//  KKJSBridgeDemo
//
//  Created by wjx on 2020/9/27.
//  Copyright © 2020 karosli. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KKJSBridgeMessageSignatureParameter : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL JSON;

+ (instancetype)parameterWithName:(NSString *)name;
+ (instancetype)parameterWithName:(NSString *)name JSON:(BOOL)JSON;

@end

@interface KKJSBridgeMessageSignature : NSObject

@property (nonatomic, copy) NSArray<KKJSBridgeMessageSignatureParameter *> *parameters;

/// 代理需要实现的方法，如果不实现，那么此次 JS-Native 交互消息将不被派发，
/// 与 resultReturnedByCallback 和 callbackFunctionCanBeUsedAsJSParameter 互斥。
/// 即，如果 resultReturnedByCallback 或者 callbackFunctionCanBeUsedAsJSParameter 为 YES，不应该设置 delegateSEL
/// 因为 JS 端线程还在等待回调才能继续执行。
@property (nonatomic, assign) SEL delegateSEL;

/// 通过回调返回结果
@property (nonatomic, assign) BOOL resultReturnedByCallback;

/// 支持 JS 端回调方法参数化
@property (nonatomic, assign) BOOL callbackFunctionCanBeUsedAsJSParameter;

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters;
+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
               resultReturnedByCallback:(BOOL)resultReturnedByCallback;

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
               resultReturnedByCallback:(BOOL)resultReturnedByCallback
 callbackFunctionCanBeUsedAsJSParameter:(BOOL)callbackFunctionCanBeUsedAsJSParameter;

+ (instancetype)signatureWithDelegateSEL:(SEL)delegateSEL;

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
                            delegateSEL:(SEL)delegateSEL;

@end

NS_ASSUME_NONNULL_END
