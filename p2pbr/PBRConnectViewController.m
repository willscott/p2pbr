//
//  PBRConnectViewController.m
//  p2pbr
//
//  Created by willscott@gmail.com on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PBRConnectViewController.h"

@interface PBRConnectViewController ()

- (void) networkChange;

@end

@implementation PBRConnectViewController

@synthesize network = _network;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
  UITableViewCell* ip = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
  ip.detailTextLabel.text = [self.network receiveAddress];
  [ip layoutSubviews];

  UITableViewCell* port = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
  port.detailTextLabel.text = [NSString stringWithFormat:@"%d", [self.network.receiveSocket localPort]];
  [port layoutSubviews];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange) name:@"PBRRemoteConnected" object:self.network];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PBRRemoteConnected" object:self.network];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0 || section == 1) {
    return 2;
  }
  return 1;
}



// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return [indexPath section] == 1;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
  return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath 
{
  return UITableViewCellEditingStyleNone;
}

#pragma mark - Text field delegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
  if ([textField.placeholder isEqualToString:@"IP"]) {
    // Switch to Port.
    UITableViewCell* port = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
    [[port.contentView.subviews lastObject] becomeFirstResponder];
    return YES;
  } else {
    [self commitState];
  }
  return NO;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 2) {
    [self commitState];
  }
}

- (void) commitState
{
  UITableViewCell* portCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
  NSString* portString = [[portCell.contentView.subviews lastObject] text];

  UITableViewCell* ipCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
  NSString* ipString = [[ipCell.contentView.subviews lastObject] text];

  [self.network connectTo:ipString onPort:[portString integerValue]];
}

- (void) networkChange
{
  [self setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
  [self performSelectorOnMainThread:@selector(hide) withObject:nil waitUntilDone:NO];
}
- (void) hide
{
  [self dismissModalViewControllerAnimated:YES];
}

@end
