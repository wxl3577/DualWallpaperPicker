#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@interface WallpaperBridge : NSObject
+ (BOOL)applyLockImage:(UIImage * _Nullable)lockImage homeImage:(UIImage * _Nullable)homeImage error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
