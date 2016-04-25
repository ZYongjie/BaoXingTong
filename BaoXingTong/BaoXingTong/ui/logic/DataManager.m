//
//  DataManager.m
//  BaoXingTong
//
//  Created by yongjie_zou on 16/4/6.
//  Copyright © 2016年 yongjie_zou. All rights reserved.
//

#import "DataManager.h"
#import "GuaranteeSlipModel.h"

static NSString *const allLocalNotificationsIdentifer = @"allLocalNotificationsIdentifer";
static NSString *const allRemindGuaranteeSlipsIdentifer = @"allRemindGuaranteeSlipsIdentifer";
static NSString *const allIdsIdentifer = @"allIdsIdentifer";

@interface DataManager ()

@property (nonatomic, strong) NSMutableArray *notificationArray;
@property (nonatomic, strong) NSMutableArray *needReadArray;
@property (nonatomic, strong) NSMutableArray *IdsArray;

@end

@implementation DataManager

static DataManager *sharedDataManager = nil;

+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataManager = [[self alloc] init];
    });
    return sharedDataManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.needReadArray = [NSMutableArray arrayWithArray:[self getDataWithIdentifer:allRemindGuaranteeSlipsIdentifer]];
        self.IdsArray = [NSMutableArray arrayWithArray:[self getDataWithIdentifer:allIdsIdentifer]];
    }
    return self;
}

- (id)getDataWithIdentifer:(NSString *)identifer
{
    if (identifer.length) {
        return [[NSUserDefaults standardUserDefaults] valueForKey:identifer];
    }
    return nil;
}

- (void)saveData:(id )data WithIdentifer:(NSString *)identifer
{
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:identifer];    //如果保存失败会怎样？
}

- (void)deleteDataWithIdentifer:(NSString *)identifer
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:identifer];    //如果删除失败会怎样？
}

#pragma mark - notification
- (void)updataLocalNotification         //更新所有本地通知，主要是applicationIconBadgeNumber
{
    NSArray *array = [[UIApplication sharedApplication] scheduledLocalNotifications];
    if (array.count <= 0) {
        return;
    }
    
    NSMutableArray *modelArray = [NSMutableArray new];
    for (UILocalNotification *notification in array) {
        NSInteger localNotificationId = ((NSNumber *)[notification.userInfo objectForKey:kLocalNotificationKey]).integerValue;
        GuaranteeSlipModel *model = [self getModelWithId:localNotificationId];
        if (model) {
            [modelArray addObject:model];
        }
    }
    
    [modelArray sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        NSDate *date1 = [formatter dateFromString:((GuaranteeSlipModel *)obj1).remindDate];
        NSDate *date2 = [formatter dateFromString:((GuaranteeSlipModel *)obj2).remindDate];
        
        NSTimeInterval a = [date1 timeIntervalSince1970];
        NSTimeInterval b = [date2 timeIntervalSince1970];
        if (a > b) {
            return NSOrderedDescending;
        }
        else
        {
            return NSOrderedAscending;
        }
    }];
    
    for (UILocalNotification *notification in array) {
        NSInteger localNotificationId = ((NSNumber *)[notification.userInfo objectForKey:kLocalNotificationKey]).integerValue;
        for (GuaranteeSlipModel *model in modelArray) {
            if (model.guaranteeSlipModelId == localNotificationId) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                notification.fireDate = [formatter dateFromString:model.remindDate];
                notification.applicationIconBadgeNumber = [modelArray indexOfObject:model] + 1;
                continue;
            }
        }
    }
    
    [[UIApplication sharedApplication] scheduledLocalNotifications];
}

- (void)addLocalNotifaction:(NSInteger)Id fireDate:(NSDate *)date
{
    if (![self.IdsArray containsObject:@(Id)]) {
        return;         //为该Id的保单不存在
    }
    NSArray *array = [[UIApplication sharedApplication] scheduledLocalNotifications];
    for (UILocalNotification *notification in array) {
        NSInteger localNotificationId = ((NSNumber *)[notification.userInfo objectForKey:kLocalNotificationKey]).integerValue;
        if (localNotificationId == Id) {
            [self updataLocalNotification];
            return;     //已经添加
        }
    }
    
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.fireDate = date;
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    localNotification.alertBody = @"你有保单快到期了";
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    localNotification.applicationIconBadgeNumber = self.needReadArray.count + 1;
    localNotification.userInfo = @{
                                   kLocalNotificationKey:@(Id)
                                   };
    localNotification.category = kNotificationCategoryIdentifile;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    
    [self updataLocalNotification];
}

- (void)removeLocalNotifaction:(NSInteger)Id
{
    NSArray *array = [[UIApplication sharedApplication] scheduledLocalNotifications];
    for (UILocalNotification *notification in array) {
        NSInteger localNotificationId = ((NSNumber *)[notification.userInfo objectForKey:kLocalNotificationKey]).integerValue;
        if (localNotificationId == Id) {
            [[UIApplication sharedApplication] cancelLocalNotification:notification];
        }
    }
    
    [self updataLocalNotification];
}

#pragma mark - data
- (NSArray *)getAllRemindGuaranteeSlipIds
{
    return self.needReadArray;
//    return [NSArray arrayWithArray:[self getDataWithIdentifer:allRemindGuaranteeSlipsIdentifer]];
}

- (NSInteger)sumOfAllUnReadRmindGuranteeSlips
{
    return self.needReadArray.count;
//    return [NSArray arrayWithArray:[self getDataWithIdentifer:allRemindGuaranteeSlipsIdentifer]].count;
}

- (void)setNeedRead:(NSInteger)modelId
{
    if (modelId > 0 && ![self.needReadArray containsObject:@(modelId)]) {
        [self.needReadArray addObject:@(modelId)];
        [self saveData:self.needReadArray WithIdentifer:allRemindGuaranteeSlipsIdentifer];
        
        GuaranteeSlipModel *model = [self getModelWithId:modelId];
        model.isNeedRemind = NO;
        [self saveDataWithModel:model];
        
        [UIApplication sharedApplication].applicationIconBadgeNumber = self.needReadArray.count;
    }
}

- (void)resetNotNeedRead:(NSInteger)modelId
{
    if ([self.needReadArray containsObject:@(modelId)]) {
        [self.needReadArray removeObject:@(modelId)];
        [self saveData:self.needReadArray WithIdentifer:allRemindGuaranteeSlipsIdentifer];
        
        [UIApplication sharedApplication].applicationIconBadgeNumber = self.needReadArray.count;
    }
}

- (NSArray *)getAllIds
{
    return self.IdsArray;
}

- (GuaranteeSlipModel *)getModelWithId:(NSInteger)Id
{
    if ([self.IdsArray containsObject:@(Id)]) {
        NSData *data = [self getDataWithIdentifer:@(Id).stringValue];
        return (GuaranteeSlipModel *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    return nil;
}

- (void)saveDataWithModel:(GuaranteeSlipModel *)model
{
    if (model.guaranteeSlipModelId <= 0) {      //新建的保单
        model.guaranteeSlipModelId = self.IdsArray.count + 1;
        NSInteger i = 1;
        for (; i <= self.IdsArray.count; i++) {
            if (![self.IdsArray containsObject:@(i)]) {
                model.guaranteeSlipModelId = i;
                break;
            }
        }
    }
    
    if (![self.IdsArray containsObject:@(model.guaranteeSlipModelId)]) {
        [self.IdsArray addObject:@(model.guaranteeSlipModelId)];
        [self saveData:self.IdsArray WithIdentifer:allIdsIdentifer];
    }
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:model];
    [self saveData:data WithIdentifer:@(model.guaranteeSlipModelId).stringValue];
}

- (void)deleteDataWithId:(NSInteger)Id
{
    if ([self.IdsArray containsObject:@(Id)]) {
        [self.IdsArray removeObject:@(Id)];
        [self deleteDataWithIdentifer:@(Id).stringValue];
        [self saveData:self.IdsArray WithIdentifer:allIdsIdentifer];
    }
}

@end
