//
//  ChangeAToW.m
//  ChangeAToW
//
//  Created by jolin.ding on 2019/12/24.
//  Copyright © 2019 jolin.ding. All rights reserved.
//

#import "ChangeAToW.h"
#import <objc/runtime.h>
#include <malloc/malloc.h>

static const char * s_delegate_ivar_name = NULL;

@implementation ChangeAToW

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

__attribute__((__always_inline__))
static void tryFree(const void * p) {
    if (p && malloc_size(p)) {
        free((void *)p);
    }
}

static inline void * memdup(const void * mem, size_t length) {
    void * dup = malloc(length);
    memcpy(dup, mem, length);
    return dup;
}

static const char * copyNoneWeakIvarName(objc_property_t property) {
    if (!property) return NULL;
    bool findWeak = false;
    uint32_t outCount = 0;
    const char * ivarName = NULL;
    objc_property_attribute_t * attributes = property_copyAttributeList(property, &outCount);
    for (uint32_t i = 0; i < outCount; i ++) {
        objc_property_attribute_t attr = *(attributes + i);
        if (strcmp(attr.name, "W") == 0) {
            findWeak = true;
            tryFree(ivarName);
        }
        else if (strcmp(attr.name, "V") == 0 && attr.value) {
            ivarName = (const char *)memdup(attr.value, strlen(attr.value) + 1);
        }
    }
    free(attributes);
    return findWeak ? NULL : ivarName;
}

static Class findClassWithPropertyName(Class cls, const char * name) {
    objc_property_t property = class_getProperty(cls, name);
    if (!property) {
        return NULL;
    }
    const char * ivarName = copyNoneWeakIvarName(property);
    if (!ivarName) {
        cls = class_getSuperclass(cls);
        while (cls) {
            property = class_getProperty(cls, name);
            ivarName = copyNoneWeakIvarName(property);
            if (ivarName) break;
            cls = class_getSuperclass(cls);
        }
    }
    s_delegate_ivar_name = ivarName;
    return ivarName ? cls : NULL;
}

static void fixupAssignDelegate(Class cls) {
    Class orgCls = cls;
    
    // 找到类（父类）中包含的该名字的属性
    cls = findClassWithPropertyName(cls, "delegate");
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
    
    #define RO_IS_ARC 1<<7
    objcRWClass->ro->flags |= RO_IS_ARC;
    #define RW_CONSTRUCTING (1<<26)
    objcRWClass->flags |= RW_CONSTRUCTING;
    
    uint8_t * weakIvarLayout = (uint8_t *)calloc(2, 1);
    *weakIvarLayout = 0x22;
    class_setWeakIvarLayout(cls, weakIvarLayout);
    objcRWClass->flags &= ~RW_CONSTRUCTING;
    
    
    fixupSelector(orgCls, @selector(setDelegate:), @selector(setFix_Delegate:));
    fixupSelector(orgCls, @selector(delegate), @selector(fix_delegate));
}

@end
