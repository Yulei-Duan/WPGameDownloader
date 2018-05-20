//
//  WPGameDownloadView.h
//  WePlayGame
//
//  Created by leviduan on 2018/5/18.
//  Copyright © 2018年 WePlay. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WPGameDownloadView,WPGameDownloader,WPGGamePageGames;

@protocol WPGameDownloadViewDelegate <NSObject>

// 下载成功回调（通过gameId判断是否为本次下载任务）
- (void)downloadSuccess:(WPGameDownloadView *)gamedownloader;
// 下载失败回调（通过gameId判断是否为本次下载任务）
- (void)downloadFail:(WPGameDownloadView *)gamedownloader;

@end

@interface WPGameDownloadView : UIView

@property (nonatomic, weak) id <WPGameDownloadViewDelegate> delegate;

// 传送gameModel模型，然后开始下载界面
- (instancetype)initWithFrame:(CGRect)frame withGameModel:(WPGGamePageGames *)gameModel;

@end
