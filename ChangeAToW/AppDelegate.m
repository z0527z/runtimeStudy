//
//  AppDelegate.m
//  ChangeAToW
//
//  Created by jolin.ding on 2019/12/24.
//  Copyright © 2019 jolin.ding. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.window setBackgroundColor:[UIColor whiteColor]];
    
    ViewController * VC = [[ViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:VC];
    [self.window setRootViewController:nav];
    [self.window makeKeyAndVisible];
    
    return YES;
}





@end
