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
const NSString* serverAddress = @"http://manhattan-1.dyn.cs.washington.edu:8080/hello";

@interface PBRViewController()
@property (strong, nonatomic) AVCaptureVideoPreviewLayer* recordView;
@property (strong, nonatomic) AVPlayerLayer* playView;

@property (strong, nonatomic) PBRAVPacketizer* packetizer;
@property (strong, nonatomic) PBRAVPlayer* player;
@property (strong, nonatomic) PBRNetworkManager* network;

- (void) didRotate:(NSNotification *)notification;
- (void) recordMode;
- (void) playMode;

@end

@implementation PBRViewController
@synthesize activityIndicator = _activityIndicator;
@synthesize localView = _localView;
@synthesize remoteView = _remoteView;

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
  [self setLocalView:nil];
  [self setRemoteView:nil];
  [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(networkChange) 
                                                 name:@"PBRRemoteConnected" 
                                               object:self.network];

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
  [self didRotate:nil];
  [super viewDidAppear:animated];
  [self.activityIndicator startAnimating];
  if ([self.network.destinations count] == 0) {
    [self performSegueWithIdentifier:@"ConnectDialog" sender:self];
  }

  if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    // Pre-start record mode to give local preview time to initialize.
  //  [self recordMode];
  }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([[segue identifier] isEqualToString:@"ConnectDialog"]) {
    [segue.destinationViewController setNetwork:self.network];
  }
}

- (void)recordMode
{
  AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:nil];
  AVCaptureDeviceInput *newAudioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self microphone] error:nil];
  AVCaptureSession *newCaptureSession = [[AVCaptureSession alloc] init];
  //newCaptureSession.sessionPreset = AVCaptureSessionPresetMedium;
  if ([newCaptureSession canAddInput:newVideoInput]) {
    [newCaptureSession addInput:newVideoInput];
  }
  if ([newCaptureSession canAddInput:newAudioInput]) {
  //  [newCaptureSession addInput:newAudioInput];
  }
  
  // The local preview view.
  self.recordView = [AVCaptureVideoPreviewLayer layerWithSession:newCaptureSession];
  
  [self.packetizer recordFromSession:newCaptureSession];
  
  self.recordView.frame = self.localView.bounds;
  
  [self.recordView setVideoGravity:AVLayerVideoGravityResizeAspect];
  if([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeRight) {
    [self.recordView setOrientation:AVCaptureVideoOrientationLandscapeLeft];    
  } else {
    [self.recordView setOrientation:AVCaptureVideoOrientationLandscapeRight];
  }
  
  [self.localView.layer addSublayer:self.recordView];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [newCaptureSession startRunning];
    [self.packetizer setActive:YES];  
  });
}

- (void)playMode
{
  AVQueuePlayer* player = [AVQueuePlayer queuePlayerWithItems:[NSArray array]];
  

  // Connect to the player.
  [self.player playTo:player];
  self.playView = [[AVPlayerLayer alloc] init];
  [self.playView setPlayer:player];
  [self.playView setFrame:[self.remoteView bounds]];
  [self.playView setVideoGravity:AVLayerVideoGravityResizeAspect];
  CALayer *viewLayer = [self.remoteView layer];
  [viewLayer setMasksToBounds:YES];
  [viewLayer insertSublayer:self.playView below:[[viewLayer sublayers] objectAtIndex:0]];
  [player play];
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

- (IBAction)toggleActive:(UISwitch *)sender {
  [self.packetizer setActive:[sender isOn]];
}

- (IBAction)toggleMode:(UISwitch *)sender {
  if ([sender isOn]) {
    [self recordMode];
  } else {
    [self playMode];
  }
  [self.network setMode:[sender isOn]];
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
      _network = [[PBRNetworkManager alloc] initWithServer:[NSURL URLWithString:(NSString*)serverAddress]];
  }
  return _network;
}

- (void) networkChange
{
  NSLog(@"Starting: Beginning Capture");
  if (!self.recordView) {
    [self recordMode];
  }
  [self playMode];
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
