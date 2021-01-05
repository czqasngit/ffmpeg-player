//
//  FFPlayer.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/4.
//

#import "FFPlayer.h"
#import "FFEngine.h"

@interface FFPlayer()
@property (nonatomic, strong)FFEngine *engine;
@end
@implementation FFPlayer

- (instancetype)init {
    self = [super init];
    if (self) {
        _engine = [[FFEngine alloc] init];
    }
    return self;
}

#pragma mark -
- (BOOL)_setupPlayer:(const char *)url {
    BOOL ret = [_engine setup:url];
    if(!ret) return NO;
    
    return YES;
}

#pragma mark - Private

#pragma mark - Public
- (BOOL)playWithUrl:(NSString *)url {
    if(![self _setupPlayer:[url UTF8String]]) {
        return NO;
    }
    return YES;
}
@end
