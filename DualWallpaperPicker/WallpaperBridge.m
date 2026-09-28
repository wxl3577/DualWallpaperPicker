#import "WallpaperBridge.h"
#import <dlfcn.h>
#import <TargetConditionals.h>

// Runtime declarations only; no private framework is linked at launch.
typedef NSInteger (*SetImagesFunction)(NSDictionary *, NSDictionary *, NSInteger, NSInteger);

static BOOL Fail(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"DualWallpaper" code:1
                                      userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

static void SetScalar(id object, NSString *name, void *value) {
    SEL selector = NSSelectorFromString(name);
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 3)
        @throw [NSException exceptionWithName:@"UnsupportedWallpaperAPI" reason:@"系统壁纸参数接口不兼容。" userInfo:nil];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = object;
    invocation.selector = selector;
    [invocation setArgument:value atIndex:2];
    [invocation invoke];
}

static id Options(Class cls, NSInteger mode) {
    id options = [[cls alloc] init];
    double parallax = 0.0;
    double zoom = 1.0;
    bool magnify = false;
    SetScalar(options, @"setWallpaperMode:", &mode);
    SetScalar(options, @"setParallaxFactor:", &parallax);
    // Disable the independent magnification option as well as motion.
    // Leave crop geometry to the system; 1.0 adds no explicit zoom.
    SetScalar(options, @"setMagnifyEnabled:", &magnify);
    SetScalar(options, @"setZoomScale:", &zoom);
    if ([[options valueForKey:@"parallaxEnabled"] boolValue] ||
        [[options valueForKey:@"magnifyEnabled"] boolValue]) {
        @throw [NSException exceptionWithName:@"UnsupportedWallpaperAPI"
                                     reason:@"系统未接受关闭视角缩放的参数。" userInfo:nil];
    }
    return options;
}

@implementation WallpaperBridge
+ (BOOL)applyLockImage:(UIImage *)lockImage homeImage:(UIImage *)homeImage error:(NSError **)error {
#if TARGET_OS_SIMULATOR
    return Fail(error, @"直接设置需要 iOS 15 真机及壁纸设置权限，模拟器不支持。");
#else
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 15)
        return Fail(error, @"直接设置目前仅适配 iOS 15。");
    static void *foundation;
    static void *services;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        foundation = dlopen("/System/Library/PrivateFrameworks/SpringBoardFoundation.framework/SpringBoardFoundation", RTLD_LAZY);
        services = dlopen("/System/Library/PrivateFrameworks/SpringBoardUIServices.framework/SpringBoardUIServices", RTLD_LAZY);
    });
    if (!foundation || !services) return Fail(error, @"系统壁纸服务不可用，请确认系统版本与安装权限。");
    SetImagesFunction setter = (SetImagesFunction)dlsym(services, "SBSUIWallpaperSetImages");
    Class cls = NSClassFromString(@"SBFWallpaperOptions");
    if (!setter || !cls) return Fail(error, @"系统未提供兼容的壁纸接口。");
    @try {
        // Construct all options before modifying either wallpaper. Mode 1/2 denotes
        // light/dark appearance, while target 1/2 denotes lock/home screen.
        NSDictionary *lockOptions = @{@"light": Options(cls, 1), @"dark": Options(cls, 2)};
        NSDictionary *homeOptions = @{@"light": Options(cls, 1), @"dark": Options(cls, 2)};
        NSInteger style = UIScreen.mainScreen.traitCollection.userInterfaceStyle;
        NSInteger lockResult = setter(@{@"light": lockImage, @"dark": lockImage}, lockOptions, 1, style);
        NSInteger homeResult = setter(@{@"light": homeImage, @"dark": homeImage}, homeOptions, 2, style);
        NSLog(@"Wallpaper requests returned lock=%ld home=%ld", (long)lockResult, (long)homeResult);
        // This undocumented API has no reliable read-back here. The UI reports
        // submission rather than claiming the actual wallpapers were verified.
        return YES;
    } @catch (NSException *exception) {
        return Fail(error, [NSString stringWithFormat:@"壁纸请求未完成（可能已设置其中一张）：%@。请重新选择后再试。", exception.reason ?: @"接口不兼容"]);
    }
#endif
}
@end
