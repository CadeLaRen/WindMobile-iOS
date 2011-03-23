//
//  WindPlotController.h
//  WindMobile
//
//  Created by Stefan Hochuli Paychère on 29.01.11.
//  Copyright 2011 Pistache Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CorePlot-CocoaTouch.h"
#import "WMReSTClient.h"
#import "StationInfo.h"


@interface WindPlotController : UIViewController <CPPlotDataSource, WMReSTClientDelegate> {
	WMReSTClient* client;
	
	CPXYGraph *graph;
	CPGraphHostingView *hostingView;
	
	StationInfo *stationInfo;
	StationGraphData *stationGraphData;
	
	CPXYAxisSet *axisSet;
	
	NSString *duration;
	UISegmentedControl *scale;
	UIButton *info;
	UIActivityIndicatorView *activityIndicator;
}
@property(readwrite, retain) IBOutlet CPGraphHostingView* hostingView;
@property(readwrite, retain) StationInfo* stationInfo;
@property(readwrite, retain) StationGraphData* stationGraphData;
@property(readwrite, retain) NSString* duration;
@property(readwrite, retain) IBOutlet UISegmentedControl *scale;
@property(readwrite, retain) IBOutlet UIButton *info;
@property(readwrite, retain) IBOutlet UIActivityIndicatorView *activityIndicator;

- (void)refreshContent:(id)sender;
- (IBAction)setInterval:(id)sender;
- (IBAction)showScale:(id)sender;
- (NSUInteger)numberOfRecordsForPlot:(CPPlot *)plot;
@end

@interface WindPlotController ()
- (void)startRefreshAnimation;
- (void)stopRefreshAnimation;
- (void)setupButtons;
@end
