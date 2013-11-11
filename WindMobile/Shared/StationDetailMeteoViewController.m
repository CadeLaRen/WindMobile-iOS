//
//  StationDetailMeteoViewController.m
//  WindMobile
//
//  Created by Stefan Hochuli Paychère on 15.02.11.
//  Copyright 2011 Pistache Software. All rights reserved.
//

#import "StationDetailMeteoViewController.h"
#import "StationInfo.h"
#import "StationData.h"
#import "WindMobileHelper.h"
#import "iPadHelper.h"
#import "WindTrendChartViewController.h"
#import "WindPlotController.h"
#import "AppDelegate_Phone.h"
#import "StationInfoMapViewController.h"

#define DegreeToRadian(x) ((x) * M_PI / 180.0f)

@implementation StationDetailMeteoViewController
@synthesize stationInfo;
@synthesize stationData;
@synthesize lastUpdated;
@synthesize altitude;
@synthesize windAverage;
@synthesize windMax;
@synthesize windDirectionArrow;
@synthesize windHistoryMin;
@synthesize windHistoryAverage;
@synthesize windHistoryMax;
@synthesize airTemperature;
@synthesize airHumidity;
@synthesize windTrendContainer;
@synthesize windTrendCtrl;
@synthesize windPlotView;
@synthesize windPlotController;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Fix for iOS 7: http://stackoverflow.com/questions/18775874/ios-7-status-bar-overlaps-the-view
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    // Update main info
    self.title = stationInfo.name;
    self.altitude.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"ALTITUDE_FORMAT", 
                                                                               @"WindMobile", nil),
                          self.stationInfo.altitude];
    
    // Invalidate all values
    NSString* NA = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    self.lastUpdated.text = NA;
    self.windAverage.text = NA;
    self.windMax.text = NA;
    self.windHistoryMin.text = NA;
    self.windHistoryMax.text = NA;
    self.windHistoryAverage.text = NA;
    self.airTemperature.text = NA;
    self.airHumidity.text = NA;
    
    // Insert wind trend chart
    windTrendCtrl = [[WindTrendChartViewController alloc] initWithNibName:@"WindTrendChartViewController" bundle:nil];
    //windTrend.view.bounds = self.windTrendContainer.frame;
    windTrendCtrl.view.frame = self.windTrendContainer.bounds;
    [self.windTrendContainer addSubview:windTrendCtrl.view];
    
    // Set size when in popover
    self.contentSizeForViewInPopover = CGSizeMake(320, 380);
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    if ([iPadHelper isPresentedModally:self]) {
        // we are presented modaly: add a dismiss button
        self.navigationItem.rightBarButtonItem = nil;
        UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                    target:self 
                                                                                    action:@selector(dismissModalViewControllerAnimated:)];
        self.navigationItem.rightBarButtonItem = buttonItem;
        [buttonItem release];
    }
    
    // If we appear horizontally display the graph on iPhone
    if ([iPadHelper isIpad] == NO) {
        switch (self.interfaceOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
            case UIInterfaceOrientationLandscapeRight:
                if (self.windPlotController == nil) {
                    self.windPlotController = [[WindPlotController alloc] initWithNibName:@"WindPlotController" bundle:nil];
                    self.windPlotController.stationInfo = self.stationInfo;
                    self.windPlotController.masterController = self;
                    
                    // Display plot view
                    self.windPlotController.view.frame = self.view.bounds;
                    self.windPlotView = windPlotController.view; // Save for future reference
                    [self.view addSubview:self.windPlotView];
                }
                break;
            case UIInterfaceOrientationPortrait:
            case UIInterfaceOrientationPortraitUpsideDown:
                [self.windPlotView removeFromSuperview];
                self.windPlotController = nil;
                break;
        }
    }
    
    // Refresh content now and every time the view becomes active to refreh the last update time
    [self refreshContent:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshContent:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    // Prepare for rotation
    if ([iPadHelper isIpad] == NO) {
        switch(toInterfaceOrientation){
            case UIInterfaceOrientationLandscapeLeft:
            case UIInterfaceOrientationLandscapeRight:
                if (self.windPlotController == nil) {
                    self.windPlotController = [[WindPlotController alloc] initWithNibName:@"WindPlotController" bundle:nil];
                    self.windPlotController.stationInfo = self.stationInfo;
                    self.windPlotController.masterController = self;
                    
                    // Display plot view
                    self.windPlotController.view.frame = self.view.bounds;
                    self.windPlotView = windPlotController.view; // Save for future reference
                    [self.view addSubview:self.windPlotView];
                }
                break;
            case UIInterfaceOrientationPortrait:
            case UIInterfaceOrientationPortraitUpsideDown:
                [self.windPlotView removeFromSuperview];
                self.windPlotController = nil;
                break;
        }
    }
}

- (void)dealloc {
    [client release];

    [stationInfo release];
    [stationData release];
    
    [stationName release];
    [lastUpdated release];
    [altitude release];
    [windAverage release];
    [windMax release];
    [windDirectionArrow release];
    [windHistoryMin release];
    [windHistoryAverage release];
    [windHistoryMax release];
    [airTemperature release];
    [airHumidity release];
    
    [windTrendContainer release];
    [windTrendCtrl release];
    
    [windPlotView release];
    [windPlotController release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Station Details methods

- (IBAction)refreshContent:(id)sender {
    [self startRefreshAnimation];
    
    if(client == nil){
        client = [[WMReSTClient alloc] init ];
    }
    
    // (re-)load content
    [client asyncGetStationData:self.stationInfo.stationID forSender:self];
}

- (void)stationData:(StationData*)aStationData{
    [self stopRefreshAnimation];
    
    self.stationData = aStationData;
    windTrendCtrl.windData = aStationData.windDirection;
    
    // refresh data
    self.lastUpdated.text = self.stationData.lastUpdate;
    switch (self.stationData.statusEnum) {
        case StationDataStatusRed:
            self.lastUpdated.textColor = [UIColor redColor];
            break;
        case StationDataStatusOrange:
            self.lastUpdated.textColor = [UIColor orangeColor];
            break;
        default:
            self.lastUpdated.textColor = [UIColor whiteColor];
            break;
    }
    
    if(self.stationData.windAverage != nil){
        self.windAverage.text = self.stationData.windAverage;
    } else {
        self.windAverage.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    if(self.stationData.windMax != nil){
        self.windMax.text = self.stationData.windMax;
    } else {
        self.windMax.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    if(self.stationData.windTrend != nil){
        float direction = [self.stationData.windTrend floatValue];
        if (direction <= 0) {
            self.windDirectionArrow.image = [UIImage imageNamed:@"arrow_green"];
        } else {
            self.windDirectionArrow.image = [UIImage imageNamed:@"arrow_red"];
        }
        CGAffineTransform xform = CGAffineTransformMakeRotation(DegreeToRadian(-direction));
        self.windDirectionArrow.transform = xform;
    }
    
    if(self.stationData.windHistoryMin != nil){
        self.windHistoryMin.text = self.stationData.windHistoryMin;
    } else {
        self.windHistoryMin.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    if(self.stationData.windHistoryMax != nil){
        self.windHistoryMax.text = self.stationData.windHistoryMax;
    } else {
        self.windHistoryMax.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    if(self.stationData.windHistoryAverage != nil){
        self.windHistoryAverage.text = self.stationData.windHistoryAverage;
    } else {
        self.windHistoryAverage.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    if(self.stationData.airTemperature != nil){
        self.airTemperature.text = self.stationData.airTemperature;
    } else {
        self.airTemperature.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    if(self.stationData.airHumidity != nil){
        self.airHumidity.text = self.stationData.airHumidity;
    } else {
        self.airHumidity.text = NSLocalizedStringFromTable(@"NOT_AVAILABLE", @"WindMobile", nil);
    }
    
    
    [self.view setNeedsDisplay];
}

- (void)serverError:(NSString* )title message:(NSString *)message{
    [self stopRefreshAnimation];
    self.lastUpdated.text = title;
    self.lastUpdated.textColor = [UIColor redColor];
}

- (void)connectionError:(NSString* )title message:(NSString *)message{
    [self stopRefreshAnimation];
    [WMReSTClient showError:title message:message];
}

- (void)startRefreshAnimation{
    // Remove refresh button
    self.navigationItem.rightBarButtonItem = nil;
    
    // activity indicator
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    [activityIndicator startAnimating];
    UIBarButtonItem *activityItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
    [activityIndicator release];
    self.navigationItem.rightBarButtonItem = activityItem;
    [activityItem release];
}

- (void)stopRefreshAnimation{
    // Stop animation
    self.navigationItem.rightBarButtonItem = nil;
    
    // Graph, Done or Map button
    if([iPadHelper isIpad]){
        UIBarButtonItem *graphItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"chart"]
                                                                      style:UIBarButtonItemStylePlain 
                                                                     target:self 
                                                                     action:@selector(showGraph:)];
        self.navigationItem.rightBarButtonItem = graphItem;
        [graphItem release];
    } else { // iPhone
        if ([iPadHelper isPresentedModally:self]) {
            UIBarButtonItem *dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                        target:self 
                                                                                        action:@selector(dismissModalViewControllerAnimated:)];
            
            self.navigationItem.rightBarButtonItem = dismissButtonItem;
            [dismissButtonItem release];
        } else {
            UIBarButtonItem *mapItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"world_bar"]
                                                                          style:UIBarButtonItemStylePlain 
                                                                         target:self 
                                                                         action:@selector(showMap:)];
            self.navigationItem.rightBarButtonItem = mapItem;
            [mapItem release];
        } 
    }
}

- (IBAction)showMap:(id)sender{
    if([iPadHelper isIpad] == NO){
        static int MAP_INDEX = 1;
        
        AppDelegate_Phone *appDelegate = [[UIApplication sharedApplication]delegate];
        UITabBarController *tabBarController = appDelegate.tabBarController;
        tabBarController.selectedIndex = MAP_INDEX;
        
        UINavigationController *navController = [tabBarController.viewControllers objectAtIndex:MAP_INDEX];
        StationInfoMapViewController *mapView = (StationInfoMapViewController *)[navController visibleViewController];
        [mapView selectStation:self.stationInfo];
    }
    
}

- (IBAction)showActionSheet:(id)sender{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                             delegate:self 
                                                    cancelButtonTitle:NSLocalizedStringFromTable(@"CANCEL", @"WindMobile", nil)
                                               destructiveButtonTitle:nil 
                                                    otherButtonTitles:NSLocalizedStringFromTable(@"SHOW_IN_MAPS", @"WindMobile",nil),
                                  NSLocalizedStringFromTable(@"REFRESH", @"WindMobile",nil),
                                  nil];
    actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
    [actionSheet showFromTabBar:self.tabBarController.tabBar];
    [actionSheet release];
    
}

- (IBAction)showGraph:(id)sender {
    if (self.navigationController != nil) {
        WindPlotController* graph = [[WindPlotController alloc] initWithNibName:@"WindPlotController" bundle:nil];
        graph.stationInfo = self.stationInfo;
        
        // Resize pop over
        graph.contentSizeForViewInPopover = CGSizeMake(500, 380);
        
        // display view
        [self.navigationController pushViewController:graph animated:YES];
        [graph release];
        
        // Force navigation bar color to black 
        self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    }
}

#pragma mark -
#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            [self showMap:self];
            break;
        case 1:
            [self refreshContent:self];
            break;
        default:
            break;
    }
}

@end
