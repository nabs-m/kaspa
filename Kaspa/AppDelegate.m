//
//  AppDelegate.m
//  Kaspa
//
//  Created by Nabil Maadarani on 2015-01-23.
//  Copyright (c) 2015 Nabil Maadarani. All rights reserved.
//

#import "AppDelegate.h"
#import <MyoKit/MyoKit.h>

@interface AppDelegate ()
@property (nonatomic, strong) BackendData *backend;
@property bool *dataFetchSuccessful;
@property (nonatomic, strong) NSString *temperature;
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    // Instantiate the hub using the singleton accessor, and set the applicationIdentifier of our application.
    [[TLMHub sharedHub] setApplicationIdentifier:@"com.Nabil.Kaspa"];
    return YES;
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    NSLog(@"Background fetch started...");
    // Check if it's time to download briefing (15 minutes)
    NSDateFormatter *timeFormat = [[NSDateFormatter alloc] init];
    [timeFormat setDateFormat:@"HH:mm"];
    [timeFormat setTimeZone:[NSTimeZone timeZoneWithName:@"America/Montreal"]];
   
    NSDate *now = [timeFormat dateFromString:[timeFormat stringFromDate:[NSDate date]]];
    NSDate *wakeUpTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"toTime"];
    int minutes = [wakeUpTime timeIntervalSinceDate:now]/60;
    
#warning Make data fetch unsuccessful when sleeping time arrives
    if(minutes <= 30 && minutes > 0 && !self.dataFetchSuccessful) {
        //Download data set on by user
        self.backend = [[BackendData alloc] init];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        
        // Today
        if([userDefaults boolForKey:@"Today state"])
            [self getTodayData];
        
        // Weather
        if([userDefaults boolForKey:@"Weather state"])
            [self getWeatherData];
        
        // Calendar Events
        if([userDefaults boolForKey:@"Calendar Events state"])
            [self getCalendarEventsData];
    }
    completionHandler(UIBackgroundFetchResultNewData);
    NSLog(@"Background fetch completed...");
}

- (void)getTodayData {
    // Get today's date
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"ddMMMMyyyy";
    NSString *todayDate = [formatter stringFromDate:[NSDate date]];
    
    // Create today URL
    NSString *todayUrl = [NSString stringWithFormat:@"%@%@", self.backend.todayChannelUrl, todayDate];
    
    // Fetch today data
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:[NSURL URLWithString:todayUrl]
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                if (!error && httpResp.statusCode == 200) {
                    //---print out the result obtained---
                    NSString *result = [[NSString alloc] initWithBytes:[data bytes]
                                                                length:[data length]
                                                              encoding:NSUTF8StringEncoding];
                    // Save today data
                    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                    [userDefaults setObject:result forKey:@"Today data"];
                    [userDefaults synchronize];
                } else {
                    self.dataFetchSuccessful = false;
                }
            }
      ] resume
     ];
}

- (void)getWeatherData {
    // Get the user's city
//    LocationFetcher *loc = [[LocationFetcher alloc] init];
    NSString *location = @"OttawaONCanada";
    
    // Create today URL
    NSString *weatherUrl = [NSString stringWithFormat:@"%@%@", self.backend.weatherChannelUrl, location];
    
//    // Fetch weather data
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:[NSURL URLWithString:weatherUrl]
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                if (!error && httpResp.statusCode == 200) {
                    //---print out the result obtained---
                    NSString *result = [[NSString alloc] initWithBytes:[data bytes]
                                                                length:[data length]
                                                              encoding:NSUTF8StringEncoding];
                    // Save weather data
                    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                    [userDefaults setObject:result forKey:@"Weather data"];
                    [userDefaults synchronize];
                } else {
                    self.dataFetchSuccessful = false;
                }
            }
      ] resume
     ];
}

- (void)getCalendarEventsData {
    // Get event list for today
    EKEventStore *eventStore = [[EKEventStore alloc] init];
    [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        // Create the end date components
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *oneDayFromNowComponents = [[NSDateComponents alloc] init];
        oneDayFromNowComponents.day = 1;
        NSDate *oneDayFromNow = [calendar dateByAddingComponents:oneDayFromNowComponents
                                                           toDate:[NSDate date]
                                                          options:0];
        
        // Create the predicate from the event store's instance method
        NSPredicate *predicate = [eventStore predicateForEventsWithStartDate:[NSDate date]
                                                                     endDate:oneDayFromNow
                                                                   calendars:nil];
        
        // Fetch all events that match the predicate
        NSArray *events = [eventStore eventsMatchingPredicate:predicate];
        
        // Save events as strings
        NSMutableArray *eventsText = [[NSMutableArray alloc] initWithObjects:@"Let's take a look at your calendar for today.", nil];
        
        switch([events count]) {
            case 0:
                // No events
                [eventsText addObject:@"It looks like you have nothing planned for the day!"];
            case 1: {
                // 1 events
                [eventsText addObject:@"You only have the following event planned."];
                EKEvent *onlyEvent = (EKEvent *)[events objectAtIndex:0];
                
                // Set date formatter
                NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]; // Make sure it's 12-hour
                [dateFormatter setDateFormat:@"hh:mm a"];
                
                NSString *eventTime = [dateFormatter stringFromDate:onlyEvent.startDate];
                [eventsText addObject:[NSString stringWithFormat:
                                       @"%@, at %@.", onlyEvent.title, eventTime]];
            }
            default:
            {
                // 2+ events
                [eventsText addObject:@"Here are the events you have planned."];
                for(EKEvent *event in events) {
                    // Set date formatter
                    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]; // Make sure it's 12-hour
                    [dateFormatter setDateFormat:@"hh:mm a"];
                    
                    NSString *eventTime = [dateFormatter stringFromDate:event.startDate];
                    [eventsText addObject:[NSString stringWithFormat:
                                              @"%@, at %@.", event.title, eventTime]];
                }
            }
        }
        
        // Save calendar event data
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:eventsText forKey:@"Calendar Events data"];
        [userDefaults synchronize];
    }];
}

- (void)parseJSONData:(NSData *)data {
    NSError *error;
    NSDictionary *parsedJSONData =
    [NSJSONSerialization JSONObjectWithData:data
                                    options:kNilOptions
                                      error:&error];
    NSDictionary *main = [parsedJSONData objectForKey:@"main"];
    
    //---temperature in Kelvin---
    NSString *temp = [main valueForKey:@"temp"];
    
    //---convert temperature to Celcius---
    float temperature = [temp floatValue] - 273;
    
    //---get current time---
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    
    NSString *timeString = [formatter stringFromDate:date];
    
    self.temperature = [NSString stringWithFormat:
                        @"%f degrees Celsius, fetched at %@",
                        temperature, timeString];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
