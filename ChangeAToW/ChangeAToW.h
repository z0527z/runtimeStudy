//
//  ChangeAToW.h
//  ChangeAToW
//
//  Created by jolin.ding on 2019/12/24.
//  Copyright © 2019 jolin.ding. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChangeAToW : NSObject

@property (nonatomic, strong) NSString * firstName;
@property (nonatomic, weak) NSNumber * phone;
@property (nonatomic, assign) id delegate;
@property (nonatomic, strong) NSString * address;
@property (nonatomic, assign) long timeStamp;
@property (nonatomic, assign) char flag;
@property (nonatomic, assign) BOOL isSuccess;


@end

NS_ASSUME_NONNULL_END
