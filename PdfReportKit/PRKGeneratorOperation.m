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

#import "PRKGeneratorOperation.h"
#import "PRKRenderHtmlOperation.h"
#import "GRMustache.h"
#import "PRKPageRenderer.h"
#import "PRKFakeRenderer.h"

@interface PRKGeneratorOperation () {
    NSString        * currentReportName;
    NSUInteger        currentReportPage;
    NSUInteger        currentReportItemsPerPage;
    NSUInteger        currentReportTotalItems;
    NSUInteger        currentNumberOfItems;
    NSUInteger        remainingItems;
    NSUInteger        currentMaxItemsSinglePage;
    NSUInteger        currentMinItemsSinglePage;
    bool              currentSuccessSinglePage;
    
    PRKPageOrientation orientation;
    
    NSMutableData           * currentReportData;
    GRMustacheTemplate      * template;
    
    NSMutableDictionary     * renderedTags;
}

@property (nonatomic, retain)   NSOperationQueue * renderingQueue;
@property (strong) NSMutableArray *pagesPrintFormatters;
@end

@implementation PRKGeneratorOperation

// Static fields
static PRKGeneratorOperation * instance = nil;
static NSArray * reportDefaultTags = nil;

+ (PRKGeneratorOperation *)sharedGenerator
{
    @synchronized(self)
    {
        if (instance == nil)
        {
            instance = [[PRKGeneratorOperation alloc] init];
        }
        
        return instance;
    }
}

- (id)init
{
    self = [super init];
    if (self)
    {
        renderedTags = [[NSMutableDictionary alloc] init];
        _renderingQueue = [[NSOperationQueue alloc] init];
        _renderingQueue.name = @"Rendering Queue";
        _renderingQueue.maxConcurrentOperationCount = 1;

    }
    
    return self;
}



-(NSArray*) reportDefaultTags {
    static NSArray *reportDefaultTags;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reportDefaultTags = @[ @"documentHeader", @"pageHeader", @"pageContent", @"pageFooter", @"pageNumber" ];
    });
    return reportDefaultTags;
}



- (PRKGeneratorOperation*)initWithName:(NSString *)reportName templateURLString:(NSString *)templatePath itemsPerPage:(NSUInteger)itemsPerPage totalItems:(NSUInteger)totalItems pageOrientation:(PRKPageOrientation)orientation dataSource: (id<PRKGeneratorDataSource>)dataSource delegate: (id<PRKGeneratorDelegate>)delegate error:(NSError *__autoreleasing *)error {
    
    self = [self init];
    if (self) {
        self.dataSource = dataSource;
        self.delegate = delegate;
        currentReportData = [NSMutableData data];
        template = [GRMustacheTemplate templateFromContentsOfFile:templatePath error:error];
        if (*error) {
            self = nil;
            return nil;
        }
        
        currentReportItemsPerPage = itemsPerPage;
        currentNumberOfItems = currentReportItemsPerPage;
        currentMaxItemsSinglePage = itemsPerPage;
        currentMinItemsSinglePage = itemsPerPage;
        currentReportTotalItems = totalItems;
        currentSuccessSinglePage = NO;
        remainingItems = 0;
        
    }
    return self;
}

-(void)main {
    
    self.pagesPrintFormatters  = [NSMutableArray array];
    
    [self createPage:@(0)];
 
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        CGRect pdfRect;
        
        if (orientation == PRKPortraitPage)
            pdfRect =CGRectMake(0, 0, 800, 1000);
        else
            pdfRect =CGRectMake(0, 0, 1000, 800);

        UIGraphicsBeginPDFContextToData(currentReportData, pdfRect, nil);

        for (NSDictionary *dict in self.pagesPrintFormatters) {
            [self renderPageWithHeaderPrintFormatter: [dict objectForKey:@"header"]
                               contentPrintFormatter: [dict objectForKey:@"content"]
                                footerPrintFormatter: [dict objectForKey:@"footer"]];
         }
        
        UIGraphicsEndPDFContext();

        [self.delegate reportsGenerator:self didFinishRenderingWithData:currentReportData];
        
        currentReportData = nil;
    });
    
}



- (void)createPage: (NSNumber *)page
{
    NSLog(@"Creating page: %i", page.unsignedIntegerValue);
    
    int i = [page intValue];
    if (remainingItems < currentReportTotalItems)
    {
        [renderedTags removeAllObjects];
        currentReportPage = i + 1;
        
        NSError * error;
        // PRKGenerator is key-value "get" compliant (as GRMustache needs), so we could use self
        NSString * renderedHtml = [template renderObject:self error:&error];
        
        NSMutableString * wellFormedHeader = [NSMutableString stringWithString:renderedHtml];
        NSMutableString * wellFormedContent = [NSMutableString stringWithString:renderedHtml];
        NSMutableString * wellFormedFooter = [NSMutableString stringWithString:renderedHtml];
        
        
        // Trim content and footer to get header
        [wellFormedHeader replaceOccurrencesOfString:[renderedTags objectForKey:@"pageContent"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedHeader.length)];
        [wellFormedHeader replaceOccurrencesOfString:[renderedTags objectForKey:@"pageFooter"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedHeader.length)];
        
        // Trim header and footer to get content
        [wellFormedContent replaceOccurrencesOfString:[renderedTags objectForKey:@"documentHeader"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedContent.length)];
        [wellFormedContent replaceOccurrencesOfString:[renderedTags objectForKey:@"pageHeader"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedContent.length)];
        [wellFormedContent replaceOccurrencesOfString:[renderedTags objectForKey:@"pageFooter"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedContent.length)];
        
        // Trim content and header to get footer
        [wellFormedFooter replaceOccurrencesOfString:[renderedTags objectForKey:@"documentHeader"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedFooter.length)];
        [wellFormedFooter replaceOccurrencesOfString:[renderedTags objectForKey:@"pageHeader"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedFooter.length)];
        [wellFormedFooter replaceOccurrencesOfString:[renderedTags objectForKey:@"pageContent"] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, wellFormedFooter.length)];
        
        PRKRenderHtmlOperation * headerOperation = [[PRKRenderHtmlOperation alloc] initWithHtmlContent:wellFormedHeader];
        headerOperation.delegate = self;
        
        PRKRenderHtmlOperation * contentOperation = [[PRKRenderHtmlOperation alloc] initWithHtmlContent:wellFormedContent];
        contentOperation.delegate = self;
        
        PRKRenderHtmlOperation * footerOperation = [[PRKRenderHtmlOperation alloc] initWithHtmlContent:wellFormedFooter];
        footerOperation.delegate = self;

        [headerOperation start];
        [headerOperation waitUntilFinished];
        
        [contentOperation start];
        [contentOperation waitUntilFinished];
        
        [footerOperation start];
        [footerOperation waitUntilFinished];
        
        NSDictionary *dict = @{@"header": headerOperation.printFormatter,
                               @"content": contentOperation.printFormatter,
                               @"footer": footerOperation.printFormatter
                               };
        
        [self.pagesPrintFormatters addObject:dict];

    }
}

- (id)valueForKey:(NSString *)key
{
    id<PRKGeneratorDataSource> source = [[self reportDefaultTags] containsObject:key] ? self : self.dataSource;
    id data = [source reportsGenerator:self dataForReport:currentReportName withTag:key forPage: currentReportPage offset:remainingItems itemsCount:currentNumberOfItems];

    
    return data;
}

- (id)reportsGenerator:(PRKGeneratorOperation *)generator dataForReport:(NSString *)reportName withTag:(NSString *)tagName forPage:(NSUInteger)pageNumber offset:(NSUInteger)offset itemsCount:(NSUInteger)itemsCount
{
        
    return [GRMustache renderingObjectWithBlock:^NSString *(GRMustacheTag *tag, GRMustacheContext *context, BOOL *HTMLSafe, NSError *__autoreleasing *error)
    {
        NSString * renderedTag;
        if (pageNumber > 1 && [tagName isEqualToString:@"documentHeader"])
        {
            renderedTag =  @"";
        }
        else if ([tagName isEqualToString:@"pageNumber"])
        {
            renderedTag = [NSString stringWithFormat:@"%d", pageNumber];
        }
        else
            renderedTag = [tag renderContentWithContext:context HTMLSafe:HTMLSafe error:error];
        
        [renderedTags setObject:renderedTag forKey:tagName];
            
        return renderedTag;
    }];
}

- (void)renderPageWithHeaderPrintFormatter: (UIViewPrintFormatter *)headerFormatter
                     contentPrintFormatter: (UIViewPrintFormatter *)contentFormatter
                      footerPrintFormatter: (UIViewPrintFormatter *)footerFormatter
{
    PRKFakeRenderer * headerFakeRenderer = [[PRKFakeRenderer alloc] init];
    [headerFakeRenderer addPrintFormatter:headerFormatter startingAtPageAtIndex:0];
    PRKFakeRenderer * footerFakeRenderer = [[PRKFakeRenderer alloc] init];
    [footerFakeRenderer addPrintFormatter:footerFormatter startingAtPageAtIndex:0];
    
    int headerHeight = [headerFakeRenderer contentHeight];
    int footerHeight = [footerFakeRenderer contentHeight];
    
    PRKPageRenderer * pageRenderer = [[PRKPageRenderer alloc] initWithHeaderFormatter:headerFormatter headerHeight:headerHeight andContentFormatter:contentFormatter andFooterFormatter:footerFormatter footerHeight:footerHeight];
    
    int pageToRender = -1;
    if (pageRenderer.numberOfPages > 1)
    {
        if (currentSuccessSinglePage) {
            currentNumberOfItems --;
        }
        else
        {
            currentNumberOfItems = currentNumberOfItems / 2;
        }
        pageToRender =currentReportPage - 1;
    }
    else
    {
        // è il massimo numero di elementi che posso stampare quindi stampo il pdf
        if (currentMinItemsSinglePage == currentNumberOfItems) {
            pageToRender = currentReportPage;
            [pageRenderer addPagesToPdfContext];
            remainingItems += currentNumberOfItems;
            currentNumberOfItems =  currentMaxItemsSinglePage;
            currentMinItemsSinglePage = currentNumberOfItems;
            currentSuccessSinglePage = NO;
        }
        else
        {
            //provo a stampare un elemento in piu e setto il minimo con cui funziona
            currentMinItemsSinglePage = currentNumberOfItems;
            currentNumberOfItems = currentNumberOfItems + 1;
            currentSuccessSinglePage = YES;
            pageToRender = currentReportPage-1;
        }
    }
    if (pageToRender>-1)
        [self createPage:@(pageToRender)];
}


@end
