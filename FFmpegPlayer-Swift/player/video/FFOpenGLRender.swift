//
//  FFOpenGLRender.swift
//  FFmpegPlayer-Swift
//
//  Created by youxiaobin on 2021/1/8.
//

import Foundation
import AppKit
import OpenGL.GL3



class FFOpenGLRender: NSOpenGLView {
    
    private var glProgram: GLuint = 0
    private var vertexShader: GLuint = 0
    private var fragmentShader: GLuint = 0
    private var VAO: GLuint = 0
    private var VBO: GLuint = 0
    private var yTexture: GLuint = 0
    private var uTexture: GLuint = 0
    private var vTexture: GLuint = 0
    
    override init?(frame frameRect: NSRect, pixelFormat format: NSOpenGLPixelFormat?) {
        super.init(frame: frameRect, pixelFormat: format)
        self.openGLContext = createOpenGLContext()
        if self.openGLContext == nil {
            fatalError("初始化OpenGLContext失败")
        }
        if !self.setupGLProgram() {
            fatalError("初始化OpenGL失败")
        }
        if !self.setupGLDrawConfig() {
            fatalError("配置OpenGL失败")
        }
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FFOpenGLRender {
    private func createOpenGLContext() -> NSOpenGLContext? {
        let attr: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile),
            UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(NSOpenGLPFANoRecovery),
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAColorSize),
            0
        ]
        guard let p = (attr.withUnsafeBufferPointer { $0.baseAddress }) else { return nil }
        guard let pf = NSOpenGLPixelFormat.init(attributes: p) else { return nil }
        
        return NSOpenGLContext.init(format: pf, share: nil)
    }
    private func compile(shaderName: String, shaderType: Int32) -> GLuint {
        guard let shaderPath = Bundle.main.path(forResource: shaderName, ofType: "glsl") else { return 0 }
        guard let shaderContent = try? String.init(contentsOfFile: shaderPath) as NSString else { return 0 }
        var bytes = shaderContent.utf8String
        let shader = glCreateShader(GLenum(shaderType))
        glShaderSource(shader, 1, &bytes, nil)
        glCompileShader(shader)
        var success = GL_FALSE;
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &success);
        if success == GL_FALSE {
            var message = [GLchar]()
            glGetShaderInfoLog(shader, GLsizei(MemoryLayout<GLchar>.size * 512), nil, &message)
            let errorInfo = String(cString: message, encoding: .utf8)
            print("shaderErrorInfo:" + (errorInfo ?? ""))
            return 0
        }
        return shader
        
    }
    private func setupGLProgram() -> Bool {
        self.openGLContext?.makeCurrentContext()
        self.glProgram = glCreateProgram()
        self.vertexShader = compile(shaderName: "vertex", shaderType: GL_VERTEX_SHADER)
        guard self.vertexShader > 0 else { return false }
        self.fragmentShader = compile(shaderName: "yuv_fragment", shaderType: GL_FRAGMENT_SHADER)
        guard self.fragmentShader > 0 else { return false }
        glAttachShader(glProgram, self.vertexShader)
        glAttachShader(glProgram, self.fragmentShader)
        glLinkProgram(glProgram)
        var success = GL_FALSE
        glGetProgramiv(glProgram, GLenum(GL_LINK_STATUS), &success);
        
        var message = [GLchar]()
        glGetShaderInfoLog(glProgram, GLsizei(MemoryLayout<GLchar>.size * 512), nil, &message)
        let errorInfo = String(cString: message, encoding: .utf8)
        print("shaderErrorInfo:" + (errorInfo ?? ""))
        
        defer {
            glDeleteShader(self.vertexShader)
            glDeleteShader(self.fragmentShader)
        }
        return success != GL_FALSE
    }
    
    private func configTexture(_ texture: GLuint) {
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLint(GL_REPEAT))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLint(GL_REPEAT))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))
        glGenerateMipmap(GLenum(GL_TEXTURE_2D))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
    }
    
    private func setupGLDrawConfig() -> Bool {
        self.openGLContext?.makeCurrentContext()
        glGenVertexArrays(1, &VAO);
        /// 创建顶点缓存对象
        glGenBuffers(1, &VBO);
        /// 顶点数据
        let vertices: [GLfloat] = [
            // positions        // texture coords
            1.0,  1.0, 0.0,  1.0, 0, // top right
            1.0, -1.0, 0.0,  1.0, 1, // bottom right
           -1.0, -1.0, 0.0,  0.0, 1, // bottom left
           -1.0, -1.0, 0.0,  0.0, 1, // bottom left
           -1.0,  1.0, 0.0,  0.0, 0, // top left
            1.0,  1.0, 0.0,  1.0, 0, // top right
        ]
        glBindVertexArray(VAO);
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), VBO);
        guard let p = (vertices.withUnsafeBufferPointer { $0.baseAddress }) else { return false }
        glBufferData(GLenum(GL_ARRAY_BUFFER),
                     30 * MemoryLayout<GLfloat>.size,
                     p,
                     GLenum(GL_STATIC_DRAW)
        );
        glVertexAttribPointer(0,
                              3,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              GLsizei(5 * MemoryLayout<GLfloat>.size),
                              UnsafeRawPointer.init(bitPattern: 0));
        glEnableVertexAttribArray(0);
        
        glVertexAttribPointer(1,
                              2,
                              GLenum(GL_FLOAT),
                              GLboolean(GL_FALSE),
                              GLsizei(5 * MemoryLayout<GLfloat>.size),
                              UnsafeRawPointer.init(bitPattern: 3 * MemoryLayout<GLfloat>.size));
        glEnableVertexAttribArray(1)
        
        glGenTextures(1, &yTexture)
        self.configTexture(yTexture)
        
        glGenTextures(1, &uTexture)
        self.configTexture(uTexture)
        
        glGenTextures(1, &vTexture)
        self.configTexture(vTexture)
        
        glBindVertexArray(0)
        
        return true
    }
}

extension FFOpenGLRender : FFVideoRender {
    var pixFMT: AVPixelFormat { AV_PIX_FMT_YUV420P }
    var render: NSView { self }
    
    func display(with frame: UnsafeMutablePointer<AVFrame>) {
        let videoWidth = frame.pointee.width;
        let videoHeight = frame.pointee.height;
        guard let glContext = self.openGLContext else { return }
        CGLLockContext(glContext.cglContextObj!)
        glContext.makeCurrentContext()
        glClearColor(0.0, 0.0, 0, 0);
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT));
        glEnable(GLenum(GL_TEXTURE_2D));
        glUseProgram(glProgram);
        
        glActiveTexture(GLenum(GL_TEXTURE0));
        glBindTexture(GLenum(GL_TEXTURE_2D), yTexture);
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GLint(GL_RED),
                     videoWidth,
                     videoHeight,
                     0,
                     GLenum(GL_RED),
                     GLenum(GL_UNSIGNED_BYTE),
                     frame.pointee.data.0);
        glUniform1i(glGetUniformLocation(glProgram, "yTexture"), 0);
        
        glActiveTexture(GLenum(GL_TEXTURE1));
        glBindTexture(GLenum(GL_TEXTURE_2D), uTexture);
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GLint(GL_RED),
                     videoWidth / 2,
                     videoHeight / 2,
                     0,
                     GLenum(GL_RED),
                     GLenum(GL_UNSIGNED_BYTE),
                     frame.pointee.data.1);
        glUniform1i(glGetUniformLocation(glProgram, "uTexture"), 1);
        
        glActiveTexture(GLenum(GL_TEXTURE2));
        glBindTexture(GLenum(GL_TEXTURE_2D), vTexture);
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GLint(GL_RED),
                     videoWidth / 2,
                     videoHeight / 2,
                     0,
                     GLenum(GL_RED),
                     GLenum(GL_UNSIGNED_BYTE),
                     frame.pointee.data.2);
        glUniform1i(glGetUniformLocation(glProgram, "vTexture"), 2);
        
        glBindVertexArray(VAO);
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 6);
        glContext.flushBuffer()
        
        CGLUnlockContext(glContext.cglContextObj!);
    }
}
