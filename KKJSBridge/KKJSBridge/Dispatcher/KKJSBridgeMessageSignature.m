//
//  KKJSBridgeMessageSignature.m
//  KKJSBridgeDemo
//
//  Created by wjx on 2020/9/27.
//  Copyright © 2020 karosli. All rights reserved.
//

#import "KKJSBridgeMessageSignature.h"

static inline NSString *NSStringFromBOOL(BOOL value)
{
    return value ? @"YES" : @"NO";
}

@implementation KKJSBridgeMessageSignatureParameter

+ (instancetype)parameterWithName:(NSString *)name;
{
    return [[KKJSBridgeMessageSignatureParameter alloc] initWithName:name JSON:NO];
}

+ (instancetype)parameterWithName:(NSString *)name JSON:(BOOL)JSON;
{
    return [[KKJSBridgeMessageSignatureParameter alloc] initWithName:name JSON:JSON];
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
    return [NSString stringWithFormat:@"<%@: %p> { name: %@, JSON: %@ }", NSStringFromClass(self.class), self, _name, NSStringFromBOOL(_JSON)];
}

@end

@implementation KKJSBridgeMessageSignature

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParameters:parameters resultReturnedByCallback:NO callbackFunctionCanBeUsedAsJSParameter:NO];
}

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
               resultReturnedByCallback:(BOOL)resultReturnedByCallback;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParameters:parameters resultReturnedByCallback:resultReturnedByCallback callbackFunctionCanBeUsedAsJSParameter:NO];
}

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
               resultReturnedByCallback:(BOOL)resultReturnedByCallback
 callbackFunctionCanBeUsedAsJSParameter:(BOOL)callbackFunctionCanBeUsedAsJSParameter;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParameters:parameters resultReturnedByCallback:resultReturnedByCallback callbackFunctionCanBeUsedAsJSParameter:callbackFunctionCanBeUsedAsJSParameter];
}

- (instancetype)initWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
          resultReturnedByCallback:(BOOL)resultReturnedByCallback
callbackFunctionCanBeUsedAsJSParameter:(BOOL)callbackFunctionCanBeUsedAsJSParameter
{
    if (self = [super init]) {
        self.parameters = parameters;
        self.resultReturnedByCallback = resultReturnedByCallback;
        self.callbackFunctionCanBeUsedAsJSParameter = callbackFunctionCanBeUsedAsJSParameter;
    }
    return self;
}

+ (instancetype)signatureWithDelegateSEL:(SEL)delegateSEL;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParameters:nil delegateSEL:delegateSEL];
}

+ (instancetype)signatureWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
                            delegateSEL:(SEL)delegateSEL;
{
    return [[KKJSBridgeMessageSignature alloc] initWithParameters:parameters delegateSEL:delegateSEL];
}

- (instancetype)initWithParameters:(NSArray<KKJSBridgeMessageSignatureParameter *> *)parameters
                       delegateSEL:(SEL)delegateSEL
{
    if (self = [super init]) {
        self.parameters = parameters;
        self.delegateSEL = delegateSEL;
    }
    return self;
}

- (NSString *)description
{
    NSString *desc = [NSString stringWithFormat:@"<%@: %p> { parameters: %@, resultReturnedByCallback: %@, callbackFunctionCanBeUsedAsJSParameter: %@ }", NSStringFromClass(self.class), self, _parameters, NSStringFromBOOL(_resultReturnedByCallback), NSStringFromBOOL(_callbackFunctionCanBeUsedAsJSParameter)];
    return desc;
}

@end
