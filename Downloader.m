#import "Downloader.h"
#define _1M 1024*1024
@implementation RNFSDownloadParams

@end

@interface RNFSDownloader()

@property (copy) RNFSDownloadParams* params;

@property (retain) NSURLSession* session;
@property (retain) NSURLSessionDownloadTask* task;
@property (retain) NSNumber* statusCode;
@property (retain) NSNumber* lastProgressValue;
@property (retain) NSNumber* contentLength;
@property (nonatomic,strong) NSFileManager *manage;
@property (retain) NSNumber* bytesWritten;
@property (nonatomic,strong) NSData *fileData;
@property (nonatomic,strong) NSURLSession *backgroundURLSession;
@property (nonatomic,strong) NSString *docPath;
@property (nonatomic,assign) long long int byte;


@property (retain) NSFileHandle* fileHandle;

@end

@implementation RNFSDownloader
{
    NSString *dataPath;
    NSString *tmpPath;
    NSString *docFilePath;
}

- (void)downloadFile:(RNFSDownloadParams*)params
{
  _params = params;

  _bytesWritten = 0;
  NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    dataPath = [self.docPath stringByAppendingPathComponent:params.sourceId];
  NSURL* url = [NSURL URLWithString:_params.fromUrl];
  _fileData = [NSData dataWithContentsOfFile:dataPath];
//  [[NSFileManager defaultManager] createFileAtPath:_params.toFile contents:nil attributes:nil];
//  _fileHandle = [NSFileHandle fileHandleForWritingAtPath:_params.toFile];
//
//  if (!_fileHandle) {
//    NSError* error = [NSError errorWithDomain:@"Downloader" code:NSURLErrorFileDoesNotExist
//                              userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Failed to create target file at path: %@", _params.toFile]}];
//
//    return _params.errorCallback(error);
//  } else {
//    [_fileHandle closeFile];
//  }
//
  NSURLSessionConfiguration *config;
  if (_params.background) {
    NSString *uuid = [[NSUUID UUID] UUIDString];
    config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:uuid];
    config.discretionary = _params.discretionary;
  } else {
    config = [NSURLSessionConfiguration defaultSessionConfiguration];
  }
//  //config.HTTPAdditionalHeaders = _params.headers;
//
  _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
  //_task = [_session downloadTaskWithURL:url];
    if (_fileData)
    {
        NSString *Caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        [self.manage removeItemAtPath:Caches error:nil];
        [self MoveDownloadFile];
        _task = [_session downloadTaskWithResumeData:_fileData];
        
    }
    else
    {
        _task = [_session downloadTaskWithURL:url];
    }
  [_task resume];
}

- (NSString *)docPath
{
    if (!_docPath)
    {
        _docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    }
    return _docPath;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)downloadTask.response;
  if (!_statusCode) {
    _statusCode = [NSNumber numberWithLong:httpResponse.statusCode];
    _contentLength = [NSNumber numberWithLong:httpResponse.expectedContentLength];
    return _params.beginCallback(_statusCode, _contentLength, httpResponse.allHeaderFields);
  }

  if ([_statusCode isEqualToNumber:[NSNumber numberWithInt:200]] || [_statusCode isEqualToNumber:[NSNumber numberWithInt:206]]) {
    _bytesWritten = @(totalBytesWritten);
//      _byte+=bytesWritten;
//
//      if (_byte > _1M)
//      {
//          [self downloadPause];
//          _byte -= _1M;
//      }
    if (_params.progressDivider.integerValue <= 0) {
      return _params.progressCallback(_contentLength, _bytesWritten);
    } else {
      double doubleBytesWritten = (double)[_bytesWritten longValue];
      double doubleContentLength = (double)[_contentLength longValue];
      double doublePercents = doubleBytesWritten / doubleContentLength * 100;
      NSNumber* progress = [NSNumber numberWithUnsignedInt: floor(doublePercents)];
      if ([progress unsignedIntValue] % [_params.progressDivider integerValue] == 0) {
        if (([progress unsignedIntValue] != [_lastProgressValue unsignedIntValue]) || ([_bytesWritten unsignedIntegerValue] == [_contentLength longValue])) {
          NSLog(@"---Progress callback EMIT--- %zu", [progress unsignedIntValue]);
          _lastProgressValue = [NSNumber numberWithUnsignedInt:[progress unsignedIntValue]];
          return _params.progressCallback(_contentLength, _bytesWritten);
        }
      }
    }
  }
}

- (void)downloadPause
{
    
    NSLog(@"%s",__func__);
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        _fileData = resumeData;
        _task = nil;
        [resumeData writeToFile:dataPath atomically:YES];
        [self getDownloadFile];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
            if (_fileData)
            {
                _task = [self.backgroundURLSession downloadTaskWithResumeData:_fileData];
                [_task resume];
            }
        });
    }];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)downloadTask.response;
  if (!_statusCode) {
    _statusCode = [NSNumber numberWithLong:httpResponse.statusCode];
  }
//    NSString *filePath = [self.docPath stringByAppendingPathComponent:@"file.mp4"];
//    [self.manage moveItemAtURL:location toURL:[NSURL fileURLWithPath:filePath] error:nil];
//    [self.manage removeItemAtPath:dataPath error:nil];
//    [self.manage removeItemAtPath:docFilePath error:nil];

   NSURL *destURL = [NSURL fileURLWithPath:_params.toFile];
   NSFileManager *fm = [NSFileManager defaultManager];
   NSError *error = nil;
   [fm removeItemAtURL:destURL error:nil];       // Remove file at destination path, if it exists
    [fm moveItemAtURL:location toURL:destURL error:&error];
    _fileData = nil;
  if (error) {
    NSLog(@"RNFS download: unable to move tempfile to destination. %@, %@", error, error.userInfo);
  }

  return _params.completeCallback(_statusCode, _bytesWritten);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
  if (error && error.code != -999) {
    _params.errorCallback(error);
  }
}
- (NSFileManager *)manage
{
    if (!_manage)
    {
        _manage = [NSFileManager defaultManager];
    }
    return _manage;
}

- (void)getDownloadFile
{
    NSArray *paths = [self.manage subpathsAtPath:NSTemporaryDirectory()];
    NSLog(@"%@",paths);
    for (NSString *filePath in paths)
    {
        if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
        {
            tmpPath = [self.docPath stringByAppendingPathComponent:filePath];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            
            [self.manage copyItemAtPath:path toPath:tmpPath error:nil];
            
        }
    }
}

- (void)MoveDownloadFile
{
    NSArray *paths = [self.manage subpathsAtPath:_docPath];
    
    for (NSString *filePath in paths)
    {
        if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
        {
            docFilePath = [_docPath stringByAppendingPathComponent:filePath];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            [self.manage copyItemAtPath:docFilePath toPath:path error:nil];
        }
    }
    NSLog(@"%@,%@",paths,[self.manage subpathsAtPath:NSTemporaryDirectory()]);
}
- (void)stopDownload
{
  if (_task.state == NSURLSessionTaskStateRunning) {
    //[_task cancel];
      [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
          _fileData = resumeData;
          _task = nil;
          [resumeData writeToFile:dataPath atomically:YES];
          [self getDownloadFile];
      }];

//    NSError *error = [NSError errorWithDomain:@"RNFS"
//                                         code:@"Aborted"
//                                     userInfo:@{
//                                       NSLocalizedDescriptionKey: @"Download has been aborted"
//                                     }];
//
//    return _params.errorCallback(error);
  }
}

@end
