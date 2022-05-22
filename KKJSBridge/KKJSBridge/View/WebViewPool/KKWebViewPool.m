//
//  KKWebViewPool.m
//  KKJSBridge
//
//  Created by karos li on 2019/8/16.
//  Copyright © 2019 karosli. All rights reserved.
//

#import "KKWebViewPool.h"
#import "WKWebView+KKWebViewReusable.h"

@interface KKWebViewPool ()
@property (nonatomic, strong, readwrite) dispatch_semaphore_t lock;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSMutableArray< __kindof WKWebView *> *> *dequeueWebViews;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSMutableArray< __kindof WKWebView *> *> *enqueueWebViews;
@property (nonatomic, copy) void(^makeWebViewConfigurationBlock)(WKWebViewConfiguration *configuration);
@end

@implementation KKWebViewPool

+ (KKWebViewPool *)sharedInstance {
    static dispatch_once_t once;
    static KKWebViewPool *singleton;
    dispatch_once(&once, ^{
        singleton = [[KKWebViewPool alloc] init];
    });
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _webViewMinReuseCount = 1;
        _webViewMaxReuseCount = 5;
        _webViewMaxReuseTimes = NSIntegerMax;
        _webViewReuseLoadUrlStr = @"";
        
        _dequeueWebViews = @{}.mutableCopy;
        _enqueueWebViews = @{}.mutableCopy;
        _lock = dispatch_semaphore_create(1);
        //memory warning 时清理全部
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearAllReusableWebViews)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.dequeueWebViews removeAllObjects];
    [self.enqueueWebViews removeAllObjects];
    self.dequeueWebViews = nil;
    self.enqueueWebViews = nil;
}

#pragma mark - public method
- (__kindof WKWebView *)dequeueWebViewWithClass:(Class)webViewClass webViewHolder:(NSObject *)webViewHolder {
    if (![webViewClass isSubclassOfClass:[WKWebView class]]) {
#ifdef DEBUG
        NSLog(@"KKWebViewPool dequeue with invalid class:%@", webViewClass);
#endif
        return nil;
    }
    
    //auto recycle
    [self _tryCompactWeakHolderOfWebView];
    
    __kindof WKWebView *dequeueWebView = [self _getWebViewWithClass:webViewClass];
    dequeueWebView.holderObject = webViewHolder;
    return dequeueWebView;
}

- (void)makeWebViewConfiguration:(nullable void(^)(WKWebViewConfiguration *configuration))block {
    self.makeWebViewConfigurationBlock = block;
}

- (void)enqueueWebViewWithClass:(Class)webViewClass {
    if (![webViewClass isSubclassOfClass:[WKWebView class]]) {
#ifdef DEBUG
        NSLog(@"KKWebViewPool enqueue with invalid class:%@", webViewClass);
#endif
    }

    NSString *webViewClassString = NSStringFromClass(webViewClass);
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); {
        NSMutableArray *enqueue = _enqueueWebViews[webViewClassString];
        if (nil == enqueue) {
            _enqueueWebViews[webViewClassString] = enqueue = [NSMutableArray array];
        }
        
        if (enqueue.count < [KKWebViewPool sharedInstance].webViewMinReuseCount) {
            [enqueue addObject:[self generateInstanceWithWebViewClass:webViewClass]];
        }
    } dispatch_semaphore_signal(_lock);
}

- (void)enqueueWebView:(__kindof WKWebView *)webView {
    if (!webView) {
#ifdef DEBUG
        NSLog(@"KKWebViewPool enqueue with invalid view:%@", webView);
#endif
        return;
    }
    [webView removeFromSuperview];
    if (webView.reusedTimes >= [[KKWebViewPool sharedInstance] webViewMaxReuseTimes] || webView.invalid) {
        [self removeReusableWebView:webView];
    } else {
        [self _recycleWebView:webView];
    }
}

- (void)reloadAllReusableWebViews {
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    for (NSArray *views in _enqueueWebViews.allValues) {
        for (__kindof WKWebView *webView in views) {
            [webView componentViewWillEnterPool];
        }
    }
    dispatch_semaphore_signal(_lock);
}

- (void)clearAllReusableWebViews {
    //auto recycle
    [self _tryCompactWeakHolderOfWebView];

    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [_enqueueWebViews removeAllObjects];
    dispatch_semaphore_signal(_lock);
}

- (void)removeReusableWebView:(__kindof WKWebView *)webView {
    if (!webView) {
        return;
    }

    if ([webView respondsToSelector:@selector(componentViewWillEnterPool)]) {
        [webView componentViewWillEnterPool];
    }

    NSString *webViewClassString = NSStringFromClass([webView class]);
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); {
        NSMutableArray *dequeue = _dequeueWebViews[webViewClassString];
        [dequeue removeObject:webView];
        
        NSMutableArray *enqueue = _enqueueWebViews[webViewClassString];
        [enqueue removeObject:webView];
    } dispatch_semaphore_signal(_lock);
}

- (void)clearAllReusableWebViewsWithClass:(Class)webViewClass {
    NSString *webViewClassString = NSStringFromClass(webViewClass);

    if (!webViewClassString || webViewClassString.length <= 0) {
        return;
    }

    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [_enqueueWebViews removeObjectForKey:webViewClassString];
    dispatch_semaphore_signal(_lock);
}

- (BOOL)containsReusableWebViewWithClass:(Class)webViewClass {
    NSString *webViewClassString = NSStringFromClass(webViewClass);
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    BOOL contains = (nil != _dequeueWebViews[webViewClassString]
                     || nil != _enqueueWebViews[webViewClassString]);
    dispatch_semaphore_signal(_lock);
    
    return contains;
}

- (__kindof WKWebView *)reusableWebViewWithPointer:(long long)address dequeued:(nullable BOOL *)dequeued;
{
    WKWebView *(^cherryPick)(NSDictionary<NSString *, NSArray<WKWebView *> *> *) = ^WKWebView *(NSDictionary<NSString *, NSArray<WKWebView *> *> *map) {
        __block WKWebView *webView = nil;
        NSArray<NSArray<__kindof WKWebView *> *> *dequeues = map.allValues;
        [dequeues enumerateObjectsUsingBlock:^(NSArray<__kindof WKWebView *> * _Nonnull views, NSUInteger idx, BOOL * _Nonnull stop0) {
            [views enumerateObjectsUsingBlock:^(__kindof WKWebView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop1) {
                if (((long long)view) == address) {
                    webView = view;
                    *stop0 = *stop1 = YES;
                }
            }];
        }];
        return webView;
    };
    
    WKWebView *webView = nil;
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); {
        if (nil == (webView = cherryPick(_dequeueWebViews))) {
            webView = cherryPick(_enqueueWebViews);
        } else if (NULL != dequeued) {
            *dequeued = YES;
        }
    } dispatch_semaphore_signal(_lock);
    
    return webView;
}

- (void)safelyEnumerateDequeuedWebView:(void (^)(__kindof WKWebView *webView, BOOL *stop))block;
{
    if (nil == block) {
        return;
    }
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); {
        [_dequeueWebViews enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<__kindof WKWebView *> * _Nonnull webViews, BOOL * _Nonnull stop0) {
            [webViews enumerateObjectsUsingBlock:^(__kindof WKWebView * _Nonnull webView, NSUInteger idx, BOOL * _Nonnull stop1) {
                block(webView, stop1);
                *stop0 = *stop1;
            }];
        }];
    } dispatch_semaphore_signal(_lock);
}

#pragma mark - private method

- (void)_tryCompactWeakHolderOfWebView {
    if (0 == _dequeueWebViews.count) {
        return;
    }
    
    NSDictionary *dequeueWebViewsTmp = [_dequeueWebViews copy];
    for (NSMutableArray *views in dequeueWebViewsTmp.allValues) {
        NSArray *viewsTmp = [views copy];
        for (__kindof WKWebView *webView in viewsTmp) {
            if (nil == webView.holderObject) {
                [self enqueueWebView:webView];
            }
        }
    }
}

- (void)_recycleWebView:(__kindof WKWebView *)webView {
    if (!webView) {
        return;
    }

    //进入回收池前清理
    if ([webView respondsToSelector:@selector(componentViewWillEnterPool)]) {
        [webView componentViewWillEnterPool];
    }

    NSString *webViewClassString = NSStringFromClass([webView class]);
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); {
        NSMutableArray *dequeue = _dequeueWebViews[webViewClassString];
        if (dequeue.count > 0) {
            [dequeue removeObject:webView];
        } else {
#ifdef DEBUG
            NSLog(@"KKWebViewPool recycle invalid view");
#endif
        }
        
        NSMutableArray *enqueue = _enqueueWebViews[webViewClassString];
        if (nil == enqueue) {
            _enqueueWebViews[webViewClassString] = enqueue = [NSMutableArray array];
        }
        
        if (enqueue.count < [KKWebViewPool sharedInstance].webViewMaxReuseCount) {
            [enqueue addObject:webView];
        }
    } dispatch_semaphore_signal(_lock);
}

- (__kindof WKWebView *)_getWebViewWithClass:(Class)webViewClass {
    NSString *webViewClassString = NSStringFromClass(webViewClass);

    if (!webViewClassString || webViewClassString.length <= 0) {
        return nil;
    }

    __kindof WKWebView *webView;
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER); {
        NSMutableArray *enqueue = _enqueueWebViews[webViewClassString];
        webView = enqueue.firstObject;
        if (nil == webView) {
            webView = [self generateInstanceWithWebViewClass:webViewClass];
        } else if (![webView isMemberOfClass:webViewClass]) {
    #ifdef DEBUG
            NSLog(@"KKWebViewPool webViewClassString: %@ already has webview of class:%@, params is %@", webViewClassString, NSStringFromClass([webView class]), NSStringFromClass(webViewClass));
    #endif
            dispatch_semaphore_signal(_lock);
            return nil;
        } else {
            [enqueue removeObjectAtIndex:0];
        }
        
        NSMutableArray *dequeue = _dequeueWebViews[webViewClassString];
        if (nil == dequeue) {
            _dequeueWebViews[webViewClassString] = dequeue = [NSMutableArray array];
        }
        [dequeue addObject:webView];
    } dispatch_semaphore_signal(_lock);

    //出回收池前初始化
    if ([webView respondsToSelector:@selector(componentViewWillLeavePool)]) {
        [webView componentViewWillLeavePool];
    }

    return webView;
}

- (__kindof WKWebView *)generateInstanceWithWebViewClass:(Class)webViewClass {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    if (self.makeWebViewConfigurationBlock) {
        self.makeWebViewConfigurationBlock(config);
    }
    return [[webViewClass alloc] initWithFrame:CGRectZero configuration:config];
}

@end
