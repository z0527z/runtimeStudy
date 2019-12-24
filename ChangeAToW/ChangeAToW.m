//
//  ChangeAToW.m
//  ChangeAToW
//
//  Created by jolin.ding on 2019/12/24.
//  Copyright © 2019 jolin.ding. All rights reserved.
//

#import "ChangeAToW.h"
#import <objc/runtime.h>

//@interface ChangeAToW ()
//{
//    __strong NSString * _firstName;
//    __weak NSNumber * _phone;
//    __unsafe_unretained id _delegate;
//    __strong NSString * _address;
//    __unsafe_unretained float _success;
//}
//@end

@implementation ChangeAToW

- (void)setDelegate:(id)delegate
{
    _delegate = delegate;
//    NSLog(@"------> %@", [[self delegate] class]);
//
//    unsigned int count = 0;
//    Ivar * ivars = class_copyIvarList([self class], &count);
//    for (unsigned int i = 0; i < count; i ++) {
//        Ivar ivar = ivars[i];
//        const char * name = ivar_getName(ivar);
//        const char * encode = ivar_getTypeEncoding(ivar);
//        long offset = ivar_getOffset(ivar);
//        printf("name:%s, encode:%s, offset:%ld\n", name, encode, offset);
//    }
}


@end

@interface ChangeAToW (fixup)

@end

@implementation ChangeAToW (fixup)

+ (void)load
{
    fixupAssignDelegate(self);
}

- (void)setFix_Delegate:(id)delegate
{
    Ivar ivar = class_getInstanceVariable([self class], "_delegate");
    object_setIvar(self, ivar, delegate);
    [self setFix_Delegate:delegate];
}

- (id)fix_delegate
{
    id delegate = [self fix_delegate];
    Ivar ivar = class_getInstanceVariable([self class], "_delegate");
    delegate = object_getIvar(self, ivar);
    return delegate;
}

static void fixupSelector(Class cls, SEL orgSel, SEL fixSel) {
    Method setter = class_getInstanceMethod(cls, orgSel);
    Method fixSetter = class_getInstanceMethod(cls, fixSel);
    BOOL success = class_addMethod(cls, orgSel, method_getImplementation(fixSetter), method_getTypeEncoding(fixSetter));
    if (success) {
        class_replaceMethod(cls, fixSel, method_getImplementation(setter), method_getTypeEncoding(setter));
    }
    else {
        method_exchangeImplementations(setter, fixSetter);
    }
}

static void fixupAssignDelegate(Class cls) {
    struct {
        Class isa;
        Class superClass;
        struct {
            void * _buckets;
#if __LP64__
            uint32_t _mask;
            uint32_t _occupied;
#else
            uint16_t _mask;
            uint16_t _occupied;
#endif
        } cache;
        uintptr_t bits;
    } *objcClass = (__bridge typeof(objcClass))cls;
#if !__LP64__
#define FAST_DATA_MASK 0xfffffffcUL
#else
#define FAST_DATA_MASK 0x00007ffffffffff8UL
#endif
    struct {
        uint32_t flags;
        uint32_t version;
        struct {
            uint32_t flags;
            uint32_t instanceStart;
            uint32_t instanceSize;
#ifdef __LP64__
            uint32_t reserved;
#endif
            const uint8_t * ivarLayout;
            const char * name;
            void * baseMethodList;
            void * baseProtocols;
            const void * ivars;
            const uint8_t * weakIvarLayout;
            void * baseProperties;
        } *ro;
        
    } *objcRWClass = (typeof(objcRWClass))(objcClass->bits & FAST_DATA_MASK);
    #define RW_CONSTRUCTING (1<<26)
    objcRWClass->flags |= RW_CONSTRUCTING;
    
    uint8_t * weakIvarLayout = (uint8_t *)calloc(2, 1);
    *weakIvarLayout = 0x22;
    class_setWeakIvarLayout(cls, weakIvarLayout);
    objcRWClass->flags &= ~RW_CONSTRUCTING;
    
    fixupSelector(cls, @selector(setDelegate:), @selector(setFix_Delegate:));
    fixupSelector(cls, @selector(delegate), @selector(fix_delegate));
}

@end
