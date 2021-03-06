//
//  TIPSPDFViewControllerProxy.m
//  PSPDFKit-Titanium
//
//  Copyright (c) 2011-2014 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY AUSTRIAN COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

#import "TIPSPDFViewControllerProxy.h"
#import "TIPSPDFViewController.h"
#import "ComPspdfkitModule.h"
#import "TiUtils.h"
#import "TiApp.h"
#import "TiBase.h"
#import "PSPDFUtils.h"
#import "ComPspdfkitViewProxy.h"
#import <objc/runtime.h>

@interface TIPSPDFViewControllerProxy() {
    KrollCallback *_didTapOnAnnotationCallback;
    __weak TiProxy *_parentProxy;
}
@property(atomic, assign) UIInterfaceOrientation lockedInterfaceOrientationValue;
@property(atomic, strong) UIColor *linkAnnotationBorderBackedColor;
@property(atomic, strong) UIColor *linkAnnotationHighlightBackedColor;
@end

@implementation TIPSPDFViewControllerProxy

@synthesize controller = _controller;
@synthesize lockedInterfaceOrientationValue = _lockedInterfaceOrientationValue;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithPDFController:(TIPSPDFViewController *)pdfController context:(id<TiEvaluator>)context parentProxy:(TiProxy *)parentProxy {
    if ((self = [super _initWithPageContext:context])) {
        PSTiLog(@"init TIPSPDFViewControllerProxy");
        _parentProxy = parentProxy;
        _lockedInterfaceOrientationValue = -1;
        _controller = pdfController;
        _controller.delegate = self;
        // As long as pdfController exists, we're not getting released.
        pdfController.proxy = self;
        self.modelDelegate = self;
    }
    return self;
}

- (void)dealloc {
    PSTiLog(@"Deallocating proxy %@", self);
}

- (TiProxy *)parentForBubbling {
    return _parentProxy;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (id)page {
    __block NSUInteger page = 0;
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            page = [[self page] unsignedIntegerValue];
        });
    }else {
        page = _controller.page;
    }

    return @(page);
}

- (id)totalPages {
    __block NSUInteger totalPages = 0;
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            totalPages = [[self totalPages] unsignedIntegerValue];
        });
    }else {
        totalPages = [[NSNumber numberWithInteger:[_controller.document pageCount]] unsignedIntegerValue];
    }

    return @(totalPages);
}

- (id)documentPath {
    return [[_controller.document fileURL] path];
}

- (void)setLinkAnnotationBorderColor:(id)arg {
    ENSURE_UI_THREAD(setLinkAnnotationBorderColor, arg);

    self.linkAnnotationBorderBackedColor = [PSPDFUtils colorFromArg:arg];
    // Ensure controller is reloaded.
    [self.controller reloadData];
}

- (void)setLinkAnnotationHighlightColor:(id)arg {
    ENSURE_UI_THREAD(setLinkAnnotationHighlightColor, arg);

    self.linkAnnotationHighlightBackedColor = [PSPDFUtils colorFromArg:arg];
    // Ensure controller is reloaded.
    [self.controller reloadData];
}

- (void)setEditableAnnotationTypes:(id)arg {
    ENSURE_UI_THREAD(setEditableAnnotationTypes, arg);
    
    NSMutableOrderedSet *editableAnnotationTypes = [NSMutableOrderedSet orderedSet];
    if ([arg isKindOfClass:NSArray.class]) {
        for (__strong NSString *item in arg) {
            item = PSSafeCast(item, NSString.class);
            if (PSPDFAnnotationTypeFromString(item) > 0) {
                [editableAnnotationTypes addObject:item];
            }
        }
    }
    self.controller.document.editableAnnotationTypes = editableAnnotationTypes;
    [self.controller reloadData];
}

- (void)setThumbnailFilterOptions:(id)arg {
    ENSURE_UI_THREAD(setThumbnailFilterOptions, arg);

    NSMutableOrderedSet *filterOptions = [NSMutableOrderedSet orderedSetWithCapacity:3];
    if ([arg isKindOfClass:NSArray.class]) {
        for (__strong NSString *filter in arg) {
            filter = [PSSafeCast(filter, NSString.class) lowercaseString];
            if ([filter isEqual:@"all"]) {
                [filterOptions addObject:@(PSPDFThumbnailViewFilterShowAll)];
            }else if ([filter isEqual:@"bookmarks"]) {
                [filterOptions addObject:@(PSPDFThumbnailViewFilterBookmarks)];
            }else if ([filter isEqual:@"annotations"]) {
                [filterOptions addObject:@(PSPDFThumbnailViewFilterAnnotations)];
            }
        }
    }
    _controller.thumbnailController.filterOptions = filterOptions;
}

- (void)setOutlineControllerFilterOptions:(id)arg {
    ENSURE_UI_THREAD(setOutlineControllerFilterOptions, arg);

    NSMutableOrderedSet *filterOptions = [NSMutableOrderedSet orderedSetWithCapacity:3];
    if ([arg isKindOfClass:NSArray.class]) {
        for (__strong NSString *filter in arg) {
            filter = [PSSafeCast(filter, NSString.class) lowercaseString];
            if ([filter isEqual:@"outline"]) {
                [filterOptions addObject:@(PSPDFOutlineBarButtonItemOptionOutline)];
            }else if ([filter isEqual:@"bookmarks"]) {
                [filterOptions addObject:@(PSPDFOutlineBarButtonItemOptionBookmarks)];
            }else if ([filter isEqual:@"annotations"]) {
                [filterOptions addObject:@(PSPDFOutlineBarButtonItemOptionAnnotations)];
            }
        }
    }
    _controller.outlineButtonItem.availableControllerOptions = filterOptions;
}

- (void)setAllowedMenuActions:(id)arg {
    ENSURE_UI_THREAD(setAllowedMenuActions, arg);

    NSMutableOrderedSet *menuActions = [NSMutableOrderedSet orderedSetWithCapacity:3];
    if ([arg isKindOfClass:NSArray.class]) {
        for (__strong NSString *filter in arg) {
            filter = [PSSafeCast(filter, NSString.class) lowercaseString];
            if ([filter isEqual:@"search"]) {
                [menuActions addObject:@(PSPDFTextSelectionMenuActionSearch)];
            }else if ([filter isEqual:@"define"]) {
                [menuActions addObject:@(PSPDFTextSelectionMenuActionDefine)];
            }else if ([filter isEqual:@"wikipedia"]) {
                [menuActions addObject:@(PSPDFTextSelectionMenuActionWikipedia)];
            }
        }
    }
    _controller.allowedMenuActions = menuActions;
}

- (void)setScrollingEnabled:(id)args {
    ENSURE_UI_THREAD(setScrollingEnabled, args);

    NSUInteger pageValue = [PSPDFUtils intValue:args onPosition:0];
    [_controller setScrollingEnabled:pageValue];
}

- (void)scrollToPage:(id)args {
    ENSURE_UI_THREAD(scrollToPage, args);

    PSCLog(@"scrollToPage: %@", args);
    NSUInteger pageValue = [PSPDFUtils intValue:args onPosition:0];
    NSUInteger animationValue = [PSPDFUtils intValue:args onPosition:1];
    BOOL animated = animationValue == NSNotFound || animationValue == 1;
    [_controller setPage:pageValue animated:animated];
}

- (void)setViewMode:(id)args {
    ENSURE_UI_THREAD(setViewMode, args);

    PSCLog(@"setViewMode: %@", args);
    NSUInteger viewModeValue = [PSPDFUtils intValue:args onPosition:0];
    NSUInteger animationValue = [PSPDFUtils intValue:args onPosition:1];
    BOOL animated = animationValue == NSNotFound || animationValue == 1;
    [_controller setViewMode:viewModeValue animated:animated];
}

- (void)searchForString:(id)args {
    ENSURE_UI_THREAD(searchForString, args);

    if (![args isKindOfClass:NSArray.class] || [args count] < 1 || ![args[0] isKindOfClass:NSString.class]) {
        PSCLog(@"Argument error, expected 1-2 arguments: %@", args);
        return;
    }

    PSCLog(@"searchForString: %@", args);
    NSString *searchString = args[0];
    BOOL animated = [PSPDFUtils intValue:args onPosition:1] > 0;
    [_controller searchForString:searchString options:nil animated:animated];
}

- (void)close:(id)args {
    ENSURE_UI_THREAD(close, args);

    PSCLog(@"Closing controller: %@", _controller);
    NSUInteger animationValue = [PSPDFUtils intValue:args onPosition:1];
    BOOL animated = animationValue == NSNotFound || animationValue == 1;

    [_controller closeControllerAnimated:animated];
}

- (void)setDidTapOnAnnotationCallback:(id)callback {
    ENSURE_SINGLE_ARG(callback, KrollCallback);

    PSCLog(@"registering annotation callback: %@", callback);
    if (_didTapOnAnnotationCallback != callback) {
        _didTapOnAnnotationCallback = callback;
    }
}

- (id)currentInterfaceOrientation {
    __block UIInterfaceOrientation interfaceOrientation;
    dispatch_sync(dispatch_get_main_queue(), ^{
        interfaceOrientation = self.controller.interfaceOrientation;
    });
    return @(interfaceOrientation);
}

- (id)lockedInterfaceOrientation {
    return @(self.lockedInterfaceOrientationValue);
}

- (void)setLockedInterfaceOrientation:(id)arg {
    ENSURE_SINGLE_ARG(arg, NSNumber);
    ENSURE_UI_THREAD(setLockedInterfaceOrientation, arg);

    UIInterfaceOrientation interfaceOrientation = [arg integerValue];
    if(UIDeviceOrientationIsValidInterfaceOrientation(interfaceOrientation) || (int)interfaceOrientation == -1) {
        self.lockedInterfaceOrientationValue = interfaceOrientation;
    }

    [UIViewController attemptRotationToDeviceOrientation];
}

- (void)saveAnnotations:(id)args {
    ENSURE_UI_THREAD(saveAnnotations, args);

    NSError *error = nil;
    BOOL success = [_controller.document saveAnnotationsWithError:&error];
    if (!success && [PSPDFTextSelectionView isTextSelectionFeatureAvailable]) {
        PSCLog(@"Saving annotations failed: %@", [error localizedDescription]);
    }
    [[self eventProxy] fireEvent:@"didSaveAnnotations" withObject:@{@"success" : @(success)}];
}

- (void)setAnnotationSaveMode:(id)arg {
    ENSURE_SINGLE_ARG(arg, NSNumber);
    ENSURE_UI_THREAD(setAnnotationSaveMode, arg);

    PSPDFAnnotationSaveMode annotationSaveMode = [arg integerValue];
    _controller.document.annotationSaveMode = annotationSaveMode;
}

- (void)setPrintOptions:(id)arg {
    ENSURE_SINGLE_ARG(arg, NSNumber);
    ENSURE_UI_THREAD(setPrintOptions, arg);

    _controller.printButtonItem.printOptions = [arg integerValue];
}

- (void)setSendOptions:(id)arg {
    ENSURE_SINGLE_ARG(arg, NSNumber);
    ENSURE_UI_THREAD(setSendOptions, arg);

    _controller.emailButtonItem.sendOptions = [arg integerValue];
}

- (void)setOpenInOptions:(id)arg {
    ENSURE_SINGLE_ARG(arg, NSNumber);
    ENSURE_UI_THREAD(setOpenInOptions, arg);

    _controller.openInButtonItem.openOptions = [arg integerValue];
}

- (void)hidePopover:(id)args {
    ENSURE_UI_THREAD(hidePopover, args);

    BOOL animated = [args count] == 1 && [args[0] boolValue];
    [PSPDFBarButtonItem dismissPopoverAnimated:animated completion:NULL];
    [self.controller.popoverController dismissPopoverAnimated:animated];
}

- (void)showBarButton:(SEL)barButtonSEL action:(id)action {
    dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [[self.controller performSelector:barButtonSEL] action:action ? [action[0] view] : self];
#pragma clang diagnostic pop
    });
}

- (void)showOutlineView:(id)arg {
    [self showBarButton:@selector(outlineButtonItem) action:arg];
}

- (void)showSearchView:(id)arg {
    [self showBarButton:@selector(searchButtonItem) action:arg];
}

- (void)showBrightnessView:(id)arg {
    [self showBarButton:@selector(brightnessButtonItem) action:arg];
}

- (void)showPrintView:(id)arg {
    [self showBarButton:@selector(printButtonItem) action:arg];
}

- (void)showEmailView:(id)arg {
    [self showBarButton:@selector(emailButtonItem) action:arg];
}

- (void)showAnnotationView:(id)arg {
    [self showBarButton:@selector(annotationButtonItem) action:arg];
}

- (void)showOpenInView:(id)arg {
    [self showBarButton:@selector(openInButtonItem) action:arg];
}

- (void)showActivityView:(id)arg {
    [self showBarButton:@selector(activityButtonItem) action:arg];
}

- (void)bookmarkPage:(id)arg {
    ENSURE_UI_THREAD(bookmarkPage, arg);
    [self.controller.bookmarkButtonItem action:self];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - TiProxyDelegate

- (void)propertyChanged:(NSString*)key oldValue:(id)oldValue newValue:(id)newValue proxy:(TiProxy *)proxy {
    PSCLog(@"Received property change: %@ -> %@", key, newValue);

    // PSPDFViewController is *not* thread safe. only set on main thread.
    ps_dispatch_main_async(^{
        [PSPDFUtils applyOptions:@{key: newValue} onObject:_controller];
    });
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PSPDFViewControllerDelegate

- (TiProxy *)eventProxy {
    ComPspdfkitViewProxy *viewProxy = [self viewProxy];
    PSTiLog(@"viewProxy_: %@ self: %@", viewProxy, self);
    TiProxy *eventProxy = viewProxy ?: self;
    PSTiLog(@"eventProxy: %@: %@", viewProxy ? @"view" : @"self", eventProxy)
    return eventProxy;
}

/// delegate for tapping on an annotation. If you don't implement this or return false, it will be processed by default action (scroll to page, ask to open Safari)
- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnAnnotation:(PSPDFAnnotation *)annotation annotationPoint:(CGPoint)annotationPoint annotationView:(UIView<PSPDFAnnotationViewProtocol> *)annotationView pageView:(PSPDFPageView *)pageView viewPoint:(CGPoint)viewPoint {
    NSParameterAssert([pdfController isKindOfClass:[TIPSPDFViewController class]]);

    NSMutableDictionary *eventDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:pageView.page], @"page", nil];
    // only set a subset
    if ([annotation isKindOfClass:[PSPDFLinkAnnotation class]]) {
        PSPDFLinkAnnotation *linkAnnotation = (PSPDFLinkAnnotation *)annotation;

        if (linkAnnotation.URL) {
            eventDict[@"URL"] = linkAnnotation.URL;
            eventDict[@"siteLinkTarget"] = linkAnnotation.URL.absoluteString;
        }else if (linkAnnotation.linkType == PSPDFLinkAnnotationPage) {
            // We don't forward all proxy types.
            if ([linkAnnotation.action respondsToSelector:@selector(pageIndex)]) {
                eventDict[@"pageIndex"] = @(((PSPDFGoToAction *)linkAnnotation.action).pageIndex);
                eventDict[@"pageLinkTarget"] = @(((PSPDFGoToAction *)linkAnnotation.action).pageIndex); // Deprecated
            }
        }

        PSPDFAction *action = linkAnnotation.action;
        if (action) {
            if (action.type == PSPDFActionTypeRemoteGoTo) {
                eventDict[@"relativePath"] = ((PSPDFRemoteGoToAction *)action).relativePath;
                eventDict[@"pageIndex"] = @(((PSPDFRemoteGoToAction *)action).pageIndex);
            }

            // Translate the type.
            id actionTypeString = [[NSValueTransformer valueTransformerForName:PSPDFActionTypeTransformerName] reverseTransformedValue:@(action.type)];
            if (actionTypeString) eventDict[@"actionType"] = actionTypeString;
        }
    }

    BOOL processed = NO;
    if(_didTapOnAnnotationCallback) {
        id retVal = [_didTapOnAnnotationCallback call:@[eventDict] thisObject:nil];
        processed = [retVal boolValue];
        PSCLog(@"retVal: %d", processed);
    }
    
    if ([[self eventProxy] _hasListeners:@"didTapOnAnnotation"]) {
        [[self eventProxy] fireEvent:@"didTapOnAnnotation" withObject:eventDict];
    }
    return processed;
}

/// controller did show/scrolled to a new page (at least 51% of it is visible)
- (void)pdfViewController:(PSPDFViewController *)pdfController didShowPageView:(PSPDFPageView *)pageView {
    if ([[self eventProxy] _hasListeners:@"didShowPage"]) {
        NSDictionary *eventDict = @{@"page": [NSNumber numberWithInteger:pageView.page]};
        [[self eventProxy] fireEvent:@"didShowPage" withObject:eventDict];
    }
}

/// page was fully rendered at zoomlevel = 1
- (void)pdfViewController:(PSPDFViewController *)pdfController didRenderPageView:(PSPDFPageView *)pageView {
    if ([[self eventProxy] _hasListeners:@"didRenderPage"]) {
        NSDictionary *eventDict = @{@"page": [NSNumber numberWithInteger:pageView.page]};
        [[self eventProxy] fireEvent:@"didRenderPage" withObject:eventDict];
    }
}

/// will be called when viewMode changes
- (void)pdfViewController:(PSPDFViewController *)pdfController didChangeViewMode:(PSPDFViewMode)viewMode {
    if ([[self eventProxy] _hasListeners:@"didChangeViewMode"]) {
        NSDictionary *eventDict = @{@"viewMode": @(viewMode)};
        [[self eventProxy] fireEvent:@"didChangeViewMode" withObject:eventDict];
    }
}

- (UIView <PSPDFAnnotationViewProtocol> *)pdfViewController:(PSPDFViewController *)pdfController annotationView:(UIView <PSPDFAnnotationViewProtocol> *)annotationView forAnnotation:(PSPDFAnnotation *)annotation onPageView:(PSPDFPageView *)pageView {

    if (annotation.type == PSPDFAnnotationTypeLink && [annotationView isKindOfClass:[PSPDFLinkAnnotationView class]]) {
        PSPDFLinkAnnotationView *linkAnnotation = (PSPDFLinkAnnotationView *)annotationView;
        if (self.linkAnnotationBorderBackedColor) {
            linkAnnotation.borderColor = self.linkAnnotationBorderBackedColor;
        }
        // TODO
        //if (self.linkAnnotationHighlightBackedColor) {
        //    linkAnnotation.highlightBackgroundColor = self.linkAnnotationHighlightBackedColor;
        //}
    }
    return annotationView;
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldShowHUD:(BOOL)animated {
    if ([[self eventProxy] _hasListeners:@"shouldShowHUD"]) {
        [[self eventProxy] fireEvent:@"shouldShowHUD" withObject:nil];
    }
    if ([[self eventProxy] _hasListeners:@"willShowHUD"]) {
        [[self eventProxy] fireEvent:@"willShowHUD" withObject:nil];
    }
    return YES;
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didShowHUD:(BOOL)animated {
    if ([[self eventProxy] _hasListeners:@"didShowHUD"]) {
        [[self eventProxy] fireEvent:@"didShowHUD" withObject:nil];
    }
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldHideHUD:(BOOL)animated {
    if ([[self eventProxy] _hasListeners:@"shouldHideHUD"]) {
        [[self eventProxy] fireEvent:@"shouldHideHUD" withObject:nil];
    }
    if ([[self eventProxy] _hasListeners:@"willHideHUD"]) {
        [[self eventProxy] fireEvent:@"willHideHUD" withObject:nil];
    }
    return YES;
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didHideHUD:(BOOL)animated {
    if ([[self eventProxy] _hasListeners:@"didHideHUD"]) {
        [[self eventProxy] fireEvent:@"didHideHUD" withObject:nil];
    }
}

@end

id PSSafeCast(id object, Class targetClass) {
    NSCParameterAssert(targetClass);
    return [object isKindOfClass:targetClass] ? object : nil;
}
