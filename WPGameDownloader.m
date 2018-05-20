//
//  WPGameDownloader.m
//  WePlayGame
//
//  Created by leviduan on 2018/5/16.
//  Copyright © 2018年 WePlay. All rights reserved.
//

#import "WPGameDownloader.h"
#import "FMDB.h"
#import "WPGGamePageModel.h"
#import "SSZipArchive.h"

static WPGameDownloader *_instance;

@implementation WPGameDataBaseModel

@end

@interface WPGameDownloader() <NSURLSessionDownloadDelegate, SSZipArchiveDelegate>
{
    FMDatabase *_db;
}

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSMutableArray *queenArray;
@property (nonatomic, strong) WPGGamePageGames *gameModel;
@property (nonatomic, assign) BOOL isDownloading;

@end

@implementation WPGameDownloader

+ (instancetype)shareManager
{
    if (!_instance) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _instance = [[self alloc] init];
        });
    }
    return _instance;
}

- (id)init
{
    if (self = [super init]) {
        _queenArray = [NSMutableArray new];
        _isDownloading = NO;
        [self createTable];
    }
    return self;
}

- (BOOL)isExistGame:(WPGGamePageGames *)gameModel
{
    return [self searchDataGameId:gameModel.gameId versiton:gameModel.h5Version];
}

- (void)downloadGameModel:(WPGGamePageGames *)gameModel
{
    [_queenArray addObject:gameModel];
    [self startDownLoad];
}

- (void)startDownLoad
{
    if (_queenArray.count<=0) {
        return;
    }
    if (_isDownloading) {
        return;
    }
    _isDownloading = YES;
    _gameModel = [_queenArray cl_objectAtIndex:0];
    [_queenArray cl_removeObjectAtIndex:0];
    [self start];
}

- (void)removefile
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *docsDir = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Caches/Game/%@/", _gameModel.gameId]];
    [manager removeItemAtPath:docsDir error:nil];
}

- (void)downloadFailed
{
    _isDownloading = NO;
    IDSLOG(@"FAILED : GAMEID: %@", _gameModel.gameId);
    [self removefile];
    [self.session finishTasksAndInvalidate];
    _session = nil;
    if ([self.delegate respondsToSelector:@selector(downloadFail:gameId:)]) {
        [self.delegate downloadFail:self gameId:_gameModel.gameId];
    }
    [self startDownLoad];
}

- (void)downloadSuccess
{
    IDSLOG(@"SUEECSS : GAMEID: %@", _gameModel.gameId);
    WPGameDataBaseModel *model = [[WPGameDataBaseModel alloc] init];
    model.gameId = _gameModel.gameId;
    model.version = _gameModel.h5Version;
    model.value = 1;
    [self inserIntoData:model];
    if ([self.delegate respondsToSelector:@selector(downloadSuccess:gameId:)]) {
        [self.delegate downloadSuccess:self gameId:model.gameId];
    }
    [self printAllData];
    _isDownloading = NO;
    [self startDownLoad];
}

- (void)start
{
    NSURL *url = [NSURL URLWithString:_gameModel.h5Down];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    self.task = [self.session downloadTaskWithRequest:request];
    [self.task resume];
}

# pragma mark - delegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    if ([self.delegate respondsToSelector:@selector(downloadProgress:gamedownloader:gameId:)]) {
        [self.delegate downloadProgress:(totalBytesWritten*100/totalBytesExpectedToWrite) gamedownloader:self gameId:_gameModel.gameId];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location;
{
    [self createGameFolder];
    
    [self createGameFolderName:_gameModel.gameId];

    NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Caches/Game/%@/", _gameModel.gameId]];
    NSString *file = [docPath stringByAppendingPathComponent:downloadTask.response.suggestedFilename];
    NSError *error = nil;
    NSFileManager *manager = [NSFileManager defaultManager];
    
    BOOL result = [manager fileExistsAtPath:location.path];
    NSLog(@"移动之前 这个文件已经存在：%@",result?@"是的":@"不存在");
    if ([manager fileExistsAtPath:location.path]) {
        NSLog(@"移动之前文件大小为: %.1fM", [[manager attributesOfItemAtPath:location.path error:nil] fileSize]/1000000.0);
    }
    if (![[manager attributesOfItemAtPath:location.path error:nil] fileSize]) {
        NSLog(@"文件为空返回");
        return;
    }
    // 判断文件是否存在
    BOOL ret = [manager moveItemAtPath:location.path toPath:file error:&error];
    if (!ret) {
        NSLog(@"MOVE FILE IS WRONG");
    }
    if (error) {
        NSLog(@"move failed:%@", [error localizedDescription]);
    }
    
    BOOL resultdd = [manager fileExistsAtPath:file];
    NSLog(@"移动之后 这个文件已经存在：%@",resultdd?@"是的":@"不存在");
    NSLog(@"储存路径 移动之后:%@, \n移动之前:%@",file,location.path);
    
    NSString *destination = [NSString stringWithFormat:@"%@/", docPath];
    BOOL ret1 = [SSZipArchive unzipFileAtPath:file toDestination:destination delegate:self];
    if (!ret1) {
        NSLog(@"解压失败");
        [self downloadFailed];
        return;
    }
    [manager removeItemAtPath:file error:nil];
    // 遍历文件
    NSDirectoryEnumerator *dirEnum = [manager enumeratorAtPath:docPath];
    NSString *fileName;
    while (fileName = [dirEnum nextObject]) {
//        NSLog(@"FielName>> : %@" , fileName);
        NSLog(@"FileFull>>> : %@" , [docPath stringByAppendingPathComponent:fileName]) ;
    }
    
    [self downloadSuccess];
}

- (long long)fileSizeAtPath:(NSString *)filePath {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:filePath]) {
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    return 0;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self downloadFailed];
    }
}

- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo
{
    NSLog(@"path1 is :%@", path);
}

- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath
{
    NSLog(@"path2 is :%@", path);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    NSLog(@"value:%lld,expetec:%lld",fileOffset,expectedTotalBytes);
}

# pragma mark - fileManager

- (void)createGameFolder
{
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dataFilePath = [docPath stringByAppendingPathComponent:@"Game"]; // 在Caches目录下创建 "game" 文件夹
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [fileManager fileExistsAtPath:dataFilePath isDirectory:&isDir];
    
    if (!(isDir && existed)) {
        // 在Document目录下创建一个archiver目录
        BOOL isSuccess = [fileManager createDirectoryAtPath:dataFilePath withIntermediateDirectories:YES attributes:nil error:nil];
        if (!isSuccess) {
            IDSLOG(@"创建文件Game文件失败");
        }
    }
}

- (void)createGameFolderName:(NSString *)folderName
{
    NSString *docPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/Game/"];
    NSString *dataFilePath = [docPath stringByAppendingPathComponent:folderName]; // 在Caches目录下创建 "game" 文件夹
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    
    BOOL existed = [fileManager fileExistsAtPath:dataFilePath isDirectory:&isDir];
    
    if (!(isDir && existed)) {

        NSError *error = nil;
        BOOL isSuccess = [fileManager createDirectoryAtPath:dataFilePath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!isSuccess) {
            IDSLOG(@"创建文件GameId文件失败");
            IDSLOG(@"创建GameId失败原因：%@", [error localizedDescription]);
        }
    }
}

# pragma mark - dataBase

- (BOOL)openDataBase
{
    NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/gamedownload.sqlite"];
    if (!_db) {
        _db = [[FMDatabase alloc] initWithPath:filePath];
    }
    
    if ([_db open]) {
        [_db setShouldCacheStatements:YES];
        return YES;
    }
    [_db close];
    return NO;
}

// 创建表
- (void)createTable
{
    //先打开数据库,然后创建表,最后关闭数据库
    if (![self openDataBase]) {
        return;
    }
    //tableExists 判断表是否存在,当表不存在的时候再去创建  参数:表名
    if (![_db tableExists:@"Game_Version_isExist"]) {

        NSString *sql = @"CREATE TABLE IF NOT EXISTS Game_Version_IsExist ('ID' INTEGER PRIMARY KEY AUTOINCREMENT,'gameid' TEXT NOT NULL, 'version' TEXT NOT NULL,'exist' INTEGER NOT NULL)";
        BOOL result = [_db executeUpdate:sql];
        if (result) {
            NSLog(@"create table success");
        }
    }
    [_db close];
}

// 打印全部数据
- (void)printAllData
{
    IDSLOG(@"printA =====");
    if (![self openDataBase]) {
        return;
    }
    
    FMResultSet *set = [_db executeQuery:@"SELECT * FROM Game_Version_isExist"];
    // next 单步查询
    while ([set next]) {
        //把每一条数据(包含id,name,phone),存入一个对象，再把对象放入数组
        IDSLOG(@"===%d,%@,%@,%d", [set intForColumnIndex:0],[set stringForColumn:@"gameid"],[set stringForColumn:@"version"],[set intForColumn:@"exist"]);
    }
    [set close];
    [_db close];
    IDSLOG(@"printB =====");
}

// 查询全部数据
- (NSMutableArray *)selectAllData
{
    if (![self openDataBase]) {
        return nil;
    }
    
    FMResultSet *set = [_db executeQuery:@"SELECT * FROM Game_Version_isExist"];
    NSMutableArray *array = [NSMutableArray array];
    // next 单步查询
    while ([set next]) {
        //把每一条数据(包含id,name,phone),存入一个对象，再把对象放入数组
        WPGameDataBaseModel *game = [[WPGameDataBaseModel alloc] init];
        game.auto_id = [set intForColumnIndex:0];
        game.gameId = [set stringForColumn:@"gameid"];
        game.version = [set stringForColumn:@"version"];
        game.value = [set intForColumn:@"exist"];
        //把查询的每一条数据分别放入数组
        [array addObject:game];
    }
    [set close];
    [_db close];
    return array;
}

- (BOOL)searchDataGameId:(NSString *)gameId versiton:(NSString *)version
{
    [self printAllData];
    if (![self openDataBase]) {
        return NO;
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM Game_Version_isExist WHERE gameid = %@ and version = '%@'", gameId,version];
    FMResultSet *set = [_db executeQuery:sql];
    BOOL returnValue = NO;
    while ([set next]) {
        returnValue = YES;
    }
    [set close];
    [_db close];
    return returnValue;
}

// 增加数据
- (void)inserIntoData:(WPGameDataBaseModel *)gameModel
{
    if ([self openDataBase]) {
        [_db executeUpdateWithFormat:@"DELETE FROM Game_Version_IsExist WHERE gameid = %@", gameModel.gameId];
        [_db executeUpdateWithFormat:@"INSERT INTO Game_Version_IsExist (gameid, version, exist) VALUES (%@,%@,%d)",gameModel.gameId, gameModel.version,gameModel.value];
        [_db close];
    }
}

// 通过gameId进行修改
- (void)updateData:(WPGameDataBaseModel *)gameModel
{
    //根据id找到具体的联系人
    if ([self openDataBase]) {
        [_db executeUpdateWithFormat:@"UPDATE Game_Version_IsExist SET version = %@, exist = %d WHERE gameid = %@",gameModel.version,gameModel.value,gameModel.gameId];
        [_db close];
    }
}

// 删除
- (void)deleteData:(NSString *)game_id
{
    if ([self openDataBase]) {
        //根据联系人的id进行删除
        [_db executeUpdateWithFormat:@"DELETE FROM Game_Version_IsExist WHERE gameid = %@",game_id];
        [_db close];
    }
}

- (NSURLSession *)session
{
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _session;
}

@end
