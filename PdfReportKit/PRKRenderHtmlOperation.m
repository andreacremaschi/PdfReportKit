/* Copyright 2012 Antonio Scandurra
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License. */

#import "PRKRenderHtmlOperation.h"
#import "PRKGeneratorOperation.h"

@implementation PRKRenderHtmlOperation

- (id)initWithHtmlContent:(NSString *)html
{
    self = [super init];
    if (self)
    {        
        htmlSource = html;
    }
    
    return self;
}

- (UIWebView *)renderingWebView {
    if (renderingWebView == nil) {
        if ([NSThread isMainThread]) {
            renderingWebView = [[UIWebView alloc] init];
            renderingWebView.delegate = self;
            
        } else
            dispatch_sync(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    renderingWebView = [[UIWebView alloc] init];
                    renderingWebView.delegate = self;
                }
            });
    }
    return renderingWebView;
}

- (void)start
{
    [self willChangeValueForKey:@"isExecuting"];
    executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    if ([NSThread isMainThread]) {
        [self.renderingWebView loadHTMLString:htmlSource baseURL:baseURL];
    } else
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.renderingWebView loadHTMLString:htmlSource baseURL:baseURL];
        });
}

- (BOOL)isConcurrent
{
    return NO;
}

- (BOOL)isFinished
{
    @synchronized(self)
    {
        return finished;
    }
}

- (BOOL)isExecuting
{
    @synchronized(self)
    {
        return executing;
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    webView.delegate = nil;
    self.printFormatter = [self.renderingWebView.viewPrintFormatter copy];

    [self willChangeValueForKey:@"isFinished"];
    finished = YES;
    [self didChangeValueForKey:@"isFinished"];
    
    [self willChangeValueForKey:@"isExecuting"];
    
    executing = NO;
    [self didChangeValueForKey:@"isExecuting"];
    
}

@end
