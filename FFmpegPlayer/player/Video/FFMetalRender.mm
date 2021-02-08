//
//  YUVMetalDisplayView.m
//  FFDemo-MacUI
//
//  Created by youxiaobin on 2020/12/11.
//

#import "FFMetalRender.h"

#define _CFToString(obj) ((__bridge NSString *)obj)

@interface FFMetalRender()
@property (nonatomic, strong)id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong)id<MTLComputePipelineState> computePipline;
@end
@implementation FFMetalRender {
    CVPixelBufferPoolRef pixelBufferPoolRef;
    dispatch_queue_t display_metal_queue;
    CVMetalTextureCacheRef metalTextureCache;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        display_metal_queue = dispatch_queue_create("display metal queue", NULL);
        [self setupMetal];
    }
    return self;
}

#pragma mark - Private

- (void)setupMetal {
    /// Create GPU Device
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    /// Create new command queue that organizes command buffers for the GPU to execute.
    self.commandQueue = [device newCommandQueue];
    /// Create new library that a set of shader functions.
    id<MTLLibrary> library = [device newDefaultLibrary];
    if(!library) return;
    /// Create new function
    id<MTLFunction> function = [library newFunctionWithName:@"yuv420ToRGB"];
    if(!function) return;
    NSError *error;
    /// Create compute pipline of GPU
    _computePipline = [device newComputePipelineStateWithFunction:function error:&error];
    if(error) {
        NSLog(@"%@", error.debugDescription);
        return;
    }
    CVReturn ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, device, NULL, &metalTextureCache);
    if(ret != kCVReturnSuccess) return;
    
    self.device = device;
    self.autoResizeDrawable = NO;
    self.framebufferOnly = NO;
    NSLog(@"Setup metal successful.");
}
- (BOOL)setupCVPixelBufferIfNeed:(AVFrame *)frame {
    if(!pixelBufferPoolRef) {
        NSMutableDictionary *pixelBufferAttributes = [[NSMutableDictionary alloc] init];
        if(frame->color_range == AVCOL_RANGE_MPEG) {
            pixelBufferAttributes[_CFToString(kCVPixelBufferPixelFormatTypeKey)] = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
        } else {
            pixelBufferAttributes[_CFToString(kCVPixelBufferPixelFormatTypeKey)] = @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
        }
        pixelBufferAttributes[_CFToString(kCVPixelBufferMetalCompatibilityKey)] = @(TRUE);
        pixelBufferAttributes[_CFToString(kCVPixelBufferWidthKey)] = @(frame->width);
        pixelBufferAttributes[_CFToString(kCVPixelBufferHeightKey)] = @(frame->height);
        /// bytes per row(alignment)
        pixelBufferAttributes[_CFToString(kCVPixelBufferBytesPerRowAlignmentKey)] = @(frame->linesize[0]);
        CVReturn cvRet = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                NULL,
                                (__bridge  CFDictionaryRef)pixelBufferAttributes,
                                &(self->pixelBufferPoolRef));
        if(cvRet != kCVReturnSuccess) {
            NSLog(@"create cv buffer pool failed: %d", cvRet);
            return NO;
        }
    }
    return YES;
}

- (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame *)frame {
//    CFTimeInterval start = CACurrentMediaTime();
    if(![self setupCVPixelBufferIfNeed:frame]) return NULL;
    CVPixelBufferRef _pixelBufferRef;
    CVReturn cvRet = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPoolRef, &_pixelBufferRef);
    if(cvRet != kCVReturnSuccess) {
        NSLog(@"create cv buffer failed: %d", cvRet);
        return NULL;
    }
    CVPixelBufferLockBaseAddress(_pixelBufferRef, 0);
    /// copy y
    size_t yBytesPerRowSize = CVPixelBufferGetBytesPerRowOfPlane(_pixelBufferRef, 0);
    void *yBase = CVPixelBufferGetBaseAddressOfPlane(_pixelBufferRef, 0);
    memcpy(yBase, frame->data[0], yBytesPerRowSize * frame->height);
    /// copy uv
    void *uvBase = CVPixelBufferGetBaseAddressOfPlane(_pixelBufferRef, 1);
    size_t uvBytesPerRowSize = CVPixelBufferGetBytesPerRowOfPlane(_pixelBufferRef, 1);
    memcpy(uvBase, frame->data[1], uvBytesPerRowSize * frame->height / 2);
    CVPixelBufferUnlockBaseAddress(_pixelBufferRef, 0);
    CFTimeInterval end = CACurrentMediaTime();
//    NSLog(@"耗时: %f", end - start);
    return _pixelBufferRef;
}

#pragma mark - Override
- (void)displayWithFrame:(AVFrame *)frame {
    CVPixelBufferRef pixelBuffer = [self createCVPixelBufferFromAVFrame:frame];
    if(!pixelBuffer) return;
    dispatch_async(display_metal_queue, ^{
        /// Display AVFrame with Metal
        /// Get Y plane width and height
        size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        CVMetalTextureRef yMetalTexture;
        CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                 self->metalTextureCache,
                                                                 pixelBuffer,
                                                                 NULL,
                                                                 MTLPixelFormatR8Unorm,
                                                                 yWidth,
                                                                 yHeight,
                                                                 0,
                                                                 &yMetalTexture);
        if(ret != kCVReturnSuccess) return;
        id<MTLTexture> yTexture = CVMetalTextureGetTexture(yMetalTexture);
        if(!yTexture) return;
        /// Get uv plane width and height
        size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        CVMetalTextureRef uvMetalTexture;
        ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                        self->metalTextureCache,
                                                        pixelBuffer,
                                                        NULL,
                                                        MTLPixelFormatRG8Unorm,
                                                        uvWidth,
                                                        uvHeight,
                                                        1,
                                                        &uvMetalTexture);
        if(ret != kCVReturnSuccess) return;
        id<MTLTexture> uvTexture = CVMetalTextureGetTexture(uvMetalTexture);
        if(!uvTexture) return;
        CVPixelBufferRelease(pixelBuffer);
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                CAMetalLayer *layer = (CAMetalLayer *)self.layer;
                id<CAMetalDrawable> drawable = [layer nextDrawable];
                id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
                id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
                [commandEncoder setComputePipelineState:self.computePipline];
                [commandEncoder setTexture:yTexture atIndex:0];
                [commandEncoder setTexture:uvTexture atIndex:1];
                simd_uint2 byteSize = simd_make_uint2((uint32_t)yWidth, (uint32_t)yHeight);
                [commandEncoder setBytes:&byteSize length:sizeof(simd_uint2) atIndex:2];
                [commandEncoder setTexture:drawable.texture atIndex:3];
                NSUInteger threadExecutionWidth = self.computePipline.threadExecutionWidth;
                NSUInteger maxTotalThreadsPerThreadgroup = self.computePipline.maxTotalThreadsPerThreadgroup;
                MTLSize threadgroupSize = MTLSizeMake(threadExecutionWidth,
                                                      maxTotalThreadsPerThreadgroup / threadExecutionWidth,
                                                      1);
                MTLSize threadgroupCount = MTLSizeMake((yWidth  + threadgroupSize.width -  1) / threadgroupSize.width,
                                                       (yHeight + threadgroupSize.height - 1) / threadgroupSize.height,
                                                       1);
                [commandEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];

                [commandEncoder endEncoding];
                [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
                    CVBufferRelease(yMetalTexture);
                    CVBufferRelease(uvMetalTexture);
                }];
                [commandBuffer presentDrawable:drawable];
                [commandBuffer commit];
            }
        });
    });
}
- (AVPixelFormat)pixelFormat {
    return AV_PIX_FMT_NV12;
}

@end
