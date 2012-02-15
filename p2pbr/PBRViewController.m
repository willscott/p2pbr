//
//  CSEViewController.m
//  ChatClient
//
//  Created by willscott@gmail.com on 1/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRViewController.h"
#include "PBRAVPacketizer.h"
#import "PBRAVPlayer.h"
#import "PBRNetworkManager.h"

//const NSString* serverAddress = @"http://www.quimian.com/p2pbr.txt";
const NSString* serverAddress = @"http://manhattan-1.dyn.cs.washington.edu:8080/";

@interface PBRViewController()
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* recordView;
@property (strong, nonatomic) MPMoviePlayerController* playView;

@property (strong, nonatomic) PBRAVPacketizer* packetizer;
@property (strong, nonatomic) PBRAVPlayer* player;
@property (strong, nonatomic) PBRNetworkManager* network;

- (void) didRotate:(NSNotification *)notification;
- (void) recordMode;
- (void) playMode;

@end

@implementation PBRViewController
@synthesize activityIndicator = _activityIndicator;
@synthesize preview = _preview;
@synthesize clientMode = _clientMode;

@synthesize recordView = _recordView;
@synthesize playView = _playView;
@synthesize packetizer = _packetizer;
@synthesize player = _player;
@synthesize network = _network;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
  [self setActivityIndicator:nil];
  [self setPreview:nil];
  [self setClientMode:nil];
  [super viewDidUnload];
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

- (AVCaptureDevice *) microphone
{
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
  for (AVCaptureDevice *device in devices) {
    if ([device isConnected]) {
      return device;
    }
  }
  return nil;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self.activityIndicator startAnimating];
  
}

- (void)recordMode
{
  AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:nil];
  AVCaptureDeviceInput *newAudioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self microphone] error:nil];
  AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];
  if ([newCaptureSession canAddInput:newVideoInput]) {
    [newCaptureSession addInput:newVideoInput];
  }
  if ([newCaptureSession canAddInput:newAudioInput]) {
    [newCaptureSession addInput:newAudioInput];
  }
  
  // The local preview view.
  self.recordView = [[AVCaptureVideoPreviewLayer alloc] initWithSession:newCaptureSession];
  CALayer *viewLayer = [self.preview layer];
  [viewLayer setMasksToBounds:YES];
  
  // Connect to packetizer.
  AVCaptureMovieFileOutput* output = [[AVCaptureMovieFileOutput alloc] init];
  [output setMovieFragmentInterval:CMTimeMakeWithSeconds(1, 10)]; //.1 sec
  [output setMaxRecordedDuration:CMTimeMakeWithSeconds(1, 2)]; //.5 sec
  AVMutableMetadataItem* title = [[AVMutableMetadataItem alloc] init];
  [title setKeySpace:AVMetadataKeySpaceCommon];
  [title setKey:AVMetadataCommonKeyTitle];
  [title setValue:@"p2pbr"];
  [output setMetadata:[NSArray arrayWithObject:title]];
  [newCaptureSession addOutput:output];
  [self.packetizer recordFrom:output];
  
  [self didRotate:nil];
  [self.recordView setFrame:[self.preview bounds]];
  
  [self.recordView setVideoGravity:AVLayerVideoGravityResizeAspect];
  
  [viewLayer insertSublayer:self.recordView below:[[viewLayer sublayers] objectAtIndex:0]];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [newCaptureSession startRunning];
  });
}

- (void)playMode
{
  self.playView = [[MPMoviePlayerController alloc] init];
  [self.playView setControlStyle:MPMovieControlModeVolumeOnly];

  // Connect to the player.
  [self.player playTo:self.playView];
  
  [self.preview addSubview:[self.playView view]];
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
    
    PBRNetworkManager* net = [self network];  
    
    if ([net.destinations count] > 0) {
        [self recordMode];
    } else {
        [self playMode];
    }
  if([sender isOn]) {
    [self.packetizer setActive:YES];
  } else {
    [self.packetizer setActive:NO];
  }
}

- (PBRAVPacketizer*) packetizer
{
  if (!_packetizer) {
    _packetizer = [[PBRAVPacketizer alloc] init];
    [_packetizer setSocket:self.network];
  }
  return _packetizer;
}

- (PBRAVPlayer*) player
{
  if (!_player) {
    _player = [[PBRAVPlayer alloc] init];
    [_player setSocket:self.network];
  }
  return _player;
}

- (PBRNetworkManager*) network
{
  if (!_network) {
      _network = [[PBRNetworkManager alloc] initWithServer:[NSURL URLWithString:(NSString*)serverAddress]mode:[self.clientMode isOn]];
  }
  return _network;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return !UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

- (void) didRotate:(NSNotification *)notification {
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
  if (orientation == UIDeviceOrientationLandscapeLeft) {
    [self.recordView setOrientation:AVCaptureVideoOrientationLandscapeRight];
  } else if (orientation == UIDeviceOrientationLandscapeRight) {
    [self.recordView setOrientation:AVCaptureVideoOrientationLandscapeLeft];
  }
}

@end
