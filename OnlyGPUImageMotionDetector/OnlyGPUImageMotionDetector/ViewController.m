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



@property (nonatomic, assign) BOOL faceThinking;
@property (nonatomic, strong) GPUImageUIElement *element;
@property (nonatomic, strong) UIView *elementView;
@property (nonatomic, strong) UIImageView *capImageView;
@property (nonatomic, assign) CGRect faceBounds;
@property (nonatomic, strong) CIDetector *faceDetector;
@property (nonatomic, strong) UIView *faceView;







@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self creatGPUImageVideoCamera];
    NSLog(@"12312");
}

- (void)creatGPUImageVideoCamera{
    //摄像头初始化
    _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionBack];
    //开启捕获声音
    [_videoCamera addAudioInputsAndOutputs];
    _videoCamera.delegate = self;
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
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!_faceThinking) {
        CFAllocatorRef allocator = CFAllocatorGetDefault();
        CMSampleBufferRef sbufCopyOut;
        CMSampleBufferCreateCopy(allocator,sampleBuffer,&sbufCopyOut);
        [self performSelectorInBackground:@selector(grepFacesForSampleBuffer:) withObject:CFBridgingRelease(sbufCopyOut)];
    }
}

- (void)grepFacesForSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    _faceThinking = YES;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *convertedImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge NSDictionary *)attachments];
    
    if (attachments)
        CFRelease(attachments);
    NSDictionary *imageOptions = nil;
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    int exifOrientation;
    
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT            = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT            = 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    BOOL isUsingFrontFacingCamera = FALSE;
    AVCaptureDevicePosition currentCameraPosition = [self.videoCamera cameraPosition];
    
    if (currentCameraPosition != AVCaptureDevicePositionBack)
    {
        isUsingFrontFacingCamera = TRUE;
    }
    
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    
    imageOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:exifOrientation] forKey:CIDetectorImageOrientation];
    NSArray *features = [self.faceDetector featuresInImage:convertedImage options:imageOptions];
    
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    
    [self GPUVCWillOutputFeatures:features forClap:clap andOrientation:curDeviceOrientation];
    _faceThinking = NO;
    
}

- (void)GPUVCWillOutputFeatures:(NSArray*)featureArray forClap:(CGRect)clap
                 andOrientation:(UIDeviceOrientation)curDeviceOrientation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect previewBox = self.view.frame;
        if (featureArray.count) {
            self.capImageView.hidden = NO;
        }
        else {
            self.capImageView.hidden = YES;
            //            [self.faceView removeFromSuperview];
            //            self.faceView = nil;
        }
        for ( CIFaceFeature *faceFeature in featureArray) {
            
            // find the correct position for the square layer within the previewLayer
            // the feature box originates in the bottom left of the video frame.
            // (Bottom right if mirroring is turned on)
            //Update face bounds for iOS Coordinate System
            CGRect faceRect = [faceFeature bounds];
            
            // flip preview width and height
            CGFloat temp = faceRect.size.width;
            faceRect.size.width = faceRect.size.height;
            faceRect.size.height = temp;
            temp = faceRect.origin.x;
            faceRect.origin.x = faceRect.origin.y;
            faceRect.origin.y = temp;
            // scale coordinates so they fit in the preview box, which may be scaled
            CGFloat widthScaleBy = previewBox.size.width / clap.size.height;
            CGFloat heightScaleBy = previewBox.size.height / clap.size.width;
            faceRect.size.width *= widthScaleBy;
            faceRect.size.height *= heightScaleBy;
            faceRect.origin.x *= widthScaleBy;
            faceRect.origin.y *= heightScaleBy;
            
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
            
            //mirror
            CGRect rect = CGRectMake(previewBox.size.width - faceRect.origin.x - faceRect.size.width, faceRect.origin.y, faceRect.size.width, faceRect.size.height);
            if (fabs(rect.origin.x - self.faceBounds.origin.x) > 5.0) {
                self.faceBounds = rect;
                                if (self.faceView) {
                                    [self.faceView removeFromSuperview];
                                    self.faceView =  nil;
                                }
                
                                // create a UIView using the bounds of the face
                                self.faceView = [[UIView alloc] initWithFrame:self.faceBounds];
                
                                // add a border around the newly created UIView
//                                self.faceView.layer.borderWidth = 1;
//                                self.faceView.layer.borderColor = [[UIColor redColor] CGColor];
                
                                // add the new view to create a box around the face
                
                                [self.view addSubview:self.faceView];
            }
        }
    });
    
}

#pragma mark -
#pragma mark Getter

- (CIDetector *)faceDetector {
    if (!_faceDetector) {
        NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
        _faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    }
    return _faceDetector;
}

- (UIView *)elementView {
    if (!_elementView) {
        _elementView = [[UIView alloc] initWithFrame:self.view.frame];
        _capImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 160, 160)];
        [_capImageView setImage:[UIImage imageNamed:@"cap.jpg"]];
        [_elementView addSubview:_capImageView];
    }
    return _elementView;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

