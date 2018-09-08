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
static CGFloat sCurrentYOffset = 0;
static CGFloat sBeginYOffset = 0;
static CGFloat sEndYOffset = 0;
static UILabel *sLabelInfo = nil;
static UIView *sContainerView = nil;

//////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DDParsecTableViewController : UITableViewController
@end

@class DDParsecTableViewController;
CHDeclareClass(DDParsecTableViewController); // declare class

CHOptimizedMethod(1, self, void, DDParsecTableViewController, viewWillAppear,BOOL,value1)
{
    sContainerView = self.view;
    NSLog(@"qiweidict : view will appear");
    CHSuper(1, DDParsecTableViewController, viewWillAppear, value1);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDParsecServiceCollectionViewController : UINavigationController<UITableViewDelegate>
- (void)doneButtonPressed:(id)arg1;
@end

@class DDParsecServiceCollectionViewController;
CHDeclareClass(DDParsecServiceCollectionViewController); // declare class

CHOptimizedMethod(1, self, void, DDParsecServiceCollectionViewController, scrollViewDidScroll,UIScrollView*,scrollView)
{
//    NSLog(@"qiweidict : content offset = %@",@(scrollView.contentOffset.y));
    sCurrentYOffset = scrollView.contentOffset.y;
    if(sBeginYOffset != 0){
        CGFloat length = fabs(sCurrentYOffset - sBeginYOffset);
        NSLog(@"qiweidict : offset length = %@",@(length));
        if(length > kThreshold){
            if(!sLabelInfo && sContainerView){
                CGSize screenSize = [UIScreen mainScreen].bounds.size;
                sLabelInfo = [[UILabel alloc]init];
                sLabelInfo.bounds = CGRectMake(0, 0, 130, 20);
                sLabelInfo.center = CGPointMake(screenSize.width / 2, -10);
                sLabelInfo.text = @"Release to close";
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
    CHSuper(1, DDParsecServiceCollectionViewController, scrollViewDidScroll,scrollView);
}

@interface DDParsecServiceCollectionViewController (dictionarypulldowntoclose)
@end

@implementation DDParsecServiceCollectionViewController (dictionarypulldowntoclose)

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    sBeginYOffset = sCurrentYOffset;
    NSLog(@"qiweidict : begin drag = %@",@(sBeginYOffset));
}
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset{
    sEndYOffset = sCurrentYOffset;
    CGFloat length = fabs(sEndYOffset - sBeginYOffset);
    NSLog(@"qiweidict : end drag = %@, length = %@",@(sEndYOffset), @(length));
    
    if(length > kThreshold){
        NSLog(@"qiweidict : should pull down to close");
        [self doneButtonPressed:nil];
    }
    
    sBeginYOffset = 0;
}

@end

CHConstructor // code block that runs immediately upon load
{
	@autoreleasepool
	{
        CHLoadLateClass(DDParsecTableViewController);
        CHLoadLateClass(DDParsecServiceCollectionViewController);
        
        CHHook(1, DDParsecTableViewController, viewWillAppear);
        CHHook(1, DDParsecServiceCollectionViewController, scrollViewDidScroll); // register hook
	}
}
