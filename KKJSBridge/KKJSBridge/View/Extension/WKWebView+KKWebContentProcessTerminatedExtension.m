//
//  WKWebView+KKWebContentProcessTerminatedExtension.m
//  KKJSBridge
//
//  Created by wjx on 2022/5/11.
//  Copyright © 2022 karosli. All rights reserved.
//

#import "WKWebView+KKWebContentProcessTerminatedExtension.h"
#import <objc/runtime.h>

@implementation WKWebView (KKWebContentProcessTerminatedExtension)

- (BOOL)isContentProcessTerminated
{
    NSNumber *result = objc_getAssociatedObject(self, @selector(isContentProcessTerminated));
    return result.boolValue;
}

- (void)setContentProcessTerminated:(BOOL)contentProcessTerminated
{
    objc_setAssociatedObject(self, @selector(isContentProcessTerminated), @(contentProcessTerminated), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
