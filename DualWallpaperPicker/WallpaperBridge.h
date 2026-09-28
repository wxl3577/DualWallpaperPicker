#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface WallpaperBridge : NSObject
+ (BOOL)applyLockImage:(UIImage *)lockImage homeImage:(UIImage *)homeImage error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
