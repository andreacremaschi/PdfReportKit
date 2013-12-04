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

#import <Foundation/Foundation.h>
#import "PRKGeneratorOperation.h"

@interface PRKGenerator : NSObject

@property (nonatomic, strong)   NSOperationQueue * renderingQueue;

// Static methods
+ (PRKGenerator *) sharedGenerator;

// Instance methods
- (void)createReportWithName: (NSString *)reportName
           templateURLString: (NSString *)templatePath
                itemsPerPage: (NSUInteger)itemsPerPage
                  totalItems: (NSUInteger)totalItems
             pageOrientation: (PRKPageOrientation)orientation
                  dataSource: (id<PRKGeneratorDataSource>)dataSource
                    delegate: (id<PRKGeneratorDelegate>)delegate
                       error: (NSError *__autoreleasing *)error
             completionBlock: (void(^)())completionBlock;



@end
