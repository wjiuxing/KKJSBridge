//
//  KKJSBridgeMessageSignature.m
//  KKJSBridgeDemo
//
//  Created by wjx on 2020/9/27.
//  Copyright © 2020 karosli. All rights reserved.
//

#import "KKJSBridgeMessageSignature.h"

@implementation KKJSBridgeMessageSignatureParamter

+ (instancetype)parameterWithName:(NSString *)name;
{
    return [[KKJSBridgeMessageSignatureParamter alloc] initWithName:name JSON:NO];
}

+ (instancetype)parameterWithName:(NSString *)name JSON:(BOOL)JSON;
{
    return [[KKJSBridgeMessageSignatureParamter alloc] initWithName:name JSON:JSON];
}

- (instancetype)initWithName:(NSString *)name JSON:(BOOL)JSON
{
    if (self = [super init]) {
        self.name = name;
        self.JSON = JSON;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> { name: %@, JSON: %@ }", NSStringFromClass(self.class), self, _name, _JSON ? @"YES" : @"NO"];
}

@end

@implementation KKJSBridgeMessageSignature

+ (instancetype)signatureWithParamters:(NSArray<KKJSBridgeMessageSignatureParamter *> *)paramters;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParamters:paramters requiredResultBySyncCallback:NO];
}

+ (instancetype)signatureWithParamters:(NSArray<KKJSBridgeMessageSignatureParamter *> *)paramters requiredResultBySyncCallback:(BOOL)requiredResultBySyncCallback;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParamters:paramters requiredResultBySyncCallback:requiredResultBySyncCallback];
}

- (instancetype)initWithParamters:(NSArray<KKJSBridgeMessageSignatureParamter *> *)paramters requiredResultBySyncCallback:(BOOL)requiredResultBySyncCallback
{
    if (self = [super init]) {
        self.paramters = paramters;
        self.requiredResultBySyncCallback = requiredResultBySyncCallback;
    }
    return self;
}

- (NSString *)description
{
    NSString *desc = [NSString stringWithFormat:@"<%@: %p> { parameters: %@, requiredResultBySyncCallback: %@ }", NSStringFromClass(self.class), self, _paramters, _requiredResultBySyncCallback ? @"YES" : @"NO"];
    return desc;
}

@end
