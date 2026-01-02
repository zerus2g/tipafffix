#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../Core/GameLogic.h"

// [SHADOW-CORE] Cấu trúc dữ liệu Xương
// Lưu tọa độ 2D trên màn hình của các bộ phận
@interface ESPSkeleton : NSObject
@property (assign) CGPoint head;
@property (assign) CGPoint neck;
@property (assign) CGPoint pelvis; // Hông
@property (assign) CGPoint leftShoulder;
@property (assign) CGPoint rightShoulder;
@property (assign) CGPoint leftHand;
@property (assign) CGPoint rightHand;
@property (assign) CGPoint leftKnee;
@property (assign) CGPoint rightKnee;
@property (assign) CGPoint leftFoot;
@property (assign) CGPoint rightFoot;
@property (assign) BOOL isValid; // Check xem có đọc được xương không
@end

@interface ESPItem : NSObject
@property (assign) CGRect frame;      // Vị trí Box
@property (copy) NSString *name;      // Tên
@property (assign) int hp;            // Máu
@property (assign) int maxHp;         // Max Máu
@property (assign) float distance;    // Khoảng cách
@property (strong) ESPSkeleton *bone; // [NEW] Dữ liệu xương
@end

@interface ESP_View : UIView
@property (assign) BOOL enableLine;     // Config: Bật Line
@property (assign) BOOL enableSkeleton; // Config: Bật Xương
@property (assign) BOOL enableBox;      // Config: Bật Box

- (instancetype)initWithFrame:(CGRect)frame;
- (void)setESPData:(NSArray<ESPItem *> *)data;
- (void)updateRendering;
- (void)readMemory;
@end