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

#import "PRKGenerator.h"
#import "PRKRenderHtmlOperation.h"
#import "GRMustache.h"
#import "PRKPageRenderer.h"
#import "PRKFakeRenderer.h"
#import "PRKGeneratorOperation.h"

@implementation PRKGenerator

+ (PRKGenerator *)sharedGenerator
{
    static dispatch_once_t onceToken;
    static id __sharedInstance;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [PRKGenerator new];
    });
    return __sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self)
    {        
        // Initialize rendering queue
        self.renderingQueue = [NSOperationQueue new];
        self.renderingQueue.name = @"Rendering Queue";
        self.renderingQueue.maxConcurrentOperationCount = 1;
        
    }
    
    return self;
}

- (void)createReportWithName: (NSString *)reportName
           templateURLString: (NSString *)templatePath
                itemsPerPage: (NSUInteger)itemsPerPage
                  totalItems: (NSUInteger)totalItems
             pageOrientation: (PRKPageOrientation)orientation
                  dataSource: (id<PRKGeneratorDataSource>)dataSource
                    delegate: (id<PRKGeneratorDelegate>)delegate
                       error: (NSError *__autoreleasing *)error
             completionBlock: (void(^)())completionBlock
{

    PRKGeneratorOperation *operation = [[PRKGeneratorOperation alloc] initWithName:reportName
                                                                 templateURLString:templatePath
                                                                      itemsPerPage:itemsPerPage
                                                                        totalItems:totalItems
                                                                   pageOrientation:orientation
                                                                        dataSource:dataSource
                                                                          delegate:delegate
                                                                             error:error];
    operation.dataSource = dataSource;
    operation.delegate = delegate;
    operation.completionBlock = completionBlock;
    
    [self.renderingQueue addOperation: operation];
    
}

@end
