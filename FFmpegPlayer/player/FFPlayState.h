//
//  FFPlayState.h
//  FFmpegPlayer
//
//  Created by Mark on 2021/2/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFPlayState) {
    FFPlayStateNone,
    FFPlayStateLoading,
    FFPlayStatePlaying,
    FFPlayStatePause,
    FFPlayStateStop
};

NS_ASSUME_NONNULL_END
