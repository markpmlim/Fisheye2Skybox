/*
*/

#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import "OpenGLRenderer.h"
#import "AAPLMathUtilities.h"
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"


@implementation OpenGLRenderer {
    GLuint _defaultFBOName;
    CGSize _viewSize;

    GLuint _glslProgram;

    GLuint _quadVAO;
    GLuint _quadVBO;

    GLuint _skyboxTextureID;

    CGSize _tex0Resolution;

    GLint _resolutionLoc;
    GLint _mouseLoc;
    GLint _timeLoc;
    GLfloat _currentTime;

    double _time;

    GLint _viewDirectionProjectionInverse;

    matrix_float4x4 _projectionMatrix;  // unused
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName
{
    self = [super init];
    if(self) {
        NSLog(@"%s %s", glGetString(GL_RENDERER), glGetString(GL_VERSION));

        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName;
        // Must bind or buildProgramWithVertexSourceURL:withFragmentSourceURL will crash on validation.
        [self buildResources];
        glBindVertexArray(_quadVAO);

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *vertexSourceURL = [mainBundle URLForResource:@"fisheye2skybox"
                                              withExtension:@"vs"];
        NSURL *fragmentSourceURL = [mainBundle URLForResource:@"fisheye2skybox"
                                              withExtension:@"fs"];
        _glslProgram = [OpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                 withFragmentSourceURL:fragmentSourceURL];
        printf("%u\n", _glslProgram);
        _viewDirectionProjectionInverse = glGetUniformLocation(_glslProgram, "u_viewDirectionProjectionInverse");
        printf("%u\n", _viewDirectionProjectionInverse);
        NSString *name = @"PicassoTower.jpg";
        _skyboxTextureID = [self textureWithContentsOfFile:name
                                              resolution:&_tex0Resolution
                                                   isHDR:NO];
        glBindVertexArray(0);
        // _viewSize is CGSizeZero but that's ok because the resize: method
        //  will be called shortly. The virtual camera's screen size will
        //  be set correctly.
    }

    return self;
}

- (void)dealloc
{
    glDeleteProgram(_glslProgram);
    glDeleteVertexArrays(1, &_quadVAO);
    glDeleteTextures(1, &_skyboxTextureID);
    glDeleteBuffers(1, &_quadVBO);
}

- (void)buildResources
{
    if (_quadVAO == 0) {
        // Array of vertices of quad
        GLfloat quadVertices[] = {
            -1.0f, -1.0f, 0.0f, // vert 0
             1.0f, -1.0f, 0.0f, // vert 1
             1.0f,  1.0f, 0.0f, // vert 2
            
             1.0f,  1.0f, 0.0f, // vert 2
            -1.0f,  1.0f, 0.0f, // vert 3
            -1.0f, -1.0f, 0.0f, // vert 0
        };

        glGenVertexArrays(1, &_quadVAO);
        glBindVertexArray(_quadVAO);
        glGenBuffers(1, &_quadVBO);
        glBindBuffer(GL_ARRAY_BUFFER, _quadVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), (void*)0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }
}

- (void)resize:(CGSize)size
{
    // Handle the resize of the draw rectangle. In particular, update the perspective projection matrix
    // with a new aspect ratio because the view orientation, layout, or size has changed.
    _viewSize = size;
    float aspect = (float)size.width / size.height;
    _projectionMatrix = matrix_perspective_right_hand_gl(radians_from_degrees(45.0f),
                                                         aspect,
                                                         1.0f, 20.0);
}

- (GLuint)textureWithContentsOfFile:(NSString *)name
                         resolution:(CGSize *)size
                              isHDR:(BOOL)isHDR
{
    //NSLog(@"%@", name);
    GLuint textureID = 0;
    GLint width = 0;
    GLint height = 0;
    GLint numComponents = 0;
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    // The objects of filePath should be either NSString or NSURL
    NSArray<NSString *> *subStrings = [name componentsSeparatedByString:@"."];
    
    NSString* filePath = [mainBundle pathForResource:subStrings[0]
                                              ofType:subStrings[1]];
    if (isHDR == YES) {
        glGenTextures(1, &textureID);
        glBindTexture(GL_TEXTURE_2D, textureID);
        // The flag stbi__vertically_flip_on_load defaults to false
        GLfloat *data = nil;
        data = stbi_loadf([filePath UTF8String],
                          &width, &height, &numComponents, 0);
        if (data != nil) {
            glTexImage2D(GL_TEXTURE_2D,
                         0,
                         GL_RGB16F,
                         width, height,
                         0,
                         GL_RGB,
                         GL_FLOAT,
                         data);
            stbi_image_free(data);

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            size->width = width;
            size->height = height;
        }
    }
    else {
        NSDictionary *loaderOptions = @{
                                        GLKTextureLoaderOriginBottomLeft : @YES,
                                        //GLKTextureLoaderSRGB : @YES
                                        };
        NSError *error = nil;
        GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithContentsOfFile:filePath
                                                                          options:loaderOptions
                                                                            error:&error];
        if (error != nil) {
            NSLog(@"Cannot instantiate a texture from the file:%@ Error Code:%@", filePath, error);
        }
        //NSLog(@"%@", textureInfo);
        textureID = textureInfo.name;
        size->width = textureInfo.width;
        size->height = textureInfo.height;
    }
    return textureID;
}

// We define pitch, yaw and roll to be angle rotations about
// the x-axis, y-axis and z-axis respectively
// Other authors might define them as y-axis, z-axis and x-axis respectively.
// Tait-Bryan Euler angle convention (z-y-x)
- (void)update
{
    _time += 0.05;
}

- (void)draw
{
    [self update];
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glViewport(0, 0,
               _viewSize.width, _viewSize.height);
    matrix_float4x4 rotateY = matrix4x4_rotation(_time * 0.1,
                                                 0.0, 1.0, 0.0);
    matrix_float4x4 rotateX  = matrix4x4_rotation(0.7 + sinf(_time * 0.3) * 0.7,
                                                  1.0, 0.0, 0.0);
    matrix_float4x4 cameraMatrix = matrix_multiply(rotateX, rotateY);
    // The view matrix is the inverse of the camera matrix.
    matrix_float4x4 viewMatrix = matrix_invert(cameraMatrix);
    // Zero the translation component of the view matrix
    viewMatrix.columns[3].x = 0;
    viewMatrix.columns[3].y = 0;
    viewMatrix.columns[3].z = 0;

    matrix_float4x4 viewDirectionProjectionMatrix = matrix_multiply(_projectionMatrix, viewMatrix);
    viewDirectionProjectionMatrix = matrix_invert(viewDirectionProjectionMatrix);

    glUseProgram(_glslProgram);
    glUniformMatrix4fv(_viewDirectionProjectionInverse, 1, GL_FALSE, (const GLfloat*)&viewDirectionProjectionMatrix);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _skyboxTextureID);
    // Bind the quad vertex array object.
    glBindVertexArray(_quadVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glUseProgram(0);
    glBindVertexArray(0);
} // draw


+ (GLuint)buildProgramWithVertexSourceURL:(NSURL*)vertexSourceURL
                    withFragmentSourceURL:(NSURL*)fragmentSourceURL
{

    NSError *error;

    NSString *vertSourceString = [[NSString alloc] initWithContentsOfURL:vertexSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(vertSourceString, @"Could not load vertex shader source, error: %@.", error);

    NSString *fragSourceString = [[NSString alloc] initWithContentsOfURL:fragmentSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(fragSourceString, @"Could not load fragment shader source, error: %@.", error);

    // Prepend the #version definition to the vertex and fragment shaders.
    float  glLanguageVersion;

#if TARGET_OS_IOS
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "OpenGL ES GLSL ES %f", &glLanguageVersion);
#else
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "%f", &glLanguageVersion);
#endif

    // `GL_SHADING_LANGUAGE_VERSION` returns the standard version form with decimals, but the
    //  GLSL version preprocessor directive simply uses integers (e.g. 1.10 should be 110 and 1.40
    //  should be 140). You multiply the floating point number by 100 to get a proper version number
    //  for the GLSL preprocessor directive.
    GLuint version = 100 * glLanguageVersion;

    NSString *versionString = [[NSString alloc] initWithFormat:@"#version %d", version];
#if TARGET_OS_IOS
    if ([[EAGLContext currentContext] API] == kEAGLRenderingAPIOpenGLES3)
        versionString = [versionString stringByAppendingString:@" es"];
#endif

    vertSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, vertSourceString];
    fragSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, fragSourceString];

    GLuint prgName;

    GLint logLength, status;

    // Create a GLSL program object.
    prgName = glCreateProgram();

    /*
     * Specify and compile a vertex shader.
     */

    GLchar *vertexSourceCString = (GLchar*)vertSourceString.UTF8String;
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, (const GLchar **)&(vertexSourceCString), NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);

    if (logLength > 0) {
        GLchar *log = (GLchar*) malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"Vertex shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the vertex shader:\n%s.\n", vertexSourceCString);

    // Attach the vertex shader to the program.
    glAttachShader(prgName, vertexShader);

    // Delete the vertex shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(vertexShader);

    /*
     * Specify and compile a fragment shader.
     */

    GLchar *fragSourceCString =  (GLchar*)fragSourceString.UTF8String;
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, (const GLchar **)&(fragSourceCString), NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetShaderInfoLog(fragShader, logLength, &logLength, log);
        NSLog(@"Fragment shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the fragment shader:\n%s.", fragSourceCString);

    // Attach the fragment shader to the program.
    glAttachShader(prgName, fragShader);

    // Delete the fragment shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(fragShader);

    /*
     * Link the program.
     */

    glLinkProgram(prgName);
    glGetProgramiv(prgName, GL_LINK_STATUS, &status);
    NSAssert(status, @"Failed to link program.");
    if (status == 0) {
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0)
        {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program link log:\n%s.\n", log);
            free(log);
        }
    }

    // Added code
    // Call the 2 functions below if VAOs have been bound prior to creating the shader program
    // iOS will not complain if VAOs have NOT been bound.
    glValidateProgram(prgName);
    glGetProgramiv(prgName, GL_VALIDATE_STATUS, &status);
    //NSAssert(status, @"Failed to validate program.");

    if (status == 0) {
        fprintf(stderr,"Program cannot run with current OpenGL State\n");
        glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0) {
            GLchar *log = (GLchar*)malloc(logLength);
            glGetProgramInfoLog(prgName, logLength, &logLength, log);
            NSLog(@"Program validate log:\n%s\n", log);
            free(log);
        }
    }

    GetGLError();

    return prgName;
}

@end
