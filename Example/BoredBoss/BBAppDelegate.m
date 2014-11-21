//
//  BBAppDelegate.m
//  BoredBoss
//
//  Created by CocoaPods on 11/18/2014.
//  Copyright (c) 2014 Javier Berlana. All rights reserved.
//

#import "BBAppDelegate.h"
#import "BoredBoss.h"

@implementation BBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    [BoredBoss sharedInstanceWithClient:@"sweetbits" andApiKey:@"1c57697e7615ee662d4399a371a598ce" launchOptions:launchOptions];
    
    [[BoredBoss sharedInstance] setFlushInterval:10];
    [[BoredBoss sharedInstance] identify:@"u_123456"];
    
    [[BoredBoss sharedInstance] setUserProperty:@"username" value:@"Test user name"];
    [[BoredBoss sharedInstance] setUserProperty:@"friends" value:@(10)];
    [[BoredBoss sharedInstance] increment:@"friends" by:@(1)];
    
    [[BoredBoss sharedInstance] track:@"Test event"];
    [[BoredBoss sharedInstance] track:@"Other event" properties:@{@"Amount":@(100),@"Currency":@"EUR"}];
    [[BoredBoss sharedInstance] track:@"New values" properties:@{@"values":@[@"a",@"b",@"c",@"d"]}];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
