//
//  DictionaryPullDownToClose.mm
//  DictionaryPullDownToClose
//
//  Created by everettjf on 2018/9/7.
//  Copyright (c) 2018 ___ORGANIZATIONNAME___. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "CaptainHook/CaptainHook.h"

// Objective-C runtime hooking using CaptainHook:
//   1. declare class using CHDeclareClass()
//   2. load class using CHLoadClass() or CHLoadLateClass() in CHConstructor
//   3. hook method using CHOptimizedMethod()
//   4. register hook using CHHook() in CHConstructor
//   5. (optionally) call old method using CHSuper()

static CGFloat kThreshold = 80;

@interface DDParsecServiceCollectionViewController : UINavigationController<UITableViewDelegate>
- (void)doneButtonPressed:(id)arg1;
@end

static DDParsecServiceCollectionViewController * sController;

namespace {
    class ScrollHelper
    {
    public:
        CGFloat sBeginYOffset = 0;
        CGFloat sEndYOffset = 0;
        UILabel *sLabelInfo = nil;
        UIView *sContainerView = nil;
        bool sTipPositionFirstPage = true;
        bool sEnable = false;

        void scrollViewDidScroll(UIScrollView * scrollView){
            if(!sEnable)return;
            
            if(sBeginYOffset != 0){
                CGFloat length = scrollView.contentOffset.y - sBeginYOffset;
//                NSLog(@"qiweidict : offset length = %@",@(length));
                if(fabs(length) > kThreshold && length < 0){
                    if(!sLabelInfo && sContainerView){
                        CGSize screenSize = [UIScreen mainScreen].bounds.size;
                        sLabelInfo = [[UILabel alloc]init];
                        sLabelInfo.bounds = CGRectMake(0, 0, 130, 20);
                        if(sTipPositionFirstPage){
                            sLabelInfo.center = CGPointMake(screenSize.width / 2, -10);
                        }else{
                            sLabelInfo.center = CGPointMake(screenSize.width / 2, 100);
                        }
                        sLabelInfo.text = @"release to close";
                        sLabelInfo.textColor = [UIColor grayColor];
                        [sContainerView addSubview:sLabelInfo];
                    }
                }else{
                    if(sLabelInfo){
                        [sLabelInfo removeFromSuperview];
                        sLabelInfo = nil;
                    }
                    
                }
            }
        }
        void scrollViewWillBeginDragging(UIScrollView * scrollView){
//            NSLog(@"qiweidict : begin %@",@(scrollView.contentOffset.y));
            if(scrollView.contentOffset.y <= 0)sEnable = true;
            else sEnable = false;
            if(!sEnable)return;

            sBeginYOffset = scrollView.contentOffset.y;
//            NSLog(@"qiweidict : begin drag = %@",@(sBeginYOffset));
        }
        void scrollViewWillEndDragging(UIScrollView * scrollView, void (^done)()){
            if(!sEnable)return;
            sEndYOffset = scrollView.contentOffset.y;
            CGFloat length = sEndYOffset - sBeginYOffset;
//            NSLog(@"qiweidict : end drag = %@, length = %@",@(sEndYOffset), @(length));
            
            if(sEndYOffset < sBeginYOffset && fabs(length) > kThreshold && length < 0){
//                NSLog(@"qiweidict : should pull down to close");
                if(done) done();
            }
            
            sBeginYOffset = 0;
            sEndYOffset = 0;
        }
    };
}

static ScrollHelper a;
static ScrollHelper b;


//////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DDParsecTableViewController : UITableViewController
@end

@class DDParsecTableViewController;
CHDeclareClass(DDParsecTableViewController); // declare class

CHOptimizedMethod(1, self, void, DDParsecTableViewController, viewDidAppear,BOOL,value1)
{
//    NSLog(@"qiweidict : first page viewDidAppear %@ , navi = %@",self,self.navigationController);
    a.sContainerView = self.view;
    a.sTipPositionFirstPage = true;
    sController = (DDParsecServiceCollectionViewController *)self.navigationController;

    CHSuper(1, DDParsecTableViewController, viewDidAppear, value1);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////


@class DDParsecServiceCollectionViewController;
CHDeclareClass(DDParsecServiceCollectionViewController); // declare class

CHOptimizedMethod(1, self, void, DDParsecServiceCollectionViewController, scrollViewDidScroll,UIScrollView*,scrollView)
{
    a.scrollViewDidScroll(scrollView);
    CHSuper(1, DDParsecServiceCollectionViewController, scrollViewDidScroll,scrollView);
}

@interface DDParsecServiceCollectionViewController (dictionarypulldowntoclose)
@end

@implementation DDParsecServiceCollectionViewController (dictionarypulldowntoclose)

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    a.scrollViewWillBeginDragging(scrollView);
}
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    a.scrollViewWillEndDragging(scrollView,^{
        [self doneButtonPressed:nil];
    });
}

@end

///////////////////////////////////////////////////////////////////////////////////////////////////

@interface DUEntryViewController : UIViewController<UIScrollViewDelegate>
@end

@interface DUEntryViewController (dictionarypulldowntoclose)
@end
@implementation DUEntryViewController (dictionarypulldowntoclose)
- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
//    NSLog(@"qiweidict: did scroll : %@",@(scrollView.contentOffset.y));
    b.sTipPositionFirstPage = false;
    b.scrollViewDidScroll(scrollView);
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    b.scrollViewWillBeginDragging(scrollView);
}
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    b.scrollViewWillEndDragging(scrollView,^{
//        NSLog(@"qiweidict : need close now");
        [sController doneButtonPressed:nil];
    });
}
@end

@class DUEntryViewController;
CHDeclareClass(DUEntryViewController); // declare class

CHOptimizedMethod(0, self, void, DUEntryViewController, viewDidLoad)
{
//    NSLog(@"qiweidict : detail viewDidLoad %p %@",self,self);
    CHSuper(0, DUEntryViewController, viewDidLoad);
    
    b.sContainerView = self.view;

    UIView *view = self.view;
    if(view.subviews.count > 0){
        UIWebView *webView = view.subviews[0];
        webView.scrollView.delegate = self;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////

CHConstructor // code block that runs immediately upon load
{
	@autoreleasepool
	{
        CHLoadLateClass(DDParsecTableViewController);
        CHLoadLateClass(DDParsecServiceCollectionViewController);
        CHLoadLateClass(DUEntryViewController);
        
        CHHook(1, DDParsecTableViewController, viewDidAppear);
        CHHook(1, DDParsecServiceCollectionViewController, scrollViewDidScroll); // register hook
        CHHook(0, DUEntryViewController, viewDidLoad);
	}
}
