//
//  HTYGLKVC.m
//  HTY360Player
//
//  Created by  on 11/8/15.
//  Copyright © 2015 Hanton. All rights reserved.
//
//  Modified by Evgeniy Upenik on 2016-03-02
//              EPFL, MMSPG
//

#import "HTYGLKVC.h"
#import "GLProgram.h"
#import "HTY360PlayerVC.h"
#import <CoreMotion/CoreMotion.h>


#define MAX_OVERTURE 95.0
#define MIN_OVERTURE 25.0
#define DEFAULT_OVERTURE 85.0

#define ES_PI  (3.14159265f)

#define ROLL_CORRECTION (-ES_PI/2.0)
//#define ROLL_CORRECTION 0

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)
// BT.709, which is the standard for HDTV
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// Uniform index
enum {
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Video rendering layout
enum videoLayout_t {
    EQUIRECTANGULAR,
    CUBEMAP_32,
    //PLANE_CUBEMAP_32,
    //CUBEMAP_180,
    NUM_LAYOUTS
};
enum videoLayout_t currentLayout;


@interface HTYGLKVC () {
    
    GLKMatrix4 _modelViewProjectionMatrix;
    
    GLuint _vertexArrayID;
    GLuint _vertexBufferID;
    GLuint _vertexIndicesBufferID;
    GLuint _vertexTexCoordID;
    GLuint _vertexTexCoordAttributeIndex;
    
    float _fingerRotationX;
    float _fingerRotationY;
    float _savedGyroRotationX;
    float _savedGyroRotationY;
    CGFloat _overture;
    
    int _numIndices;
    
    CMMotionManager *_motionManager;
    CMAttitude *_referenceAttitude;
    
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    const GLfloat *_preferredConversion;
    
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLProgram *program;
@property (strong, nonatomic) NSMutableArray *currentTouches;
@property (strong, nonatomic) NSArray *layoutName;

- (void)setupGL;
- (void)tearDownGL;
- (void)buildProgram;

@end

@implementation HTYGLKVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectOrientation) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    UIPinchGestureRecognizer *pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    [view addGestureRecognizer:pinchRecognizer];
    
    UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTapGesture:)];
    singleTapRecognizer.numberOfTapsRequired = 1;
    [view addGestureRecognizer:singleTapRecognizer];
    
    self.preferredFramesPerSecond = 30.0f;
    
    _overture = DEFAULT_OVERTURE;
    
    // Set the default conversion to BT.709, which is the standard for HDTV.
    _preferredConversion = kColorConversion709;
    
    currentLayout = CUBEMAP_32;
    _layoutName = @[ @"Equirectangular", @"Cubemap32", @"PlaneCubemap32", @"Cubemap180"];
    
    [self setupGL];
    
    [self startDeviceMotion];
}

-(UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

-(void) detectOrientation {
    //    _referenceAttitude = nil;
}

- (void)dealloc {
    [self stopDeviceMotion];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
    
    // Dispose of any resources that can be recreated.
}


#pragma mark Generate layout projection meshes

// Sphere mesh | further here we use 200 slices -> 100 parallels
int esGenSphere ( int numSlices, float radius, float **vertices, float **normals,
                 float **texCoords, uint16_t **indices, int *numVertices_out) {
    
    int i; int j;
    int numParallels = numSlices / 2;
    int numVertices = ( numParallels + 1 ) * ( numSlices + 1 );
    int numIndices = numParallels * numSlices * 6;
    float angleStep = (2.0f * ES_PI) / ((float) numSlices);
    
    // Allocate space for mesh data
    if ( vertices != NULL )
        *vertices = malloc ( sizeof(float) * 3 * numVertices );
    
    if ( texCoords != NULL )
        *texCoords = malloc ( sizeof(float) * 2 * numVertices );
    
    if ( indices != NULL )
        *indices = malloc ( sizeof(uint16_t) * numIndices );
    
    // Calculate coordinates
    for ( i = 0; i < numParallels + 1; i++ ) {
        for ( j = 0; j < numSlices + 1; j++ ) {
            int vertex = ( i * (numSlices + 1) + j ) * 3;
            
            // Generate world space (3D) coords for every point on flat projection
            // Though some vertices apear more than once in the array
            if ( vertices ) {
                (*vertices)[vertex + 0] = radius * sinf ( angleStep * (float)i ) * sinf ( angleStep * (float)j ); // X
                (*vertices)[vertex + 1] = radius * cosf ( angleStep * (float)i );                                 // Y
                (*vertices)[vertex + 2] = radius * sinf ( angleStep * (float)i ) * cosf ( angleStep * (float)j ); // Z
            }
            
            // Assign 2D plane coords to each element of vertices array
            if ( texCoords ) {
                int texIndex = ( i * (numSlices + 1) + j ) * 2;
                (*texCoords)[texIndex + 0] = (float) j / (float) numSlices;
                (*texCoords)[texIndex + 1] = 1.0f - ((float) i / (float) (numParallels));
            }
        }
    }
    
    // Generate the indices
    if ( indices != NULL ) {
        uint16_t *indexBuf = (*indices);
        for ( i = 0; i < numParallels ; i++ ) {
            for ( j = 0; j < numSlices; j++ ) {
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                *indexBuf++ = i * ( numSlices + 1 ) + ( j + 1 );
            }
        }
    }
    
    if (numVertices_out) {
        *numVertices_out = numVertices;
    }
    
    return numIndices;
}

// Cube mesh
int esGenCube ( float radius, float **vertices, float **normals,
                 float **texCoords, uint16_t **indices, int *numVertices_out) {

    int numVertices = 24;
    int numIndices = 24/4 * 6;
    float r = radius;

    // Allocate space for mesh data
    if ( vertices != NULL )
        *vertices = malloc ( sizeof(float) * 3 * numVertices );
    if ( texCoords != NULL )
        *texCoords = malloc ( sizeof(float) * 2 * numVertices );
    if ( indices != NULL )
        *indices = malloc ( sizeof(uint16_t) * numIndices );
    
    
    // Vertices for cube in 3D space        
    //                                        
    //            7-----6      ^ y                  6---7
    //           /|    /|      |                    |+Y |
    //          4-----5 |      |                6---5---4---7---6
    //          | 3- -|-2      /-----> x        |-X |+Z |+X |-Z |
    //          |/    |/      /                 2---1---0---3---2
    //          0-----1      |/                     |-Y |
    //                       'z                     2---3
    //
    //                     X                           Y                           Z
#define ADD_VX_0(n) (*vertices)[n*3 + 0] = -r; (*vertices)[n*3 + 1] =  r; (*vertices)[n*3 + 2] = -r;
#define ADD_VX_1(n) (*vertices)[n*3 + 0] =  r; (*vertices)[n*3 + 1] =  r; (*vertices)[n*3 + 2] = -r;
#define ADD_VX_2(n) (*vertices)[n*3 + 0] =  r; (*vertices)[n*3 + 1] =  r; (*vertices)[n*3 + 2] =  r;
#define ADD_VX_3(n) (*vertices)[n*3 + 0] = -r; (*vertices)[n*3 + 1] =  r; (*vertices)[n*3 + 2] =  r;
#define ADD_VX_4(n) (*vertices)[n*3 + 0] = -r; (*vertices)[n*3 + 1] = -r; (*vertices)[n*3 + 2] = -r;
#define ADD_VX_5(n) (*vertices)[n*3 + 0] =  r; (*vertices)[n*3 + 1] = -r; (*vertices)[n*3 + 2] = -r;
#define ADD_VX_6(n) (*vertices)[n*3 + 0] =  r; (*vertices)[n*3 + 1] = -r; (*vertices)[n*3 + 2] =  r;
#define ADD_VX_7(n) (*vertices)[n*3 + 0] = -r; (*vertices)[n*3 + 1] = -r; (*vertices)[n*3 + 2] =  r;
    
    // Texture coordinates on plane for vertices
    //
    //        6---7               4---7 6---5 6---7  <--- top
    //        |+Y |               |+X | |-X | |+Y |
    //    6---5---4---7---6       0---3 2---1 5---4  <--- mid
    //    |-X |+Z |+X |-Z |       1---0 5---4 7---6
    //    2---1---0---3---2       |-Y | |+Z | |-Z |
    //        |-Y |               2---3 1---0 3---2  <--- bottom
    //        2---3               ^    ^     ^    ^
    //                          left l_mid r_mid right
    
    float top = 0.0f; float mid = 0.5f; float bottom = 1.0f;
    float left = 0.0f; float left_mid = left + 1.0/3.0;
    float right = 1.0f; float right_mid = right - 1.0/3.0;
    
// Assing texture coordinates to index of vertex
#define ADD_TX(n,x,y) (*texCoords)[n*2 + 0] = x; (*texCoords)[n*2 + 1] =  y;
    
    // +X: Right  | Vertices 0,3,7,4
    ADD_VX_0(0)  ADD_TX(0,left,    mid)
    ADD_VX_3(1)  ADD_TX(1,left_mid,mid)
    ADD_VX_7(2)  ADD_TX(2,left_mid,top)
    ADD_VX_4(3)  ADD_TX(3,left,    top)
    
    // -X: Left   | Vertices 2,1,5,6
    ADD_VX_2(4)  ADD_TX(4,left_mid, mid)
    ADD_VX_1(5)  ADD_TX(5,right_mid,mid)
    ADD_VX_5(6)  ADD_TX(6,right_mid,top)
    ADD_VX_6(7)  ADD_TX(7,left_mid, top)
    
    // +Y: Top    | Vertices 5,4,7,6
    ADD_VX_5(8)  ADD_TX( 8,right_mid,mid)
    ADD_VX_4(9)  ADD_TX( 9,right,    mid)
    ADD_VX_7(10) ADD_TX(10,right,    top)
    ADD_VX_6(11) ADD_TX(11,right_mid,top)
    
    // -Y: Bottom | Vertices 2,3,0,1
    ADD_VX_2(12) ADD_TX(12,left,    bottom)
    ADD_VX_3(13) ADD_TX(13,left_mid,bottom)
    ADD_VX_0(14) ADD_TX(14,left_mid,mid)
    ADD_VX_1(15) ADD_TX(15,left,    mid)
    
    // +Z: Front  | Vertices 1,0,4,5
    ADD_VX_1(16) ADD_TX(16,left_mid, bottom)
    ADD_VX_0(17) ADD_TX(17,right_mid,bottom)
    ADD_VX_4(18) ADD_TX(18,right_mid,mid)
    ADD_VX_5(19) ADD_TX(19,left_mid, mid)
    
    // -Z: Back   | Vertices 3,2,6,7
    ADD_VX_3(20) ADD_TX(20,right_mid,bottom)
    ADD_VX_2(21) ADD_TX(21,right,    bottom)
    ADD_VX_6(22) ADD_TX(22,right,    mid)
    ADD_VX_7(23) ADD_TX(23,right_mid,mid)
    
    
    // Generate the indices
    if ( indices != NULL ) {
        uint16_t *indexBuf = (*indices);
        for ( int i = 0; i < numVertices ; i+=4 ) {
            *indexBuf++ = i + 0; *indexBuf++ = i + 1; *indexBuf++ = i + 2;
            *indexBuf++ = i + 2; *indexBuf++ = i + 3; *indexBuf++ = i + 0;
        }
    }
    
    if (numVertices_out) {
        *numVertices_out = numVertices;
    }
    
    return numIndices;
}


#pragma mark Setup GL

- (void)setupGL {
    [EAGLContext setCurrentContext:self.context];
    
    [self buildProgram];
    
    GLfloat *vVertices = NULL;
    GLfloat *vTextCoord = NULL;
    GLushort *indices = NULL;
    int numVertices = 0;
    //_numIndices =  esGenSphere(200, 1.0f, &vVertices,  NULL,
    //                           &vTextCoord, &indices, &numVertices);
    _numIndices =  esGenCube( .707f, &vVertices,  NULL,
                               &vTextCoord, &indices, &numVertices);
    
    glGenVertexArraysOES(1, &_vertexArrayID);
    glBindVertexArrayOES(_vertexArrayID);
    
    // Vertex
    glGenBuffers(1, &_vertexBufferID);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferID);
    glBufferData(GL_ARRAY_BUFFER,
                 numVertices*3*sizeof(GLfloat),
                 vVertices,
                 GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(GLfloat) * 3,
                          NULL);
    
    // Texture Coordinates
    glGenBuffers(1, &_vertexTexCoordID);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexTexCoordID);
    glBufferData(GL_ARRAY_BUFFER,
                 numVertices*2*sizeof(GLfloat),
                 vTextCoord,
                 GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(_vertexTexCoordAttributeIndex);
    glVertexAttribPointer(_vertexTexCoordAttributeIndex,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(GLfloat) * 2,
                          NULL);
    
    //Indices
    glGenBuffers(1, &_vertexIndicesBufferID);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _vertexIndicesBufferID);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                 sizeof(GLushort) * _numIndices,
                 indices, GL_STATIC_DRAW);
    
    
    if (!_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
    
    [_program use];
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
}

- (void)tearDownGL {
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBufferID);
    glDeleteVertexArraysOES(1, &_vertexArrayID);
    glDeleteBuffers(1, &_vertexTexCoordID);
    
    _program = nil;
    _videoTextureCache = nil;
}

#pragma mark texture cleanup

- (void)cleanUpTextures {
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

#pragma mark device motion management

- (void)startDeviceMotion {
    NSLog(@"startDeviceMotion\n");
    _isUsingMotion = NO;
    
    _motionManager = [[CMMotionManager alloc] init];
    _referenceAttitude = nil;
    _motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;
    _motionManager.gyroUpdateInterval = 1.0f / 60;
    _motionManager.showsDeviceMovementDisplay = YES;
    
    [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
    
    //while (!_referenceAttitude)
    //    _referenceAttitude = _motionManager.deviceMotion.attitude; // Maybe nil actually. reset it later when we have data
    
    _savedGyroRotationX = 0;
    _savedGyroRotationY = 0;
    
    _isUsingMotion = YES;
    //NSLog(@"roll  %1.0f°", GLKMathRadiansToDegrees(_motionManager.deviceMotion.attitude.roll));
    //NSLog(@"yaw   %1.0f°", GLKMathRadiansToDegrees(_motionManager.deviceMotion.attitude.yaw));
    //NSLog(@"pitch %1.0f°", GLKMathRadiansToDegrees(_motionManager.deviceMotion.attitude.pitch));
}

- (void)stopDeviceMotion {
    NSLog(@"stopDeviceMotion\n");
    //NSLog(@"roll  %1.0f°", GLKMathRadiansToDegrees(_motionManager.deviceMotion.attitude.roll));
    //NSLog(@"yaw   %1.0f°", GLKMathRadiansToDegrees(_motionManager.deviceMotion.attitude.yaw));
    //NSLog(@"pitch %1.0f°", GLKMathRadiansToDegrees(_motionManager.deviceMotion.attitude.pitch));
    
    _fingerRotationX = _savedGyroRotationX;// - _referenceAttitude.roll - ROLL_CORRECTION;
    _fingerRotationY = _savedGyroRotationY;
    
    _isUsingMotion = NO;
    [_motionManager stopDeviceMotionUpdates];
    _motionManager = nil;
}

#pragma mark - GLKView and GLKViewController delegate methods

#if SHOW_DEBUG_LABEL
- (NSString *) orientationString: (UIDeviceOrientation) orientation {
    switch (orientation) {
        case UIDeviceOrientationUnknown: return @"Unknown";
        case UIDeviceOrientationPortrait: return @"Portrait";
        case UIDeviceOrientationPortraitUpsideDown: return @"Portrait Upside Down";
        case UIDeviceOrientationLandscapeLeft: return @"Landscape Left";
        case UIDeviceOrientationLandscapeRight: return @"Landscape Right";
        case UIDeviceOrientationFaceUp: return @"Face Up";
        case UIDeviceOrientationFaceDown: return @"Face Down";
        default: break;
    }
    return nil;
}

- (void)fillDebugValues:(CMAttitude *)attitude {
    self.videoPlayerController.rollValueLabel.text = [NSString stringWithFormat:@"%1.0f°", GLKMathRadiansToDegrees(attitude.roll)];
    self.videoPlayerController.yawValueLabel.text = [NSString stringWithFormat:@"%1.0f°", GLKMathRadiansToDegrees(attitude.yaw)];
    self.videoPlayerController.pitchValueLabel.text = [NSString stringWithFormat:@"%1.0f°", GLKMathRadiansToDegrees(attitude.pitch)];
    self.videoPlayerController.orientationValueLabel.text = [self orientationString:[[UIDevice currentDevice] orientation]];
}
#endif

- (BOOL) isLandscapeOrFlat {
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    return UIDeviceOrientationIsLandscape(orientation) || orientation==UIDeviceOrientationFaceUp || orientation==UIDeviceOrientationFaceDown;
}

- (BOOL) isPortrait {
    return UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation]);
}

- (void)update {
    
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(_overture), aspect, 0.1f, 400.0f);
    projectionMatrix = GLKMatrix4Rotate(projectionMatrix, ES_PI, 0.0f, 0.0f, 1.0f);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 300.0, 300.0, 300.0);
    
    if(_isUsingMotion) {
        CMDeviceMotion *d = _motionManager.deviceMotion;
        if (d != nil) {
            CMAttitude *attitude = d.attitude;
            
            if (_referenceAttitude != nil) {
                //[attitude multiplyByInverseOfAttitude:_referenceAttitude];
            } else {
                //NSLog(@"- update: Set new attitude:", nil);
                //NSLog(@"r %1.0f° y %1.0f° p %1.0f°", GLKMathRadiansToDegrees(attitude.roll),GLKMathRadiansToDegrees(attitude.yaw), GLKMathRadiansToDegrees(attitude.pitch));
                _referenceAttitude = d.attitude;
            }
            
#if SHOW_DEBUG_LABEL
            [self fillDebugValues:attitude];
#endif
            
            //float cRoll = -fabs(attitude.roll); // Up/Down en landscape
            float cRoll = attitude.roll;        // Up/Down en landscape + Add sturation /EU
            float cYaw = attitude.yaw;          // Left/ Right en landscape -> pas besoin de prendre l'opposé
            float cPitch = attitude.pitch;      // Depth en landscape -> pas besoin de prendre l'opposé
            
            UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
            if (orientation == UIDeviceOrientationLandscapeRight ){
                cPitch = -cPitch; // correct depth when in landscape right
            }
            if (orientation == UIDeviceOrientationLandscapeLeft ){
                cRoll = -cRoll;
                cYaw = -cYaw;
            }
            
            if (YES) {
                modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, cRoll); // Up/Down axis
                modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, cPitch);
                modelViewMatrix = GLKMatrix4RotateZ(modelViewMatrix, cYaw);
                modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, ROLL_CORRECTION);
                
                _savedGyroRotationX = -cRoll - ROLL_CORRECTION; //+ _fingerRotationX;
                _savedGyroRotationY = cPitch; //+ _fingerRotationY;
            }
        }
        
    } else {
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, -_fingerRotationX);
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, _fingerRotationY);
    }
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [_program use];
    
    glBindVertexArrayOES(_vertexArrayID);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    
    CVPixelBufferRef pixelBuffer = [self.videoPlayerController retrievePixelBufferToDraw];
    
    CVReturn err;
    if (pixelBuffer != NULL) {
        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        if (!_videoTextureCache) {
            NSLog(@"No video texture cache");
            return;
        }
        
        [self cleanUpTextures];
        
        // Y-plane
        glActiveTexture(GL_TEXTURE0);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RED_EXT,
                                                           frameWidth,
                                                           frameHeight,
                                                           GL_RED_EXT,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_lumaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // UV-plane.
        glActiveTexture(GL_TEXTURE1);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RG_EXT,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_RG_EXT,
                                                           GL_UNSIGNED_BYTE,
                                                           1,
                                                           &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        CFRelease(pixelBuffer);
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glDrawElements ( GL_TRIANGLES, _numIndices,
                        GL_UNSIGNED_SHORT, 0 );
    }
}

#pragma mark - OpenGL Program

- (void)buildProgram {
    _program = [[GLProgram alloc]
                initWithVertexShaderFilename:@"Shader"
                fragmentShaderFilename:@"Shader"];
    
    [_program addAttribute:@"position"];
    [_program addAttribute:@"texCoord"];
    
    if (![_program link]) {
        NSString *programLog = [_program programLog];
        NSLog(@"Program link log: %@", programLog);
        NSString *fragmentLog = [_program fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragmentLog);
        NSString *vertexLog = [_program vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertexLog);
        _program = nil;
        NSAssert(NO, @"Falied to link HalfSpherical shaders");
    }
    
    _vertexTexCoordAttributeIndex = [_program attributeIndex:@"texCoord"];
    
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = [_program uniformIndex:@"modelViewProjectionMatrix"];
    uniforms[UNIFORM_Y] = [_program uniformIndex:@"SamplerY"];
    uniforms[UNIFORM_UV] = [_program uniformIndex:@"SamplerUV"];
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = [_program uniformIndex:@"colorConversionMatrix"];
}

#pragma mark - touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if(_isUsingMotion) return;
    for (UITouch *touch in touches) {
        [_currentTouches addObject:touch];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if(_isUsingMotion) return;
    UITouch *touch = [touches anyObject];
    float distX = [touch locationInView:touch.view].x -
    [touch previousLocationInView:touch.view].x;
    float distY = [touch locationInView:touch.view].y -
    [touch previousLocationInView:touch.view].y;
    distX *= -0.005;
    distY *= -0.005;
    _fingerRotationX += distY *  _overture / 100;
    _fingerRotationY -= distX *  _overture / 100;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_isUsingMotion) return;
    for (UITouch *touch in touches) {
        [_currentTouches removeObject:touch];
    }
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        [_currentTouches removeObject:touch];
    }
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer {
    _overture /= recognizer.scale;
    
    if (_overture > MAX_OVERTURE)
        _overture = MAX_OVERTURE;
    if(_overture<MIN_OVERTURE)
        _overture = MIN_OVERTURE;
}

- (void)handleSingleTapGesture:(UITapGestureRecognizer *)recognizer {
    [_videoPlayerController toggleControls];
}

- getCurrentLayout {
    return _layoutName[currentLayout];
}

- (void) nextLayout {
    currentLayout = (currentLayout >= NUM_LAYOUTS - 1) ? 0 : (currentLayout + 1);
}

@end
