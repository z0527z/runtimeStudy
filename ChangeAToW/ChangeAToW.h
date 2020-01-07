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
@property (nonatomic, assign) id delegate;
@property (nonatomic, strong) NSString * firstName;
@property (nonatomic, weak) NSNumber * phone;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, weak) NSDate * date;
@property (nonatomic, assign) long timeStamp;
@property (nonatomic, strong) NSString * address;
@property (nonatomic, assign) char flag;
@property (nonatomic, assign) BOOL isSuccess;
@property (nonatomic, assign) char pos;
@property (nonatomic, assign) BOOL state;
@property (nonatomic, assign) short keyCount;
@property (nonatomic, assign) short bubbleNum;
@property (nonatomic, assign) short carNum;


@end

NS_ASSUME_NONNULL_END
