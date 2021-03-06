//
//  ComPspdfkitModule.h
//  PSPDFKit-Titanium
//
//  Copyright (c) 2011-2014 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY AUSTRIAN COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//
//  Appcelerator Titanium is Copyright (c) 2009-2014 by Appcelerator, Inc.
//  and licensed under the Apache Public License (version 2)
//

#import "ComPspdfkitModule.h"
#import "ComPspdfkitView.h"
#import "TiBase.h"
#import "TiApp.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "PSPDFUtils.h"
#import "TIPSPDFViewController.h"
#import "TIPSPDFViewControllerProxy.h"
#import "TIPSPDFAnnotationProxy.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Declare internal helper.
extern BOOL PSPDFReplaceMethodWithBlock(Class c, SEL origSEL, SEL newSEL, id block);

@interface TIPSPDFViewControllerProxy (PSPDFInternal)
@property(atomic, assign) UIInterfaceOrientation lockedInterfaceOrientationValue;
@end

@interface TiRootViewController (PSPDFInternal)
- (void)refreshOrientationWithDuration:(NSTimeInterval)duration;
- (void)pspdf_refreshOrientationWithDuration:(NSTimeInterval)duration; // will be added dynamically
@end

@implementation ComPspdfkitModule

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Appcelerator Lifecycle

// this method is called when the module is first loaded
- (void)startup {
	[super startup];
    [self printVersionStringOnce];
}

// this method is called when the module is being unloaded
// typically this is during shutdown. make sure you don't do too
// much processing here or the app will be quit forcibly
- (void)shutdown:(id)sender {
	[super shutdown:sender];
}

- (id)moduleGUID {
	return @"3056f4e3-4ee6-4cf3-8417-1d8b8f95853c";
}

- (NSString *)moduleId {
	return @"com.pspdfkit";
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

BOOL PSPDFShouldRelayBarButtonSetter(id _self) {
    BOOL shouldRelay = YES;
    @try {
        // check if we should ignore the call
        UIView *view = [[_self valueForKey:@"controller"] view];
        UIView *comPspdfkitView = nil;
        if ((comPspdfkitView = PSViewInsideViewWithPrefix(view, NSStringFromClass(ComPspdfkitView.class)))) {
            PSPDFViewController *pdfController = [[(ComPspdfkitView *)comPspdfkitView controllerProxy] controller];
            shouldRelay = !pdfController.useParentNavigationBar;
        }
    }
    @catch (NSException *exception) {
        PSCLog(@"Error while checking PSPDFShouldRelayBarButtonSetter: %@", exception);
    }
    return shouldRelay;
}

// Prevent that left/rightBarButtonItems is called within appcelerator if a PSPDFKit view is hosted.
__attribute__((constructor)) void PSPDFFixBarButtonItemOverridesInAppcelerator(void) {
    @autoreleasepool {
        SEL setRightNavButtonSEL = @selector(pspdf_setRightNavButton:withObject:);
        PSPDFReplaceMethodWithBlock(NSClassFromString(@"TiUIWindowProxy"), @selector(setRightNavButton:withObject:), setRightNavButtonSEL, ^(id _self, id proxy, id properties) {
            if (PSPDFShouldRelayBarButtonSetter(_self)) {
                objc_msgSend(_self, setRightNavButtonSEL, proxy, properties);
            }
        });
    }

    @autoreleasepool {
        SEL setLeftNavButtonSEL = @selector(pspdf_setLeftNavButton:withObject:);
        PSPDFReplaceMethodWithBlock(NSClassFromString(@"TiUIWindowProxy"), @selector(setLeftNavButton:withObject:), setLeftNavButtonSEL, ^(id _self, id proxy, id properties) {
            if (PSPDFShouldRelayBarButtonSetter(_self)) {
                objc_msgSend(_self, setLeftNavButtonSEL, proxy, properties);
            }
        });
    }
}

// Hack into Titanium to stop "fixing" interface orientation when we have a locked one.
__attribute__((constructor)) void PSPDFFixRotation(void) {
    @autoreleasepool {
        SEL customRefreshSEL = @selector(pspdf_refreshOrientationWithDuration:);
        PSPDFReplaceMethodWithBlock(NSClassFromString(@"TiRootViewController"), @selector(refreshOrientationWithDuration:), customRefreshSEL, ^(id _self, NSTimeInterval timeInterval) {
            BOOL isShowingPSPDFController = NO;
            if ([[_self modalViewController] isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navController = (UINavigationController *)[_self modalViewController];
                if ([navController.viewControllers count] && [(navController.viewControllers)[0] isKindOfClass:PSPDFViewController.class]) {
                    isShowingPSPDFController = YES;
                }
            }
            // only call original method if we are not displayed.
            if (!isShowingPSPDFController) {
                [_self pspdf_refreshOrientationWithDuration:timeInterval];
            }
        });
    }
}

// Extract a dictionary from the input
- (NSDictionary *)dictionaryFromInput:(NSArray *)input position:(NSUInteger)position {
    NSDictionary *dict = input.count > position && [input[position] isKindOfClass:NSDictionary.class] ? input[position] : nil;
    return dict;
}

// Show version string once in the console.
- (void)printVersionStringOnce {
    static BOOL printVersionOnce = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"Initialized PSPDFKit %@", [self PSPDFKitVersion]);
        printVersionOnce = NO;
    });
}

// internal helper for pushing the PSPDFViewController on the view
- (TIPSPDFViewControllerProxy *)pspdf_displayPdfInternal:(NSArray *)pdfNames animation:(NSUInteger)animation options:(NSDictionary *)options documentOptions:(NSDictionary *)documentOptions {
    __block TIPSPDFViewControllerProxy *proxy = nil;
    ps_dispatch_main_sync(^{
        PSPDFDocument *document = nil;

        // Support encryption
        NSString *passphrase = documentOptions[@"passphrase"];
        NSString *salt = documentOptions[@"salt"];
        if (passphrase.length && salt.length) {
            NSURL *pdfURL = [NSURL fileURLWithPath:[pdfNames firstObject]];
            PSPDFAESCryptoDataProvider *cryptoWrapper = [[PSPDFAESCryptoDataProvider alloc] initWithURL:pdfURL passphrase:passphrase salt:salt rounds:PSPDFDefaultPBKDFNumberOfRounds];
            document = [PSPDFDocument documentWithDataProvider:cryptoWrapper.dataProvider];
        }

        if (!document) document = [[PSPDFDocument alloc] initWithBaseURL:nil files:pdfNames];

        TIPSPDFViewController *pdfController = [[TIPSPDFViewController alloc] initWithDocument:document];

        [PSPDFUtils applyOptions:options onObject:pdfController];
        [PSPDFUtils applyOptions:documentOptions onObject:document];

        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:pdfController];
        UIViewController *rootViewController = (UIViewController *)[([UIApplication sharedApplication].windows)[0] rootViewController];

        // allow custom animation styles
        PSTiLog(@"animation: %d", animation);
        if (animation >= 2) {
            navController.modalTransitionStyle = animation - 2;
        }

        // encapsulate controller into proxy
        //PSTiLog(@"_pspdf_displayPdfInternal");
        proxy = [[TIPSPDFViewControllerProxy alloc] initWithPDFController:pdfController context:self.pageContext parentProxy:self];

        // rotation lock?
        UIInterfaceOrientation lockedInterfaceOrientation = [options[@"lockedInterfaceOrientation"] integerValue];
        if (UIDeviceOrientationIsValidInterfaceOrientation(lockedInterfaceOrientation)) {
            pdfController.proxy.lockedInterfaceOrientationValue = lockedInterfaceOrientation;
        }

        [rootViewController presentViewController:navController animated:animation > 0 completion:NULL];
    });
    return proxy;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (id)PSPDFKitVersion {
    return PSPDFVersionString();
}

- (void)setLicenseKey:(id)license {
    NSString *licenseString = [license isKindOfClass:NSArray.class] ? [license firstObject] : license;
    if ([licenseString isKindOfClass:NSString.class] && licenseString.length > 0) {
        PSPDFSetLicenseKey(licenseString.UTF8String);
    }
}

/// show modal pdf animated
- (id)showPDFAnimated:(NSArray *)pathArray {
    [self printVersionStringOnce];

    if (pathArray.count < 1 || pathArray.count > 4 || ![pathArray[0] isKindOfClass:NSString.class] || [pathArray[0] length] == 0) {
        PSCLog(@"PSPDFKit Error. At least one argument is needed: pdf filename (either absolute or relative (application bundle and documents directory are searched for it)\n \
                      Argument 2 sets animated to true or false. (optional, defaults to true)\n \
                      Argument 3 can be an array with options for PSPDFViewController. See http://pspdfkit.com/documentation.html for details. You need to write the numeric equivalent for enumeration values (e.g. PSPDFPageModeDouble has the numeric value of 1)\
                      Argument 4 can be an array with options for PSPDFDocument.\
                      \n(arguments: %@)", pathArray);
        return nil;
    }

    NSUInteger animation = 1; // default modal
    if (pathArray.count >= 2 && [pathArray[1] isKindOfClass:NSNumber.class]) {
        animation = [pathArray[1] intValue];
    }

    // be somewhat intelligent about path search
    id filePath = pathArray[0];
    NSArray *pdfPaths = [PSPDFUtils resolvePaths:filePath];

    // extract options from input
    NSDictionary *options = [self dictionaryFromInput:pathArray position:2];
    NSDictionary *documentOptions = [self dictionaryFromInput:pathArray position:3];

    if (options) PSCLog(@"options: %@", options);
    if (documentOptions) PSCLog(@"documentOptions: %@", documentOptions);

    PSCLog(@"Opening PSPDFViewController for %@.", pdfPaths);
    return [self pspdf_displayPdfInternal:pdfPaths animation:animation options:options documentOptions:documentOptions];
}

- (void)clearCache:(id)args {
    PSCLog(@"requesting clear cache... (spins of async)");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [PSPDFCache.sharedCache clearCache];
    });
}

- (void)cacheDocument:(id)args {
    PSCLog(@"Request to cache document at path %@", args);

    // be somewhat intelligent about path search
    NSArray *documents = [PSPDFUtils documentsFromArgs:args];
    for (PSPDFDocument *document in documents) {
        [PSPDFCache.sharedCache cacheDocument:document startAtPage:0 sizes:@[[NSValue valueWithCGSize:PSPDFCache.sharedCache.thumbnailSize], [NSValue valueWithCGSize:UIScreen.mainScreen.bounds.size]] diskCacheStrategy:PSPDFDiskCacheStrategyEverything];
    }
}

- (void)removeCacheForDocument:(id)args {
    PSCLog(@"Request to REMOVE cache for document at path %@", args);

    // be somewhat intelligent about path search
    NSArray *documents = [PSPDFUtils documentsFromArgs:args];
    for (PSPDFDocument *document in documents) {
        NSError *error = nil;
        if (![[PSPDFCache sharedCache] removeCacheForDocument:document deleteDocument:NO error:&error]) {
            PSCLog(@"Failed to clear cache for %@: %@", document, error);
        }
    }
}

- (void)stopCachingDocument:(id)args {
    PSCLog(@"Request to STOP cache document at path %@", args);

    // be somewhat intelligent about path search
    NSArray *documents = [PSPDFUtils documentsFromArgs:args];
    for (PSPDFDocument *document in documents) {
        [PSPDFCache.sharedCache stopCachingDocument:document];
    }
}

- (id)imageForDocument:(id)args {
    PSCLog(@"Request image: %@", args);
    if ([args count] < 2) {
        PSCLog(@"Invalid number of arguments: %@", args);
        return nil;
    }
    UIImage *image = nil;

    PSPDFDocument *document = [PSPDFUtils documentsFromArgs:args].firstObject;
    NSUInteger page = [args[1] unsignedIntegerValue];
    BOOL full = [args count] < 3 || [args[2] unsignedIntegerValue] == 0;

    // be somewhat intelligent about path search
    if (document && page < [document pageCount]) {
        image = [PSPDFCache.sharedCache imageFromDocument:document page:page size:full ? UIScreen.mainScreen.bounds.size : PSPDFCache.sharedCache.thumbnailSize options:PSPDFCacheOptionDiskLoadSync|PSPDFCacheOptionRenderSync];
        if (!image) {
            CGSize size = full ? [[UIScreen mainScreen] bounds].size : [PSPDFCache sharedCache].thumbnailSize;
            image = [document imageForPage:page size:size clippedToRect:CGRectZero annotations:nil options:nil receipt:NULL error:NULL];
        }
    }

    // if we use this directly, we get linker errors???
    id proxy = nil;
    if (NSClassFromString(@"TiUIImageViewProxy")) {
        proxy = [NSClassFromString(@"TiUIImageViewProxy") new];
        [proxy performSelector:@selector(setImage:) withObject:image];
    }
    return proxy;
}

- (void)setLanguageDictionary:(id)dictionary {
    ENSURE_UI_THREAD(setLanguageDictionary, dictionary);

    if (![dictionary isKindOfClass:NSDictionary.class]) {
        PSCLog(@"PSPDFKit Error. Argument error, need dictionary with languages.");
    }

    PSPDFSetLocalizationDictionary(dictionary);
}

- (void)setLogLevel:(id)logLevel {
    ENSURE_UI_THREAD(setLogLevel, logLevel);

    PSPDFLogLevel = [PSPDFUtils intValue:logLevel];;
    PSCLog(@"New Log level set to %d", PSPDFLogLevel);
}

@end

@implementation ComPspdfkitSourceModule @end
