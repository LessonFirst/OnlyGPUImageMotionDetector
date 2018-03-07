//
//  ViewController.m
//  OnlyGPUImageMotionDetector
//
//  Created by only on 2018/3/7.
//  Copyright © 2018年 only. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"
#define kScreenHeight        [UIScreen mainScreen].bounds.size.height
#define kScreenWidth         [UIScreen mainScreen].bounds.size.width

// 灵敏度  值越小 越灵敏
static NSTimeInterval const kMotionDetectionSensitiveValue = 0.3;


@interface ViewController ()<GPUImageVideoCameraDelegate>
@property (strong, nonatomic) GPUImageVideoCamera *videoCamera;
@property (strong, nonatomic) GPUImageView *gpuImageView;
@property (strong, nonatomic) GPUImageOpacityFilter *beautifyFilter;
@property (strong, nonatomic) GPUImageRawDataOutput *dataHandler;
@property (strong, nonatomic) GPUImageMotionDetector *motionDetector;







@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self creatGPUImageVideoCamera];
}

- (void)creatGPUImageVideoCamera{
    //摄像头初始化
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionBack];
    //开启捕获声音
    [_videoCamera addAudioInputsAndOutputs];
    //设置输出图像方向，可用于横屏推流。
    _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    //镜像策略，这里这样设置是最自然的。跟系统相机默认一样。
    _videoCamera.horizontallyMirrorRearFacingCamera = NO;
    _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    //设置预览view
    _gpuImageView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
    [self.view addSubview:_gpuImageView];
    //初始化美颜滤镜
    _beautifyFilter = [[GPUImageOpacityFilter alloc] init];
    //相机获取视频数据输出至美颜滤镜
    [_videoCamera addTarget:_beautifyFilter];
    //美颜后输出至预览
    [_beautifyFilter addTarget:_gpuImageView];
    
    // 运动检测的类
    _motionDetector = [[GPUImageMotionDetector alloc]init];
    [_beautifyFilter addTarget:_motionDetector];
    
    _motionDetector.motionDetectionBlock = ^(CGPoint motionCentroid, CGFloat motionIntensity, CMTime frameTime) {
        
        if (motionCentroid.x > kMotionDetectionSensitiveValue ||  motionCentroid.y > kMotionDetectionSensitiveValue){
            NSLog(@"有人经过了");
        }
        
    };
    
    
    _dataHandler = [[GPUImageRawDataOutput alloc]initWithImageSize:CGSizeMake(kScreenWidth, kScreenHeight) resultsInBGRAFormat:YES];
    [_beautifyFilter addTarget:_dataHandler];
    
    //    _videoCamera.delegate = _dataHandler;
    
    //开始捕获视频
    [self.videoCamera startCameraCapture];
    
    //修改帧率
    //    [self updateFps:AVCaptureSessionPreset640x480.fps];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

