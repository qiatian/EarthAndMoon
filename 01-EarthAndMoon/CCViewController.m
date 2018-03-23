//
//  CCViewController.m
//  01-EarthAndMoon
//
//  Created by CC老师 on 2018/1/17.
//  Copyright © 2018年 CC老师. All rights reserved.
//

#import "CCViewController.h"
#import "AGLKVertexAttribArrayBuffer.h"
#import "sphere.h"

//场景地球轴倾斜度
static const GLfloat SceneEarthAxialTiltDeg = 23.5f;
//月球轨道日数
static const GLfloat SceneDaysPerMoonOrbit = 28.0f;
//半径
static const GLfloat SceneMoonRadiusFractionOfEarth = 0.25;
//月球距离地球的距离
static const GLfloat SceneMoonDistanceFromEarth = 2.0f;



@interface CCViewController ()
//上下文
@property(nonatomic,strong)EAGLContext *mContext;

//顶点positionBuffer 顶点
@property(nonatomic,strong)AGLKVertexAttribArrayBuffer *vertexPositionBuffer;

//顶点NormalBuffer 法线
@property(nonatomic,strong)AGLKVertexAttribArrayBuffer *vertexNormalBuffer;

//顶点TextureCoordBuffer 纹理
@property(nonatomic,strong)AGLKVertexAttribArrayBuffer *vertextTextureCoordBuffer;

//光照、纹理 不用GLSL时候用GLKBaseEffect
@property(nonatomic,strong)GLKBaseEffect *baseEffect;

//不可变纹理对象数据,地球纹理对象
@property(nonatomic,strong)GLKTextureInfo *earchTextureInfo;

//月亮纹理对象
@property(nonatomic,strong)GLKTextureInfo *moomTextureInfo;

//模型视图矩阵
//GLKMatrixStackRef CFType 允许一个4*4 矩阵堆栈
@property(nonatomic,assign)GLKMatrixStackRef modelViewMatrixStack;

//地球的旋转角度
@property(nonatomic,assign)GLfloat earthRotationAngleDegress;
//月亮旋转的角度
@property(nonatomic,assign)GLfloat moonRotationAngleDegress;


@end

@implementation CCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //1.新建OpenGLES上下文
    self.mContext = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    //获取GLKView
    GLKView *view = (GLKView *)self.view;
    view.context = self.mContext;
    //存储颜色格式
    view.drawableColorFormat = GLKViewDrawableColorFormatSRGBA8888;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [EAGLContext setCurrentContext:self.mContext];
    
    //深度测试开启
    glEnable(GL_DEPTH_TEST);
    
    //创建GLKBaseEffect，3个光照，2个纹理
    self.baseEffect = [[GLKBaseEffect alloc]init];
    //配置光照信息
    [self configureLight];
    
    //投影方式 纵横比 w/h
    GLfloat aspectRatio = self.view.bounds.size.width/self.view.bounds.size.height;
    //设置投影方式 GLSL方式设置投影步骤：1.创建4*4矩阵 2.GLKMatrixMakeOrtho() 3.通过uniform方式传递顶点着色器处理 4.让图元的每一个顶点都能配合投影处理
    self.baseEffect.transform.projectionMatrix = GLKMatrix4MakeOrtho(-1.0f*aspectRatio, 1.0 *aspectRatio, -1.0f, 1.0f, 1.0f, 120.0f);
    
    //模型视图变换 往屏幕里面移动5个像素点
    self.baseEffect.transform.modelviewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -5.0f);
   
    //设置背景颜色
    GLKVector4 colorVector = GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f);
    [self setClearColor:colorVector];
    
    //处理顶点数据
    [self bufferData];
}

-(void)bufferData
{
    //创建空矩阵
    self.modelViewMatrixStack = GLKMatrixStackCreate(kCFAllocatorDefault);
    
    //为将要缓存的数据开辟空间 参数1数据大小，3个GLFloat,xyz 参数2有多少个数据，count 参数3数据来源 参数4用途
    //顶点数据
    self.vertexPositionBuffer = [[AGLKVertexAttribArrayBuffer alloc]initWithAttribStride:3*sizeof(GLfloat) numberOfVertices:sizeof(sphereVerts)/(3*sizeof(GLfloat)) bytes:sphereVerts usage:GL_STATIC_DRAW];
    //光照数据
    self.vertexNormalBuffer = [[AGLKVertexAttribArrayBuffer alloc]initWithAttribStride:3*sizeof(GLfloat) numberOfVertices:sizeof(sphereNormals)/(3*sizeof(GLfloat)) bytes:sphereNormals usage:GL_STATIC_DRAW];
    //纹理数据
    self.vertextTextureCoordBuffer = [[AGLKVertexAttribArrayBuffer alloc]initWithAttribStride:3*sizeof(GLfloat) numberOfVertices:sizeof(sphereTexCoords)/(3*sizeof(GLfloat)) bytes:sphereTexCoords usage:GL_STATIC_DRAW];
    
    //处理纹理
    //获取地球纹理图片
    CGImageRef earthImageRef = [UIImage imageNamed:@"Earth512x256.jpg"].CGImage;
    //控制纹理的加载方式
    NSDictionary *earthOptions = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],GLKTextureLoaderOriginBottomLeft, nil];
    //加载的纹理资源图片 参数1加载纹理图片资源 参数2加载方式字典 参数3错误信息
    self.earchTextureInfo = [GLKTextureLoader textureWithCGImage:earthImageRef options:earthOptions error:nil];
    
    //获取月球图片
    CGImageRef moonImg = [UIImage imageNamed:@"Moon256x128"].CGImage;
    //控制图片的加载方式
    NSDictionary *moonOptions = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],GLKTextureLoaderOriginBottomLeft, nil];
    self.moomTextureInfo = [GLKTextureLoader textureWithCGImage:moonImg options:moonOptions error:nil];
    
    //用矩阵堆栈压栈  将模型视图变换的矩阵加载到modelViewMatrixStack
    GLKMatrixStackLoadMatrix4(self.modelViewMatrixStack, self.baseEffect.transform.modelviewMatrix);
    //确定月球的位置 初始化在轨道上的位置
    self.moonRotationAngleDegress = -20.0f;

}

-(void)setClearColor:(GLKVector4)clearColorRGBA
{
    glClearColor(clearColorRGBA.r, clearColorRGBA.g, clearColorRGBA.b, clearColorRGBA.a);
}

-(void)configureLight
{
    //是否开启光照
    self.baseEffect.light0.enabled = GL_TRUE;
    //union共用体
    //设置漫反射颜色
    self.baseEffect.light0.diffuseColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 1.0f);
    //世界坐标中的光的位置
    //w=0.0式，则使用定向光公式计算光，向量X，Y，Z分量来指定光的方向。光被认为是无限远的，光被认为是无限远的，衰减、聚光灯的属性会被忽略；
    //w!=0时，指定坐标的光在其次坐标的位置和光是一个点光源和聚光灯计算
    self.baseEffect.light0.position = GLKVector4Make(1.0f, 0.0f, 0.8f, 0.0f);
    //光的环境的颜色
    self.baseEffect.light0.ambientColor = GLKVector4Make(0.2f, 0.2f, 0.2f, 1.0f);
  
}

#pragma mark - drawRect 代理方法
//渲染场景
-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    //设置清屏颜色
    glClearColor(0.3f, 0.3f, 0.3f, 1.0f);
    
    //清除缓冲区
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    //计数地球的旋转角度
    _earthRotationAngleDegress += 360.0f/60.0f;
    
    //计算月亮的旋转角度
    _moonRotationAngleDegress +=(360.0f/60.0f)/SceneDaysPerMoonOrbit;
    
    
    //准备绘制 参数1:数据用途 参数2数据读取个数 参数3数据读取索引 参数4能否调用glEnableVertexAttribArray:着色器能否读取到数据，是否启用了对应的属性决定，允许顶点着色器去读取GPU里面的数据
    [self .vertexPositionBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition numberOfCoordinates:3 attribOffset:0 shouldEnable:YES];
    
    [self .vertexNormalBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition numberOfCoordinates:3 attribOffset:0 shouldEnable:YES];
    
    [self .vertextTextureCoordBuffer prepareToDrawWithAttrib:GLKVertexAttribPosition numberOfCoordinates:3 attribOffset:0 shouldEnable:YES];
    
    //开始绘制
    [self drawEarth];
    [self drawMoon];
    
    
    

}


-(void)drawEarth
{
    //获取纹理的name和target
    self.baseEffect.texture2d0.name = self.earchTextureInfo.name;
    self.baseEffect.texture2d0.target = self.earchTextureInfo.target;
    
    //将当前的压栈
    GLKMatrixStackPush(self.modelViewMatrixStack);
    //在指定的轴上旋转，变换最上面的矩阵 围绕x 轴旋转
    GLKMatrixStackRotate(self.modelViewMatrixStack, GLKMathDegreesToRadians(SceneEarthAxialTiltDeg), 1.0f, 0.0f, 0.0f);
    
    //
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelViewMatrixStack);
    
    //准备绘制
    [self.baseEffect prepareToDraw];
    
    //调用AGL
    [AGLKVertexAttribArrayBuffer drawPreparedArraysWithMode:GL_TRIANGLES startVertexIndex:0 numberOfVertices:sphereNumVerts];
    
    //出栈
    GLKMatrixStackPop(self.modelViewMatrixStack);
    
    //
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelViewMatrixStack);
}

-(void)drawMoon
{
  //
    self.baseEffect.texture2d0.name = self.moomTextureInfo.name;
    self.baseEffect.texture2d0.target = self.moomTextureInfo.target;
    
    //压栈
    GLKMatrixStackPush(self.modelViewMatrixStack);
    //自转 围绕Y轴
    GLKMatrixStackRotate(self.modelViewMatrixStack, GLKMathDegreesToRadians(self.moonRotationAngleDegress), 0.0f, 1.0f, 0.0f);
    //月亮和地球存在距离
    //平移
    GLKMatrixStackTranslate(self.modelViewMatrixStack, 0.0f, 0.0f, SceneMoonDistanceFromEarth);
    
    //月亮比地球小
    //缩放
    GLKMatrixStackScale(self.modelViewMatrixStack, SceneMoonRadiusFractionOfEarth, SceneMoonRadiusFractionOfEarth, SceneMoonRadiusFractionOfEarth);
    
    //围绕地球转
    GLKMatrixStackRotate(self.modelViewMatrixStack, GLKMathDegreesToRadians(self.moonRotationAngleDegress), 0.0f, 1.0f, 0.0f);
    
    //
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelViewMatrixStack);
    
    //准备绘制
    [self.baseEffect prepareToDraw];
    //开始绘制
    [AGLKVertexAttribArrayBuffer drawPreparedArraysWithMode:GL_TRIANGLES startVertexIndex:0 numberOfVertices:sphereNumVerts];
    
    GLKMatrixStackPop(self.modelViewMatrixStack);
    
    self.baseEffect.transform.modelviewMatrix = GLKMatrixStackGetMatrix4(self.modelViewMatrixStack);
    
    
}


#pragma mark -Switch Click
//切换正投影效果或透视投影效果
- (IBAction)switchClick:(UISwitch *)sender {
    
    //纵横比
    GLfloat aspect = self.view.bounds.size.width / self.view.bounds.size.height;
    if ([sender isOn]) {
        self.baseEffect.transform.projectionMatrix = GLKMatrix4MakeOrtho(-1.0f * aspect,1.0*aspect, -1.0 , 1.0, 2.0, 120.f);
    }else{
        self.baseEffect.transform.projectionMatrix = GLKMatrix4MakeFrustum(-1.0f * aspect,1.0*aspect, -1.0 , 1.0, 2.0, 120.f);
    }
}

//横屏处理
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    
    return (toInterfaceOrientation !=
            UIInterfaceOrientationPortraitUpsideDown &&
            toInterfaceOrientation !=
            UIInterfaceOrientationPortrait);
    
}

@end
