//
//  FFFrameQueue.m
//  FFmpegPlayer
//
//  Created by Mark on 2021/1/16.
//

#import "FFObjectQueue.h"
#import <pthread.h>
#import "FFQueueAudioObject.h"

@interface FFObjectQueue()
@property(nonatomic, strong)NSMutableArray *storage;
@end
@implementation FFObjectQueue {
    pthread_mutex_t locker;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _storage = [[NSMutableArray alloc] init];
        pthread_mutex_init(&locker, NULL);
    }
    return self;
}

#pragma mark - Public
- (id _Nullable)dequeue {
    id obj = NULL;
    pthread_mutex_lock(&locker);
    if(_storage.count == 0) {
        pthread_mutex_unlock(&locker);
        return NULL;
    }
    obj = _storage.lastObject;
    [_storage removeLastObject];
    pthread_mutex_unlock(&locker);
    return obj;
}
- (void)enqueue:(id)object {
    pthread_mutex_lock(&locker);
    [_storage insertObject:object atIndex:0];
    pthread_mutex_unlock(&locker);
}
- (NSInteger)count {
    NSInteger count = 0;
    pthread_mutex_lock(&locker);
    count = _storage.count;
    pthread_mutex_unlock(&locker);
    return count;
}
- (void)clean {
    pthread_mutex_lock(&locker);
    [_storage removeAllObjects];
    pthread_mutex_unlock(&locker);
}
- (float)duration {
    float _duration = 0;
    pthread_mutex_lock(&locker);
    for(FFQueueAudioObject *obj in _storage) {
        _duration += obj.duration;
    }
    pthread_mutex_unlock(&locker);
    return _duration;
}
@end
