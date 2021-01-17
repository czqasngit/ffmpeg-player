//
//  FFFrameQueue.m
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import "FFQueue.h"

@interface FFQueue()
@property(nonatomic, strong)NSMutableArray *storage;
@end
@implementation FFQueue

- (instancetype)init {
    self = [super init];
    if (self) {
        _storage = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Public
- (id _Nullable)dequeue {
    if(_storage.count == 0) return NULL;
    id obj = _storage.lastObject;
    [_storage removeLastObject];
    return obj;
}
- (void)enqueue:(id)object {
    [_storage insertObject:object atIndex:0];
}
- (NSInteger)count {
    return _storage.count;
}
@end
