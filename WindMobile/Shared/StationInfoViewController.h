//
//  StationInfoViewController.h
//  WindMobile
//
//  Created by Stefan Hochuli Paychère on 14.05.10.
//  Copyright 2010 Pistache Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WMReSTClient.h"
#import "IASKAppSettingsViewController.h"

@interface StationInfoViewController : UITableViewController<WMReSTClientDelegate> {
	WMReSTClient* client;
	NSArray *stations;
}
@property (retain)NSArray *stations;

// Content
- (void)refreshContent:(id)sender;
// WMReSTClient delegate
- (void)stationList:(NSArray*)stations;
- (void)requestError:(NSString*) message details:(NSMutableDictionary *)error;

@end

@interface StationInfoViewController ()
- (void)startRefreshAnimation;
- (void)stopRefreshAnimation;
@end