//
//  PBRViewController.m
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRViewController.h"
#import "ADTSEncoder.h"

@interface PBRViewController()
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* localVideo;
@property (strong, nonatomic) TSSocket* sink;
@property (strong, nonatomic) ADTSEncoder* audioWriter;

- (void) didRotate:(NSNotification *)notification;

@end

@implementation PBRViewController
@synthesize activityIndicator = _activityIndicator;
@synthesize preview = _preview;

@synthesize localVideo = _localVideo;
@synthesize sink = _sink;
@synthesize audioWriter = _audioWriter;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [self setActivityIndicator:nil];
  [self setPreview:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotate:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (AVCaptureDevice *) frontFacingCamera
{
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (AVCaptureDevice *device in devices) {
    if ([device position] == AVCaptureDevicePositionFront) {
      return device;
    }
  }
  return nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.activityIndicator startAnimating];

  AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:nil];
  AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];
  if ([newCaptureSession canAddInput:newVideoInput]) {
    [newCaptureSession addInput:newVideoInput];
  }
  
  // The export to network setup.
  if (!self.audioWriter) {
    self.audioWriter = [[ADTSEncoder alloc] initWithSink:self.sink];
  }
  
  // The local preview view.
  self.localVideo = [[AVCaptureVideoPreviewLayer alloc] initWithSession:newCaptureSession];
  CALayer *viewLayer = [self.preview layer];
  [viewLayer setMasksToBounds:YES];
  
  [self didRotate:nil];
  [self.localVideo setFrame:[self.preview bounds]];
  
  [self.localVideo setVideoGravity:AVLayerVideoGravityResizeAspect];
  
  [viewLayer insertSublayer:self.localVideo below:[[viewLayer sublayers] objectAtIndex:0]];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [newCaptureSession startRunning];
  });
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:UIDeviceOrientationDidChangeNotification
                                                object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
  [self.activityIndicator stopAnimating];
}

- (IBAction)toggle:(UISwitch *)sender {
  if([sender isOn]) {
    [self.sink connect];
  } else {
    [self.sink disconnect];
  }
}

- (TSSocket*) sink
{
  if (!_sink) {
    _sink = [[TSSocket alloc] init];
  }
  return _sink;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return !UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

- (void) didRotate:(NSNotification *)notification {
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
  if (orientation == UIDeviceOrientationLandscapeLeft) {
    [self.localVideo setOrientation:AVCaptureVideoOrientationLandscapeRight];
  } else if (orientation == UIDeviceOrientationLandscapeRight) {
    [self.localVideo setOrientation:AVCaptureVideoOrientationLandscapeLeft];
  }
}

@end
