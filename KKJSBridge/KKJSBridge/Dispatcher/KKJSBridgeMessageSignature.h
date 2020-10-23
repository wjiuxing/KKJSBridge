//
//  KKJSBridgeMessageSignature.h
//  KKJSBridgeDemo
//
//  Created by wjx on 2020/9/27.
//  Copyright © 2020 karosli. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KKJSBridgeMessageSignatureParamter : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL JSON;

+ (instancetype)parameterWithName:(NSString *)name;
+ (instancetype)parameterWithName:(NSString *)name JSON:(BOOL)JSON;

@end

@interface KKJSBridgeMessageSignature : NSObject

@property (nonatomic, copy) NSArray<KKJSBridgeMessageSignatureParamter *> *paramters;

/// 要求同步回调返回结果
@property (nonatomic, assign) BOOL requiredResultBySyncCallback;

+ (instancetype)signatureWithParamters:(NSArray<KKJSBridgeMessageSignatureParamter *> *)paramters;
+ (instancetype)signatureWithParamters:(NSArray<KKJSBridgeMessageSignatureParamter *> *)paramters requiredResultBySyncCallback:(BOOL)requiredResultBySyncCallback;

@end

NS_ASSUME_NONNULL_END
