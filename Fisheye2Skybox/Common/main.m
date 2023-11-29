/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main app entry point.
*/

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#import <Availability.h>
#import "AppDelegate.h"
#else
#import <Cocoa/Cocoa.h>
#endif

#if TARGET_OS_IOS || TARGET_OS_TV

int main(int argc, char * argv[]) {

#if TARGET_OS_SIMULATOR && (!defined(__IPHONE_13_0) ||  !defined(__TVOS_13_0))
//#error Metal is not supported in this version of Simulator.
#endif

    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

#elif TARGET_OS_MAC

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

#endif
