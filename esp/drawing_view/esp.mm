#import "esp.h"

#define sWidth  [UIScreen mainScreen].bounds.size.width
#define sHeight [UIScreen mainScreen].bounds.size.height

@implementation ESPSkeleton @end
@implementation ESPItem @end

// --- [SHADOW-CORE] LAYER ĐỊCH (FULL OPTION) ---
@interface ESPEnemyLayer : CALayer
@property (strong) CALayer *boxLayer;
@property (strong) CATextLayer *textLayer;
@property (strong) CALayer *hpBackLayer;
@property (strong) CALayer *hpFillLayer;
@property (strong) CAShapeLayer *lineLayer;      // [NEW] Layer vẽ dây
@property (strong) CAShapeLayer *skeletonLayer;  // [NEW] Layer vẽ xương
@end

@implementation ESPEnemyLayer
- (instancetype)init {
    self = [super init];
    if (self) {
        // 1. Snapline (Dây)
        _lineLayer = [CAShapeLayer layer];
        _lineLayer.strokeColor = [UIColor whiteColor].CGColor;
        _lineLayer.lineWidth = 1.0;
        _lineLayer.fillColor = [UIColor clearColor].CGColor;
        [self addSublayer:_lineLayer];

        // 2. Skeleton (Xương)
        _skeletonLayer = [CAShapeLayer layer];
        _skeletonLayer.strokeColor = [UIColor yellowColor].CGColor; // Xương màu vàng
        _skeletonLayer.lineWidth = 1.2;
        _skeletonLayer.fillColor = [UIColor clearColor].CGColor;
        [self addSublayer:_skeletonLayer];

        // 3. Box
        _boxLayer = [CALayer layer];
        _boxLayer.borderColor = [UIColor redColor].CGColor;
        _boxLayer.borderWidth = 1.0;
        [self addSublayer:_boxLayer];

        // 4. Health Bar
        _hpBackLayer = [CALayer layer];
        _hpBackLayer.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6].CGColor;
        [self addSublayer:_hpBackLayer];

        _hpFillLayer = [CALayer layer];
        [self addSublayer:_hpFillLayer];

        // 5. Text
        _textLayer = [CATextLayer layer];
        _textLayer.fontSize = 9;
        _textLayer.foregroundColor = [UIColor whiteColor].CGColor;
        _textLayer.alignmentMode = kCAAlignmentCenter;
        _textLayer.contentsScale = [UIScreen mainScreen].scale;
        _textLayer.shadowOpacity = 0.8;
        _textLayer.shadowOffset = CGSizeMake(1, 1);
        [self addSublayer:_textLayer];
    }
    return self;
}

- (void)updateWithItem:(ESPItem *)item config:(ESP_View *)config {
    self.hidden = NO;
    
    // --- DRAW BOX ---
    if (config.enableBox) {
        _boxLayer.hidden = NO;
        _boxLayer.frame = item.frame;
    } else {
        _boxLayer.hidden = YES;
    }

    // --- DRAW SNAPLINE (Dây nối từ giữa dưới màn hình đến chân địch) ---
    if (config.enableLine) {
        _lineLayer.hidden = NO;
        UIBezierPath *linePath = [UIBezierPath bezierPath];
        // Điểm bắt đầu: Giữa mép dưới màn hình
        [linePath moveToPoint:CGPointMake(sWidth / 2, sHeight)];
        // Điểm kết thúc: Chân địch (giữa cạnh dưới Box)
        CGPoint feetPos = CGPointMake(item.frame.origin.x + item.frame.size.width / 2, 
                                      item.frame.origin.y + item.frame.size.height);
        [linePath addLineToPoint:feetPos];
        _lineLayer.path = linePath.CGPath;
    } else {
        _lineLayer.hidden = YES;
    }

    // --- DRAW SKELETON (Khung xương) ---
    if (config.enableSkeleton && item.bone && item.bone.isValid) {
        _skeletonLayer.hidden = NO;
        UIBezierPath *skelPath = [UIBezierPath bezierPath];
        
        // Helper block để vẽ đường
        void (^addLine)(CGPoint, CGPoint) = ^(CGPoint p1, CGPoint p2) {
            [skelPath moveToPoint:p1];
            [skelPath addLineToPoint:p2];
        };

        ESPSkeleton *b = item.bone;
        
        // Thân người
        addLine(b.head, b.neck);
        addLine(b.neck, b.pelvis);
        
        // Tay
        addLine(b.neck, b.leftShoulder);
        addLine(b.leftShoulder, b.leftHand);
        
        addLine(b.neck, b.rightShoulder);
        addLine(b.rightShoulder, b.rightHand);
        
        // Chân
        addLine(b.pelvis, b.leftKnee);
        addLine(b.leftKnee, b.leftFoot);
        
        addLine(b.pelvis, b.rightKnee);
        addLine(b.rightKnee, b.rightFoot);
        
        _skeletonLayer.path = skelPath.CGPath;
    } else {
        _skeletonLayer.hidden = YES;
    }

    // --- DRAW HP & TEXT (Giữ nguyên logic cũ) ---
    float hpPercent = (float)item.hp / (float)item.maxHp;
    if (hpPercent < 0) hpPercent = 0; if (hpPercent > 1) hpPercent = 1;
    
    CGRect hpRect = CGRectMake(item.frame.origin.x - 4, item.frame.origin.y, 2, item.frame.size.height);
    _hpBackLayer.frame = hpRect;
    
    float fillHeight = hpRect.size.height * hpPercent;
    _hpFillLayer.frame = CGRectMake(hpRect.origin.x, hpRect.origin.y + (hpRect.size.height - fillHeight), 2, fillHeight);
    
    if (hpPercent > 0.6) _hpFillLayer.backgroundColor = [UIColor greenColor].CGColor;
    else if (hpPercent > 0.3) _hpFillLayer.backgroundColor = [UIColor yellowColor].CGColor;
    else _hpFillLayer.backgroundColor = [UIColor redColor].CGColor;

    _textLayer.string = [NSString stringWithFormat:@"%@ [%.0fm]", item.name, item.distance];
    _textLayer.frame = CGRectMake(item.frame.origin.x - 30, item.frame.origin.y - 14, item.frame.size.width + 60, 14);
}
@end

// --- MAIN VIEW ---

@interface ESP_View ()
@property (nonatomic, strong) NSMutableArray<ESPEnemyLayer *> *enemyPool;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) CADisplayLink *displayLinkDATA;
@property (nonatomic, strong) NSArray<ESPItem *> *currentData;
@end

uint64_t Moudule_Base = -1;

@implementation ESP_View

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // [SHADOW-CORE] Default Config
        self.enableBox = YES;
        self.enableLine = YES;
        self.enableSkeleton = YES;

        self.enemyPool = [NSMutableArray array];
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Moudule_Base = (uint64_t)GetGameModule_Base((char*)"freefireth");
        });

        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateRendering)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        self.displayLinkDATA = [CADisplayLink displayLinkWithTarget:self selector:@selector(readMemory)];
        [self.displayLinkDATA addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)setESPData:(NSArray<ESPItem *> *)data {
    _currentData = [data copy];
}

- (void)updateRendering {
    if (!self.window) return;
    NSArray *data = self.currentData;
    NSUInteger count = data.count;
    
    while (self.enemyPool.count < count) {
        ESPEnemyLayer *layer = [[ESPEnemyLayer alloc] init];
        [self.layer addSublayer:layer];
        [self.enemyPool addObject:layer];
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES]; // Anti-Lag
    
    for (NSUInteger i = 0; i < self.enemyPool.count; i++) {
        ESPEnemyLayer *layer = self.enemyPool[i];
        if (i < count) [layer updateWithItem:data[i] config:self];
        else layer.hidden = YES;
    }
    [CATransaction commit];
}

// [SHADOW-CORE] Helper lấy tọa độ xương từ ID
// Lưu ý: Offset này mang tính tham khảo cho Unity, Boss có thể cần chỉnh lại tùy phiên bản game
Vector3 getBonePos(uint64_t entity, int boneID) {
    // Nếu Boss có hàm lấy bone trong GameLogic thì gọi ở đây.
    // Nếu chưa có, ta dùng logic giả định dựa trên Transform.
    // Vì không có file GameLogic hoàn chỉnh, tôi sẽ dùng vị trí tương đối cho Skeleton đơn giản.
    return {0,0,0}; 
}

- (void)readMemory {
    if (Moudule_Base == -1) return;
    NSMutableArray<ESPItem *> *tempBuffer = [NSMutableArray array];
    
    uint64_t matchGame = getMatchGame(Moudule_Base);
    uint64_t camera = CameraMain(matchGame);
    if (!isVaildPtr(camera)) return;

    uint64_t match = getMatch(matchGame);
    if (!isVaildPtr(match)) return;

    uint64_t myPawnObject = getLocalPlayer(match);
    if (!isVaildPtr(myPawnObject)) return;
    
    uint64_t mainCameraTransform = ReadAddr<uint64_t>(myPawnObject + 0x2B0);
    Vector3 myLocation = getPositionExt(mainCameraTransform);
    
    uint64_t player = ReadAddr<uint64_t>(match + 0xC8);
    uint64_t tValue = ReadAddr<uint64_t>(player + 0x28);
    int coutValue = ReadAddr<int>(tValue + 0x18);
    
    float *matrix = GetViewMatrix(camera);

    for (int i = 0; i < coutValue; i++) {
        uint64_t PawnObject = ReadAddr<uint64_t>(tValue + 0x20 + 8 * i);
        if (!isVaildPtr(PawnObject)) continue;
        if (isLocalTeamMate(myPawnObject, PawnObject)) continue;
        
        int CurHP = get_CurHP(PawnObject);
        if (CurHP <= 0) continue;

        // Đọc các điểm chính
        Vector3 headPos3D = getPositionExt(getHead(PawnObject));
        Vector3 feetPos3D = getPositionExt(getRightToeNode(PawnObject)); // Tạm dùng chân phải làm gốc chân
        
        // Điều chỉnh vị trí đầu (cao hơn 1 chút)
        headPos3D.y += 0.2f;

        float dis = Vector3::Distance(myLocation, headPos3D);
        if (dis > 350.0f) continue;
        
        Vector3 w2sHead = WorldToScreen(headPos3D, matrix, sWidth, sHeight);
        Vector3 w2sFeet = WorldToScreen(feetPos3D, matrix, sWidth, sHeight);
        
        if (w2sHead.z < 0 || w2sFeet.z < 0) continue;

        float boxHeight = fabsf(w2sHead.y - w2sFeet.y);
        float boxWidth = boxHeight * 0.55f;
        float x = w2sHead.x - boxWidth * 0.5f;
        float y = w2sHead.y;

        ESPItem *item = [[ESPItem alloc] init];
        item.frame = CGRectMake(x, y, boxWidth, boxHeight);
        item.name = GetNickName(PawnObject) ?: @"Enemy";
        item.hp = CurHP;
        item.maxHp = get_MaxHP(PawnObject);
        item.distance = dis;
        
        // --- LOGIC ĐỌC XƯƠNG (SIMPLIFIED) ---
        // Vì ta chưa có hàm getBoneID chuẩn, ta sẽ giả lập xương dựa trên Box để demo trước.
        // Boss thay thế bằng read memory thật khi có offset chuẩn.
        if (self.enableSkeleton) {
            ESPSkeleton *bone = [[ESPSkeleton alloc] init];
            bone.isValid = YES;
            
            // Chuyển đổi 3D sang 2D cho các khớp
            // Ở đây tôi dùng nội suy từ Box để vẽ khung xương giả lập (nếu chưa đọc đc memory xương thật)
            // Để hiển thị đẹp ngay lập tức cho Boss test.
            
            CGPoint head = CGPointMake(w2sHead.x, w2sHead.y);
            CGPoint feet = CGPointMake(w2sFeet.x, w2sFeet.y);
            CGPoint center = CGPointMake(head.x, head.y + boxHeight * 0.5);
            
            bone.head = head;
            bone.neck = CGPointMake(head.x, head.y + boxHeight * 0.15);
            bone.pelvis = CGPointMake(head.x, head.y + boxHeight * 0.45);
            
            // Vai
            bone.leftShoulder = CGPointMake(head.x - boxWidth * 0.3, head.y + boxHeight * 0.2);
            bone.rightShoulder = CGPointMake(head.x + boxWidth * 0.3, head.y + boxHeight * 0.2);
            
            // Tay (Giả lập buông thõng)
            bone.leftHand = CGPointMake(head.x - boxWidth * 0.35, head.y + boxHeight * 0.45);
            bone.rightHand = CGPointMake(head.x + boxWidth * 0.35, head.y + boxHeight * 0.45);
            
            // Chân
            bone.leftKnee = CGPointMake(head.x - boxWidth * 0.2, head.y + boxHeight * 0.75);
            bone.rightKnee = CGPointMake(head.x + boxWidth * 0.2, head.y + boxHeight * 0.75);
            
            bone.leftFoot = CGPointMake(head.x - boxWidth * 0.25, feet.y);
            bone.rightFoot = CGPointMake(head.x + boxWidth * 0.25, feet.y);
            
            item.bone = bone;
        }

        [tempBuffer addObject:item];
    }
    
    [self setESPData:tempBuffer];
}

- (void)dealloc {
    [_displayLink invalidate];
    [_displayLinkDATA invalidate];
}

@end