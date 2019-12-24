//
//  ViewController.m
//  ChangeAToW
//
//  Created by jolin.ding on 2019/12/24.
//  Copyright © 2019 jolin.ding. All rights reserved.
//

#import "ViewController.h"
#import "ChangeAToW.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ChangeAToW * obj = [[ChangeAToW alloc] init];
    @autoreleasepool {
        NSObject * proxy = [NSObject new];
        obj.delegate = proxy;
    }
    NSLog(@"delegate: %@", obj.delegate);
    
}


@end
