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
- (instancetype)initWithLength:(int)length {
    self = [super init];
    if (self) {
        self->length = length;
        self->data = (uint8_t *)malloc(length);
    }
    return self;
}
- (uint8_t *)data {
    return self->data;
}
- (int)length {
    return self->length;
}
- (void)updateLength:(int64_t)length {
    self->length = length;
}

@end
