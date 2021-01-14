//
//  Metal.metal
//  FFDemo-MacUI
//
//  Created by youxiaobin on 2020/12/11.
//

#include <metal_stdlib>
using namespace metal;
///y_inTexture: Y
///uv_inTexture: UV
///byteSize: Y的宽高
///outTexture: RGBA
///gid: 执行线程所在的Grid位置
kernel void yuv420ToRGB(texture2d<float, access::read> y_inTexture [[ texture(0) ]],
                        texture2d<float, access::read> uv_inTexture [[ texture(1) ]],
                        constant uint2 &byteSize [[ buffer(2) ]],
                        texture2d<float, access::write> outTexture [[ texture(3) ]],
                        uint2 gid [[ thread_position_in_grid ]]) {
    if(gid.x > byteSize.x || gid.y > byteSize.y) return;
//    if(gid.x % 2 == 0 || gid.y % 2 == 0 || gid.x % 3 == 0 || gid.y % 3 == 0) {
//        outTexture.write(float4(0, 0, 0, 1.0), gid);
//        return;
//    }
    /// 获取y分量数据,由于在创建MetalTexture的时候在方法CVMetalTextureCacheCreateTextureFromImage
    /// 中指定了归一化的格式,所以这里得到的y值范围是[0, 1]
    float4 yFloat4 = y_inTexture.read(gid);

    /// Y与UV在YUV420P格式下的比例是4:1
    /// YUV420P垂直与水平分别是2:1的比例
    /// gid是包含X，Y坐标,所以这里gid/2实际上是缩小了4倍，符合YUV420P中Y与UV的比例
    /// 每4个Y共享一组UV
    float4 uvFloat4 = uv_inTexture.read(gid/2);
    float y = yFloat4.x;
    float cb = uvFloat4.x;
    float cr = uvFloat4.y;
    
    /// 按YCbCr转RGB的公式进行数据转换
    float r = y + 1.403 * (cr - 0.5);
    float g = y - 0.343 * (cb - 0.5) - 0.714 * (cr - 0.5);
    float b = y + 1.770 * (cb - 0.5);
    outTexture.write(float4(r, g, b, 1.0), gid);
        
}

