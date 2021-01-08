//
//  YUVOpenGLDisplayView.m
//  FFDemo-MacUI
//
//  Created by youxiaobin on 2020/12/17.
//

#import "FFOpenGLRender.h"
#import <OpenGL/gl3.h>
#define _CFToString(obj) ((__bridge NSString *)obj)



@interface FFOpenGLRender()
@end
@implementation FFOpenGLRender {
    dispatch_queue_t _display_rgb_queue;
    /// 顶点对象
    GLuint _VBO;
    GLuint _VAO;
    GLuint _yTexture;
    GLuint _uTexture;
    GLuint _vTexture;
    GLuint _glProgram;
    /// 顶点着色器
    GLuint _vertextShader;
    /// 片段着色器
    GLuint _fragmentShader;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setOpenGLContext:[ self _createOpenGLContext]];
        [self _setupOpenGLProgram];
        [self _setupOpenGL];
    }
    return self;
}
- (void)dealloc {
    glDeleteProgram(_glProgram);
    glDeleteBuffers(1, &_VBO);
    glDeleteVertexArrays(1, &_VAO);
    glDeleteTextures(1, &_yTexture);
    glDeleteTextures(1, &_uTexture);
    glDeleteTextures(1, &_vTexture);
}
#pragma mark - Private
- (NSOpenGLContext *)_createOpenGLContext {
    NSOpenGLPixelFormatAttribute attr[] = {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 24,
        0
    };
    NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
    if (!pf) {
        NSLog(@"No OpenGL pixel format");
    }
    NSOpenGLContext *openGLContext = [[NSOpenGLContext alloc] initWithFormat:pf shareContext: nil] ;
    return openGLContext;
}
#pragma mark - OpenGL
/// 编译着色器
- (GLuint)_compileShader:(NSString *)shaderName shaderType:(GLuint)shaderType {
    if(shaderName.length == 0) return -1;
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"glsl"];
    NSError *error;
    NSString *source = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if(error) return -1;
    GLuint shader = glCreateShader(shaderType);
    const char *ss = [source UTF8String];
    glShaderSource(shader, 1, &ss, NULL);
    glCompileShader(shader);
    int  success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if(!success) {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, NULL, infoLog);
        printf("shader error msg: %s \n", infoLog);
    }
    return shader;
}
/// 初始化OpenGL可编程程序
- (BOOL)_setupOpenGLProgram {
    [self.openGLContext makeCurrentContext];
    _glProgram = glCreateProgram();
    _vertextShader = [self _compileShader:@"vertex" shaderType:GL_VERTEX_SHADER];
    _fragmentShader = [self _compileShader:@"yuv_fragment" shaderType:GL_FRAGMENT_SHADER];
    glAttachShader(_glProgram, _vertextShader);
    glAttachShader(_glProgram, _fragmentShader);
    glLinkProgram(_glProgram);
    GLint success;
    glGetProgramiv(_glProgram, GL_LINK_STATUS, &success);
    if(!success) {
        char infoLog[512];
        glGetProgramInfoLog(_glProgram, 512, NULL, infoLog);
        printf("Link shader error: %s \n", infoLog);
    }
    glDeleteShader(_vertextShader);
    glDeleteShader(_fragmentShader);
    return success;
}
- (void)_setupOpenGL {
    [self.openGLContext makeCurrentContext];
    glGenVertexArrays(1, &_VAO);
    /// 创建顶点缓存对象
    glGenBuffers(1, &_VBO);
    /// 顶点数据
    float vertices[] = {
        // positions        // texture coords
        1.0f,  1.0f, 0.0f,  1.0f, 0, // top right
        1.0f, -1.0f, 0.0f,  1.0f, 1, // bottom right
       -1.0f, -1.0f, 0.0f,  0.0f, 1, // bottom left
       -1.0f, -1.0f, 0.0f,  0.0f, 1, // bottom left
       -1.0f,  1.0f, 0.0f,  0.0f, 0, // top left
        1.0f,  1.0f, 0.0f,  1.0f, 0, // top right
    };
    glBindVertexArray(_VAO);
    /// 绑定顶点缓存对象到当前的顶点位置,之后对GL_ARRAY_BUFFER的操作即是对_VBO的操作
    /// 同时也指定了_VBO的对象类型是一个顶点数据对象
    glBindBuffer(GL_ARRAY_BUFFER, _VBO);
    /// 将CPU数据发送到GPU,数据类型GL_ARRAY_BUFFER
    /// GL_STATIC_DRAW 表示数据不会被修改,将其放置在GPU显存的更合适的位置,增加其读取速度
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    
    /// 指定顶点着色器位置为0的参数的数据读取方式与数据类型
    /// 第一个参数: 参数位置
    /// 第二个参数: 一次读取数据
    /// 第三个参数: 数据类型
    /// 第四个参数: 是否归一化数据
    /// 第五个参数: 间隔多少个数据读取下一次数据
    /// 第六个参数: 指定读取第一个数据在顶点数据中的偏移量
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    /// 启用顶点着色器中位置为0的参数
    glEnableVertexAttribArray(0);
    
    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
    
    glGenTextures(1, &_yTexture);
    [self _configTexture:_yTexture];
    
    glGenTextures(1, &_uTexture);
    [self _configTexture:_uTexture];
    
    glGenTextures(1, &_vTexture);
    [self _configTexture:_vTexture];
    
    glBindVertexArray(0);
    
}
- (void)_configTexture:(GLuint)texture {
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenerateMipmap(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, 0);
}
#pragma mark - Override
- (void)displayWithAVFrame:(AVFrame *)yuvFrame {
    int videoWidth = yuvFrame->width;
    int videoHeight = yuvFrame->height;
    CGLLockContext([self.openGLContext CGLContextObj]);
    [self.openGLContext makeCurrentContext];
    glClearColor(0.0, 0.0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glEnable(GL_TEXTURE_2D);
    glUseProgram(_glProgram);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _yTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, videoWidth, videoHeight, 0, GL_RED, GL_UNSIGNED_BYTE, yuvFrame->data[0]);
    glUniform1i(glGetUniformLocation(_glProgram, "yTexture"), 0);
    
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _uTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, videoWidth / 2, videoHeight / 2, 0, GL_RED, GL_UNSIGNED_BYTE, yuvFrame->data[1]);
    glUniform1i(glGetUniformLocation(_glProgram, "uTexture"), 1);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _vTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, videoWidth / 2, videoHeight / 2, 0, GL_RED, GL_UNSIGNED_BYTE, yuvFrame->data[2]);
    glUniform1i(glGetUniformLocation(_glProgram, "vTexture"), 2);
    
    glBindVertexArray(_VAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    [self.openGLContext flushBuffer];
    
    CGLUnlockContext([self.openGLContext CGLContextObj]);
    
}
- (AVPixelFormat)piexlFormat {
    return AV_PIX_FMT_YUV420P;
}


@end
