//
//  FFQueueObject.m
//  FFmpegPlayer
//
//  Created by youxiaobin on 2021/1/18.
//

#import "FFQueueAudioObject.h"

@implementation FFQueueAudioObject {
    uint8_t *data;
    int64_t length;
}
- (void)dealloc {
    free(self->data);
}
- (instancetype)initWithLength:(int64_t)length pts:(float)pts duration:(float)duration {
    self = [super init];
    if (self) {
        _pts = pts;
        _duration = duration;
        self->length = length;
        self->data = (uint8_t *)malloc(length);
    }
    return self;
}
- (uint8_t *)data {
    return self->data;
}
- (int64_t)length {
    return self->length;
}
- (void)updateLength:(int64_t)length {
    self->length = length;
}

@end
