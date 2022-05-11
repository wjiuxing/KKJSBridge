//
//  WKWebView+KKWebContentProcessTerminatedExtension.h
//  KKJSBridge
//
//  Created by wjx on 2022/5/11.
//  Copyright © 2022 karosli. All rights reserved.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WKWebView (KKWebContentProcessTerminatedExtension)

/// web content process 被杀
@property (nonatomic, assign, getter=isContentProcessTerminated) BOOL contentProcessTerminated;

@end

NS_ASSUME_NONNULL_END
