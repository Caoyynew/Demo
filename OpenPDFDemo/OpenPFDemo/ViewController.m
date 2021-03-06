//
//  ViewController.m
//  OpenPFDemo
//
//  Created by 康起军 on 16/2/26.
//  Copyright © 2016年 Kangqj. All rights reserved.
// 参考：http://blog.csdn.net/yiyaaixuexi/article/details/7645725

#import "ViewController.h"
#import "WebViewController.h"
#import <QuickLook/QuickLook.h>
#import "DrawPDFViewController.h"

#include "common.h"
#include "mupdf/fitz.h"
#import "MuDocRef.h"
#import "MuDocumentController.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate, QLPreviewControllerDataSource, UIPageViewControllerDataSource>
{
    char *_filePath;
    NSString *_filename;
    fz_context *ctx;
    MuDocRef *doc;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"OpenPDFDemo";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil)
    {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
    }
    
    switch (indexPath.row)
    {
        case 0:
            cell.textLabel.text = @"UIWebView";
            break;
        case 1:
            cell.textLabel.text = @"QLPreviewController";
            break;
        case 2:
            cell.textLabel.text = @"CGContextDrawPDFPage+UIPageViewController";
            break;
        case 3:
            cell.textLabel.text = @"MuPDF";
            break;
        default:
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (indexPath.row)
    {
        case 0:
        {
            WebViewController *viewController = [[WebViewController alloc] init];
            [self.navigationController pushViewController:viewController animated:YES];
            [viewController release];
            
            break;
        }
        case 1:
        {
            QLPreviewController *previewController = [[QLPreviewController alloc] init];
            previewController.dataSource = self;
            [self.navigationController pushViewController:previewController animated:YES];
            [previewController release];
            
            break;
        }
        case 2:
        {
            NSDictionary *options =[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:UIPageViewControllerSpineLocationMin]
                                                               forKey: UIPageViewControllerOptionSpineLocationKey];
            
            UIPageViewController *pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl
                                                             navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                           options:options];
            pageController.dataSource = self;
            DrawPDFViewController *pdfController = [self getViewControllerWithPage:1];
            
            NSArray *viewControllers =[NSArray arrayWithObject:pdfController];
            [pageController setViewControllers:viewControllers
                                      direction:UIPageViewControllerNavigationDirectionForward
                                       animated:NO
                                     completion:nil];
            
            [self.navigationController pushViewController:pageController animated:YES];
            [pageController release];
            
            break;
        }
        case 3:
        {
            NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"pdf"];
            [self openMuPDF:path name:@"test.pdf"];
            break;
        }
        default:
            break;
    }
}

- (void)openMuPDF:(NSString *)path name:(NSString *)name
{
    _filePath = malloc(strlen([path UTF8String])+1);
    
    strcpy(_filePath, [path UTF8String]);
    
    dispatch_sync(queue, ^{});
    
    printf("open document '%s'\n", _filePath);
    
    _filename = [name retain];
    
    doc = [[MuDocRef alloc] initWithFilename:_filePath];
    if (!doc) {
        
        return;
    }
    
    if (fz_needs_password(ctx, doc->doc))
    {
        [self askForPassword: @"'%@' needs a password:"];
    }
    else
    {
        [self onPasswordOkay];
    }
}

- (void)askForPassword: (NSString*)prompt
{
    UIAlertView *passwordAlertView = [[UIAlertView alloc]
                                      initWithTitle: @"Password Protected"
                                      message: [NSString stringWithFormat: prompt, [_filename lastPathComponent]]
                                      delegate: self
                                      cancelButtonTitle: @"Cancel"
                                      otherButtonTitles: @"Done", nil];
    [passwordAlertView setAlertViewStyle: UIAlertViewStyleSecureTextInput];
    [passwordAlertView show];
    [passwordAlertView release];
}

- (void)onPasswordOkay
{
    MuDocumentController *document = [[MuDocumentController alloc] initWithFilename:_filename path:_filePath document:doc];
    if (document) {
        [self setTitle: @"Library"];
        [[self navigationController] pushViewController:document animated:YES];
        [document release];
    }
    [_filename release];
    free(_filePath);
}



- (DrawPDFViewController *)getViewControllerWithPage:(NSInteger)page
{
    NSString *filename = @"test.pdf";
    CFURLRef pdfURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(), (__bridge CFStringRef)filename, NULL, NULL);
    CGPDFDocumentRef pdfDocument = CGPDFDocumentCreateWithURL((CFURLRef)pdfURL);
    CFRelease(pdfURL);
    
    DrawPDFViewController *pdfController = [[DrawPDFViewController alloc] initWithPage:page withPDFDoc:pdfDocument];
    
    return pdfController;
}

#pragma - mark QLPreviewControllerDataSource
- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller
{
    return 1;
}

- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"pdf"];
    return [NSURL fileURLWithPath:path];
}


#pragma - mark UIPageViewControllerDataSource
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    DrawPDFViewController *controller = (DrawPDFViewController *)viewController;
    
    if (controller.page-1 < 1)
    {
        return nil;
    }
    
    return [self getViewControllerWithPage:controller.page-1];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    DrawPDFViewController *controller = (DrawPDFViewController *)viewController;
    long pageSum = CGPDFDocumentGetNumberOfPages(controller.pdfDocument);
    
    if (controller.page+1 > pageSum)
    {
        return nil;
    }
    return [self getViewControllerWithPage:controller.page+1];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
