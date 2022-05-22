//
//  KKJSBridgeJSExecutor.m
//  KKJSBridge
//
//  Created by karos li on 2019/7/23.
//  Copyright © 2019 karosli. All rights reserved.
//

#import "KKJSBridgeJSExecutor.h"
#import <WebKit/WebKit.h>

@implementation KKJSBridgeJSExecutor

+ (void)evaluateJavaScript:(NSString *)javaScriptString inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    if ([[NSThread currentThread] isMainThread]) {
        __weak typeof(webView) weakWebView = webView;
        [webView evaluateJavaScript:javaScriptString completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            __strong typeof(weakWebView) strongWebView = weakWebView;
            [strongWebView title];
            if (completionHandler) {
                completionHandler(result, error);
            }
        }];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            __weak typeof(webView) weakWebView = webView;
            [webView evaluateJavaScript:javaScriptString completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                __strong typeof(weakWebView) strongWebView = weakWebView;
                [strongWebView title];
                if (completionHandler) {
                    completionHandler(result, error);
                }
            }];
        });
    }
}

+ (void)evaluateJavaScriptFunction:(NSString *)function withJson:(NSDictionary *)json inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    NSString *messageString = [self jsSerializeWithJson:json];
    NSString *jsString = [NSString stringWithFormat:@"%@('%@')", function, messageString];
    [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
}

+ (void)evaluateJavaScriptFunction:(NSString *)function withDictionary:(NSDictionary *)dictionary inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    NSString *argsFragment = [self serializeWithJson:dictionary pretty:NO];
    NSString *jsString = [NSString stringWithFormat:@"%@(%@)", function, argsFragment];
    [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
}

+ (void)evaluateJavaScriptFunction:(NSString *)function withArray:(NSArray *)array inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    NSString *argsFragment = [self serializeWithArray:array pretty:NO];
    NSString *jsString = [NSString stringWithFormat:@"%@(%@)", function, argsFragment];
    [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
}

+ (void)evaluateJavaScriptFunction:(NSString *)function withString:(NSString *)string inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    NSString *jsString = [NSString stringWithFormat:@"%@('%@')", function, string];
    [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
}

+ (void)evaluateJavaScriptFunction:(NSString *)function withNumber:(NSNumber *)number inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    NSString *jsString = [NSString stringWithFormat:@"%@(%@)", function, number];
    [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
}

+ (void)evaluateJavaScriptFunction:(NSString *)function withArgs:(NSArray *)args inWebView:(WKWebView *)webView completionHandler:(void (^ _Nullable)(_Nullable id result, NSError * _Nullable error))completionHandler {
    if (0 == args.count) {
        NSString *jsString = [NSString stringWithFormat:@"%@()", function];
        return [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:args options:kNilOptions error:nil];
    NSString *argsFragment = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    argsFragment = [argsFragment substringWithRange:(NSRange) {
        .location = 1,
        .length = argsFragment.length - 2
    }];
    
    NSString *jsString = [NSString stringWithFormat:@"%@(%@)", function, argsFragment];
    return [self evaluateJavaScript:jsString inWebView:webView completionHandler:completionHandler];
}

#pragma mark - util
+ (NSString *)jsSerializeWithJson:(NSDictionary * _Nullable)json {
    if (0 == json.count) {
        return @"{}";
    }

    NSMutableString *JSON = [[self serializeWithJson:json pretty:NO] mutableCopy];
    [JSON replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\'" withString:@"\\\'" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\f" withString:@"\\f" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\u2028" withString:@"\\u2028" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\u2029" withString:@"\\u2029" options:0 range:(NSRange) { .length = JSON.length }];
    return JSON;
}

+ (NSString *)serializeWithJson:(NSDictionary * _Nullable)json pretty:(BOOL)pretty {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json ?: @{} options:(pretty ? NSJSONWritingPrettyPrinted : kNilOptions) error:&error];
#ifdef DEBUG
    if (error) {
        NSLog(@"KKJSBridge Error: format json error %@", error.localizedDescription);
    }
#endif
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str ?: @"";
}

+ (NSString *)jsSerializeWithArray:(NSArray * _Nullable)array {
    if (0 == array.count) {
        return @"[]";
    }
    
    NSMutableString *JSON = [[self serializeWithArray:array pretty:NO] mutableCopy];
    [JSON replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\'" withString:@"\\\'" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\n" withString:@"\\n" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\r" withString:@"\\r" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\f" withString:@"\\f" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\u2028" withString:@"\\u2028" options:0 range:(NSRange) { .length = JSON.length }];
    [JSON replaceOccurrencesOfString:@"\u2029" withString:@"\\u2029" options:0 range:(NSRange) { .length = JSON.length }];
    return JSON;
}

+ (NSString *)serializeWithArray:(NSArray * _Nullable)array pretty:(BOOL)pretty {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:array ?: @[] options:(pretty ? NSJSONWritingPrettyPrinted : kNilOptions) error:&error];
#ifdef DEBUG
    if (error) {
        NSLog(@"KKJSBridge Error: format array error %@", error.localizedDescription);
    }
#endif
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str ?: @"";
}

@end
