//
//  NSObject+ObjCGraft.mm
//  ObjCGraft
//
//  Created on 29/12/2018.
//

#import <objc/message.h>
#import <objc/runtime.h>

#import "NSObject+ObjCGraft.h"
#import "_ObjCGraftCenter.h"
#import "_ObjCGraftInfo.h"

static void _NSObjectSuperDealloc(NSObject * __unsafe_unretained self, Class compositedClass, SEL _cmd);

#pragma mark - Internal

void _NSObjectDealloc(NSObject * __unsafe_unretained self, SEL _cmd) {
    objcgraft::_ObjCGraftCenter::shared().lock();
    if (objcgraft::_ObjCGraftCenter::shared().objectHasGraftInfo(self)) {
        auto& graft_info = objcgraft::_ObjCGraftCenter::shared().objectGetGraftInfo(self);
        
        Class composited_class = graft_info.composited_class;
        
        NSObjectDealloc * customImpl = (NSObjectDealloc *)objcgraft::_ObjCGraftCenter::shared().objectGetBackwardInstanceImpl(self, objcgraft::_ObjCCompositedClass::BackwardInstanceImplKind::Dealloc);
        
        if (customImpl != nullptr) {
            (* customImpl)(self, _cmd);
        } else {
            _NSObjectSuperDealloc(self, composited_class, _cmd);
        }
        
        objcgraft::_ObjCGraftCenter::shared().objectWillDealloc(self);
    } else {
        _NSObjectSuperDealloc(self, object_getClass(self), _cmd);
    }
    objcgraft::_ObjCGraftCenter::shared().unlock();
}

Class _NSObjectGetClass(NSObject * self, SEL _cmd) {
    objcgraft::_ObjCGraftCenter::shared().lock();
    
    auto& graft_info = objcgraft::_ObjCGraftCenter::shared().objectGetGraftInfo(self);
    
    Class semantic_calss = graft_info.semantic_class;
    
    NSObjectGetClass * customImpl = (NSObjectGetClass *)objcgraft::_ObjCGraftCenter::shared().objectGetBackwardInstanceImpl(self, objcgraft::_ObjCCompositedClass::BackwardInstanceImplKind::ClassGetter);
    
    if (customImpl) {
#if DEBUG
        Class retVal = (* customImpl)(self, _cmd);
        NSLog(@"The return value(\"%@\") of your implementation defined for selector \"-class\" grafted on class \"%@\" was omitted.", NSStringFromClass(retVal), NSStringFromClass(semantic_calss));
#else
        (* customImpl)(self, _cmd);
#endif
    }
    
    assert(semantic_calss != nil);
    
    objcgraft::_ObjCGraftCenter::shared().unlock();
    
    return semantic_calss;
}

BOOL _NSObjectRespondsToSelector(NSObject * __unsafe_unretained self, SEL _cmd, SEL selector) {
    BOOL respondsToSelector = NO;
    
    objcgraft::_ObjCGraftCenter::shared().lock();
    
    auto& graft_info = objcgraft::_ObjCGraftCenter::shared().objectGetGraftInfo(self);
    
    Class composited_class = graft_info.composited_class;
    
    if (class_respondsToSelector(composited_class, selector)) {
        respondsToSelector = YES;
    } else {
        NSObjectRespondsToSelector * customImpl = (NSObjectRespondsToSelector *)objcgraft::_ObjCGraftCenter::shared().objectGetBackwardInstanceImpl(self, objcgraft::_ObjCCompositedClass::BackwardInstanceImplKind::RespondsToSelector);
        
        if (customImpl) {
            respondsToSelector = customImpl(self, _cmd, selector);
        } else {
            struct objc_super superclass = {
                .receiver = self,
                .super_class = class_getSuperclass(composited_class)
            };
            
            typedef BOOL SuperMsg (struct objc_super *, SEL, SEL);
            SuperMsg * superImpl = (SuperMsg *)objc_msgSendSuper;
            respondsToSelector = (* superImpl)(&superclass, _cmd, selector);
        }
    }
    
    objcgraft::_ObjCGraftCenter::shared().unlock();
    
    return respondsToSelector;
}

BOOL _NSObjectConformsToProtocol(NSObject * __unsafe_unretained self, SEL _cmd, Protocol * protocol) {
    BOOL conformsToProtocol = NO;
    
    objcgraft::_ObjCGraftCenter::shared().lock();
    
    auto& graft_info = objcgraft::_ObjCGraftCenter::shared().objectGetGraftInfo(self);
    
    Class composited_class = graft_info.composited_class;
    
    
    if (class_conformsToProtocol(composited_class, protocol)) {
        conformsToProtocol = YES;
    } else {
        NSObjectConformsToProtocol * customImpl = (NSObjectConformsToProtocol *)objcgraft::_ObjCGraftCenter::shared().objectGetBackwardInstanceImpl(self, objcgraft::_ObjCCompositedClass::BackwardInstanceImplKind::ConformsToProtocol);
        
        if (customImpl) {
            conformsToProtocol = customImpl(self, _cmd, protocol);
        } else {
            struct objc_super superclass = {
                .receiver = self,
                .super_class = class_getSuperclass(composited_class)
            };
            
            typedef BOOL SuperMsg (struct objc_super *, SEL, Protocol *);
            SuperMsg * superImpl = (SuperMsg *)objc_msgSendSuper;
            conformsToProtocol = (* superImpl)(&superclass, _cmd, protocol);
        }
    }
    
    objcgraft::_ObjCGraftCenter::shared().unlock();
    
    return conformsToProtocol;
}

#pragma mark - Private

void _NSObjectSuperDealloc(NSObject * __unsafe_unretained self, Class compositedClass, SEL _cmd) {
    struct objc_super superclass = {
        .receiver = self,
        .super_class = class_getSuperclass(compositedClass)
    };
    
    typedef void SuperMsg (struct objc_super *, SEL);
    SuperMsg * superImpl = (SuperMsg *)objc_msgSendSuper;
    (* superImpl)(&superclass, _cmd);
}
