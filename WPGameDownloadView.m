//
//  WPGameDownloadView.m
//  WePlayGame
//
//  Created by leviduan on 2018/5/18.
//  Copyright © 2018年 WePlay. All rights reserved.
//

#import "WPGameDownloadView.h"
#import "WPGameDownloader.h"
#import "WPGGamePageModel.h"

@interface WPGameDownloadView() <WPGameDownloaderDelegate>

@property (nonatomic, strong) UILabel *prograssLabel;

@end

@implementation WPGameDownloadView
{
    WPGameDownloader *_downloader;
    WPGGamePageGames *_gameModel;
}

- (instancetype)initWithFrame:(CGRect)frame withGameModel:(WPGGamePageGames *)gameModel
{
    self = [super initWithFrame:frame];
    if (self) {
        _gameModel = gameModel;
        [self initWithUI];
    }
    return self;
}

- (void)initWithUI
{
    _downloader = [WPGameDownloader shareManager];
    _downloader.delegate = self;
    [_downloader downloadGameModel:_gameModel];
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
    effectView.alpha = .9f;
    effectView.frame = self.frame;
    [self addSubview:effectView];
    [self addSubview:self.prograssLabel];
    self.prograssLabel.centerX = SCREEN_WIDTH/2.0;
    self.prograssLabel.centerY = SCREEN_HEIGHT/2.0;
}

- (UILabel *)prograssLabel
{
    if (!_prograssLabel) {
        _prograssLabel = [[UILabel alloc] init];
        _prograssLabel.text = @" ";
        _prograssLabel.font = [UIFont fontWithName:@"PingFangSC-Medium" size:23];
        _prograssLabel.textColor = NF_Color_C1;
    }
    return _prograssLabel;
}

// 下载成功回调（通过gameId判断是否为本次下载任务）
- (void)downloadSuccess:(WPGameDownloader *)gamedownloader gameId:(NSString *)gameId
{
    if ([_gameModel.gameId isEqualToString:gameId]) {
        if ([self.delegate respondsToSelector:@selector(downloadSuccess:)]) {
            [self.delegate downloadSuccess:self];
        }
    }
}
// 下载失败回调（通过gameId判断是否为本次下载任务）
- (void)downloadFail:(WPGameDownloader *)gamedownloader gameId:(NSString *)gameId
{
    if ([_gameModel.gameId isEqualToString:gameId]) {
        if ([self.delegate respondsToSelector:@selector(downloadFail:)]) {
            [self.delegate downloadFail:self];
        }
    }
}
// 下载进度回调（通过gameId判断是否为本次下载任务）
- (void)downloadProgress:(NSInteger)progress gamedownloader:(WPGameDownloader *)gamedownloader gameId:(NSString *)gameId
{
    if ([_gameModel.gameId isEqualToString:gameId]) {
        self.prograssLabel.text = [NSString stringWithFormat:@"%ld/100", progress];
        [self.prograssLabel sizeToFit];
        self.prograssLabel.centerX = SCREEN_WIDTH/2.0;
        self.prograssLabel.centerY = SCREEN_HEIGHT/2.0;
    }
}

@end
