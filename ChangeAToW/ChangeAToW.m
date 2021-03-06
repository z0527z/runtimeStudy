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

struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    uint32_t alignment_raw;
    uint32_t size;
};

struct ivar_list_t {
    uint32_t entsizeAndFlags;
    uint32_t count;
    struct ivar_t first;
};

static void fixupAssignDelegate(Class cls) {
    Class orgCls = cls;
    
    // 找到包含该属性名的类（父类）
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
            const struct ivar_list_t * ivars;
            const uint8_t * weakIvarLayout;
            void * baseProperties;
        } *ro;
        
    } *objcRWClass = (typeof(objcRWClass))(objcClass->bits & FAST_DATA_MASK);
    
    // 查找上面找到的类是否含有 ivars
    struct ivar_list_t * ivarList = (struct ivar_list_t *)objcRWClass->ro->ivars;
    if (!ivarList || !ivarList->count) {
        return;
    }
    
    // 设置类的 class_rw_t 的标志以便后续能够调用 class_setWeakIvarLayout
    #define RO_IS_ARC 1<<7
    objcRWClass->ro->flags |= RO_IS_ARC;
    #define RW_CONSTRUCTING (1<<26)
    objcRWClass->flags |= RW_CONSTRUCTING;
    
    // 从ivarList中找到该ivar
    struct ivar_t * foundIvar = NULL;
    for (uint32_t i = 0; i < ivarList->count; i ++) {
        struct ivar_t * ivar = (&ivarList->first + i);
        if (ivar->name && strcmp(s_delegate_ivar_name, ivar->name) == 0) {
            foundIvar = ivar;
            break;
        }
    }
    
    if (!foundIvar) {
        return;
    }
    
    // 找到 s_delegate_ivar_name 所在的位置，计算它前面有多少个非weak ivar，计算从它开始到下一个非weak ivar的个数
    const uint8_t * weakLayout = class_getWeakIvarLayout(cls);
    uint8_t * placeHolderNewWeakLayout = calloc(ivarList->count + 1, sizeof(uint8_t));
    uint8_t * p = placeHolderNewWeakLayout;
    ptrdiff_t offset = ivar_getOffset((Ivar)foundIvar);
    unsigned long placeHolderIndex = offset / sizeof(void *);
    unsigned long visitedOffset = 0;
    bool didFix = false;
    while (*weakLayout != '\x00') {
        int firstWeakOffset = (*weakLayout & 0xf0) >> 4;
        int continuousWeakCount = *weakLayout & 0xf;
        
        visitedOffset += firstWeakOffset + continuousWeakCount;
        
        if (placeHolderIndex == firstWeakOffset) { // 要改变的属性刚好在第一个weak前面
            *p++ = (((firstWeakOffset - 1) << 4) & 0xf0) | ((continuousWeakCount + 1) & 0xf);
            memcpy(p, weakLayout + 1, strlen((const char *)weakLayout) - 1);
            didFix = true;
            break;
        }
        else if (placeHolderIndex < firstWeakOffset) { // 要改变的属性在第一个weak前面好几个身位
            *p++ = (((placeHolderIndex - 1) << 4) & 0xf0) | 0x1;
            memcpy(p, weakLayout, strlen((const char *)weakLayout));
            didFix = true;
            break;
        }
        else if (visitedOffset + 1 < placeHolderIndex) { // 要改变的属性不在范围内
            *p++ = *weakLayout++;
            continue;
        }
        
        uint8_t newLayout =  ((firstWeakOffset << 4) & 0xf0)  | ((continuousWeakCount + 1) & 0xf);
        *p++ = newLayout;
        didFix = true;
        break;
    }
    
    // 在原来的范围内找完都没有找到要改变的属性，则需要在原来的基础上新增layout描述
    if (!didFix) {
        *p++ = (((placeHolderIndex - visitedOffset - 1) << 4) & 0xf0) | 0x1;
    }
    
    uint8_t * tmp = placeHolderNewWeakLayout;
    while (*tmp != '\x00') {
        printf("%02x ", *tmp++);
    }
    printf("\n");
    
    class_setWeakIvarLayout(cls, placeHolderNewWeakLayout);
    objcRWClass->flags &= ~RW_CONSTRUCTING;
    
    
    fixupSelector(orgCls, @selector(setDelegate:), @selector(setFix_Delegate:));
    fixupSelector(orgCls, @selector(delegate), @selector(fix_delegate));
}


@end
