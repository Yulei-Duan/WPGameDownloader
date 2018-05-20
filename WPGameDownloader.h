//
//  WPGameDownloader.h
//  WePlayGame
//
//  Created by leviduan on 2018/5/16.
//  Copyright © 2018年 WePlay. All rights reserved.
//
//  @content：游戏下载器
//

#import <Foundation/Foundation.h>

@class WPGameDownloader, WPGGamePageGames;

@interface WPGameDataBaseModel : NSObject

@property (nonatomic, assign) int auto_id;
@property (nonatomic, copy) NSString *gameId;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, assign) int value;

@end

@protocol WPGameDownloaderDelegate <NSObject>

// 下载成功回调（通过gameId判断是否为本次下载任务）
- (void)downloadSuccess:(WPGameDownloader *)gamedownloader gameId:(NSString *)gameId;
// 下载失败回调（通过gameId判断是否为本次下载任务）
- (void)downloadFail:(WPGameDownloader *)gamedownloader gameId:(NSString *)gameId;
// 下载进度回调（通过gameId判断是否为本次下载任务）
- (void)downloadProgress:(NSInteger)progress gamedownloader:(WPGameDownloader *)gamedownloader gameId:(NSString *)gameId;

@end

@interface WPGameDownloader : NSObject

@property (nonatomic, weak) id <WPGameDownloaderDelegate> delegate;

// 单例
+ (instancetype)shareManager;

// 下载游戏
- (void)downloadGameModel:(WPGGamePageGames *)gameModel;

// 游戏是否下载到本地
- (BOOL)isExistGame:(WPGGamePageGames *)gameModel;

@end
