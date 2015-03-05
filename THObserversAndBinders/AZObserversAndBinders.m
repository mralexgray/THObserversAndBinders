//
//  AZObserversAndBinders.m
//  THObserversAndBinders
//
//  Created by Alex Gray on 6/9/13.
//  Copyright (c) 2013 James Montgomerie. All rights reserved.
////
//@interface THObserver : NSObject
//
//#pragma mark -
//#pragma mark Block-based observers.
//
//typedef void(^THObserverBlock)(void);
//typedef void(^THObserverBlockWithOldAndNew)(id oldValue, id newValue);
//typedef void(^THObserverBlockWithChangeDictionary)(NSDictionary *change);
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//                  block:(THObserverBlock)block;
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//         oldAndNewBlock:(THObserverBlockWithOldAndNew)block;
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//                options:(NSKeyValueObservingOptions)options
//            changeBlock:(THObserverBlockWithChangeDictionary)block;
//
//#pragma mark -
//#pragma mark Target-action based observers.
//
//// Target-action based observers take a selector with a signature with 0-4
//// arguments, and call it like this:
////
//// 0 arguments: [target action];
////
//// 1 argument:  [target actionForObject:object];
////
//// 2 arguments: [target actionForObject:object keyPath:keyPath];
////
//// 3 arguments: [target actionForObject:object keyPath:keyPath change:changeDictionary];
////     Don't expect anything in the change dictionary unless you supply some
////     NSKeyValueObservingOptions.
////
//// 4 arguments: [target actionForObject:object keyPath:keyPath oldValue:oldValue newValue:newValue];
////     NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew will be
////     automatically added to your options if they're not already there and you
////     supply a 4-argument callback.
////
//// The action should not return any value (i.e. should be declared to return
//// void).
////
//// Both the observer and the target are weakly referenced internally.
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//                 target:(id)target
//                 action:(SEL)action;
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//                options:(NSKeyValueObservingOptions)options
//                 target:(id)target
//                 action:(SEL)action;
//
//
//// A second kind of target-action based observer; takes a selector with a
//// signature with 1-2 arguments, and call it like this:
////
//// 1 argument:  [target actionWithNewValue:newValue];
////
//// 2 arguments: [target actionWithOldValue:oldValue newValue:newValue];
////
//// 3 arguments: [target actionForObject:object oldValue:oldValue newValue:newValue];
////
//// The action should not return any value (i.e. should be declared to return
//// void).
////
//// Both the observer and the target are weakly referenced internally.
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//                 target:(id)target
//            valueAction:(SEL)valueAction;
//
//+ (id)observerForObject:(id)object
//                keyPath:(NSString *)keyPath
//                options:(NSKeyValueObservingOptions)options
//                 target:(id)target
//            valueAction:(SEL)valueAction;
//
//
//#pragma mark - 
//#pragma mark Lifetime management
//
//// This is a one-way street. Call it to stop the observer functioning.
//// The THObserver will do this cleanly when it deallocs, but calling it manually
//// can be useful in ensuring an orderly teardown.
//- (void)stopObserving;
//
//@end
#import "AZObserversAndBinders.h"

#import <objc/message.h>

@implementation THObserver {
    __weak id _observedObject;
    NSString *_keyPath;
    dispatch_block_t _block;
}

typedef enum THObserverBlockArgumentsKind {
    THObserverBlockArgumentsNone,
    THObserverBlockArgumentsOldAndNew,
    THObserverBlockArgumentsChangeDictionary
} THObserverBlockArgumentsKind;

- (id)initForObject:(id)object
            keyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
              block:(dispatch_block_t)block
 blockArgumentsKind:(THObserverBlockArgumentsKind)blockArgumentsKind
{
    if((self = [super init])) {
        if(!object || !keyPath || !block) {
            [NSException raise:NSInternalInconsistencyException format:@"Observation must have a valid object (%@), keyPath (%@) and block(%@)", object, keyPath, block];
            self = nil;
        } else {
            _observedObject = object;
            _keyPath = [keyPath copy];
            _block = [block copy];
                        
            [_observedObject addObserver:self
                              forKeyPath:_keyPath
                                 options:options
                                 context:(void *)blockArgumentsKind];
        }
    }
    return self;
}

- (void)dealloc
{
    if(_observedObject) {
        [self stopObserving];
    }
}

- (void)stopObserving
{
    [_observedObject removeObserver:self forKeyPath:_keyPath];
    _block = nil;
    _keyPath = nil;
    _observedObject = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    switch((THObserverBlockArgumentsKind)context) {
        case THObserverBlockArgumentsNone:
            ((THObserverBlock)_block)();
            break;
        case THObserverBlockArgumentsOldAndNew:
            ((THObserverBlockWithOldAndNew)_block)(change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
            break;
        case THObserverBlockArgumentsChangeDictionary:
            ((THObserverBlockWithChangeDictionary)_block)(change);
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"%s called on %@ with unrecognised context (%p)", __func__, self, context];
    }
}


#pragma mark -
#pragma mark Block-based observer construction.

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
                  block:(THObserverBlock)block
{
    return [[self alloc] initForObject:object
                               keyPath:keyPath
                               options:0
                                 block:(dispatch_block_t)block
                    blockArgumentsKind:THObserverBlockArgumentsNone];
}

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
         oldAndNewBlock:(THObserverBlockWithOldAndNew)block
{
    return [[self alloc] initForObject:object
                               keyPath:keyPath
                               options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                                 block:(dispatch_block_t)block
                    blockArgumentsKind:THObserverBlockArgumentsOldAndNew];
}

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
                options:(NSKeyValueObservingOptions)options
            changeBlock:(THObserverBlockWithChangeDictionary)block
{
    return [[self alloc] initForObject:object
                               keyPath:keyPath
                               options:options
                                 block:(dispatch_block_t)block
                    blockArgumentsKind:THObserverBlockArgumentsChangeDictionary];
}


#pragma mark -
#pragma mark Target-action based observer construction.

static NSUInteger SelectorArgumentCount(SEL selector)
{
    NSUInteger argumentCount = 0;
    
    const char *selectorStringCursor = sel_getName(selector);
    char ch;
    while((ch = *selectorStringCursor)) {
        if(ch == ':') {
            ++argumentCount;
        }
        ++selectorStringCursor;
    }
    
    return argumentCount;
}

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
                options:(NSKeyValueObservingOptions)options
                 target:(id)target
                 action:(SEL)action
{
    id ret = nil;
    
    __weak id wTarget = target;
    __weak id wObject = object;

    dispatch_block_t block = nil;
    THObserverBlockArgumentsKind blockArgumentsKind;

    // Was doing this with an NSMethodSignature by calling
    // [target methodForSelector:action], but that will fail if the method
    // isn't defined on the target yet, beating ObjC's dynamism a bit.
    // This looks a little hairier, but it won't fail (and is probably a lot
    // more efficient anyway).
    NSUInteger actionArgumentCount = SelectorArgumentCount(action);
    
    switch(actionArgumentCount) {
        case 0: {
            block = [^{
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, action);
                }
            } copy];
            blockArgumentsKind = THObserverBlockArgumentsNone;
        }
            break;
        case 1: {
            block = [^{
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, action, wObject);
                }
            } copy];
            blockArgumentsKind = THObserverBlockArgumentsNone;
        }
            break;
        case 2: {
            NSString *myKeyPath = [keyPath copy];
            block = [^{
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, action, wObject, myKeyPath);
                }
            } copy];
            blockArgumentsKind = THObserverBlockArgumentsNone;
        }
            break;
        case 3: {
            NSString *myKeyPath = [keyPath copy];
            block = [(dispatch_block_t)(^(NSDictionary *change) {
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, action, wObject, myKeyPath, change);
                }
            }) copy];
            blockArgumentsKind = THObserverBlockArgumentsChangeDictionary;
        }
            break;
        case 4: {
            NSString *myKeyPath = [keyPath copy];
            options |=  NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
            block = [(dispatch_block_t)(^(id oldValue, id newValue) {
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, action, wObject, myKeyPath, oldValue, newValue);
                }
            }) copy];
            blockArgumentsKind = THObserverBlockArgumentsOldAndNew;
        }
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Incorrect number of arguments (%ld) in action for %s (should be 0 - 4)", (long)actionArgumentCount, __func__];
    }
    
    if(block) {
        ret = [[self alloc] initForObject:object
                                  keyPath:keyPath
                                  options:options
                                    block:block
                       blockArgumentsKind:blockArgumentsKind];
    }
    
    return ret;
}

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
                 target:(id)target
                 action:(SEL)action
{
    return [self observerForObject:object keyPath:keyPath options:0 target:target action:action];
}


#pragma mark -
#pragma mark Value-only target-action observers.

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
                options:(NSKeyValueObservingOptions)options
                 target:(id)target
            valueAction:(SEL)valueAction
{
    id ret = nil;
    
    __weak id wTarget = target;

    THObserverBlockWithChangeDictionary block = nil;
    
    NSUInteger actionArgumentCount = SelectorArgumentCount(valueAction);
    
    switch(actionArgumentCount) {
        case 1: {
            options |= NSKeyValueObservingOptionNew;
            block = [^(NSDictionary *change) {
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, valueAction, change[NSKeyValueChangeNewKey]);
                }
            } copy];
        }
            break;
        case 2: {
            options |= NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
            block = [^(NSDictionary *change) {
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, valueAction, change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
                }
            } copy];
        }
            break;
        case 3: {
            __weak id wObject = object;

            options |= NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
            block = [^(NSDictionary *change) {
                id msgTarget = wTarget;
                if(msgTarget) {
                    objc_msgSend(msgTarget, valueAction, wObject, change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
                }
            } copy];
        }
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Incorrect number of arguments (%ld) in action for %s (should be 1 - 2)", (long)actionArgumentCount, __func__];
    }
    
    if(block) {
        ret = [[self alloc] initForObject:object
                                  keyPath:keyPath
                                  options:options
                                    block:(dispatch_block_t)block
                       blockArgumentsKind:THObserverBlockArgumentsChangeDictionary];
    }
    
    return ret;
}

+ (id)observerForObject:(id)object
                keyPath:(NSString *)keyPath
                 target:(id)target
            valueAction:(SEL)valueAction
{
    return [self observerForObject:object keyPath:keyPath options:0 target:target valueAction:valueAction];
}


@end


@implementation THBinder {
    THObserver *_observer;
}

- (id)initForBindingFromObject:(id)fromObject keyPath:(NSString *)fromKeyPath
                      toObject:(id)toObject keyPath:(NSString *)toKeyPath
           transformationBlock:(THBinderTransformationBlock)transformationBlock
{
    if((self = [super init])) {
        __weak id wToObject = toObject;
        NSString *myToKeyPath = [toKeyPath copy];
        
        THObserverBlockWithChangeDictionary changeBlock;
        if(transformationBlock) {
            changeBlock = [^(NSDictionary *change) {
                [wToObject setValue:transformationBlock(change[NSKeyValueChangeNewKey])
                         forKeyPath:myToKeyPath];
            } copy];
        } else {
            changeBlock = [^(NSDictionary *change) {
                [wToObject setValue:change[NSKeyValueChangeNewKey]
                         forKeyPath:myToKeyPath];
            } copy];
        }
        
        _observer = [THObserver observerForObject:fromObject
                                          keyPath:fromKeyPath
                                          options:NSKeyValueObservingOptionNew
                                      changeBlock:changeBlock];
    }
    return self;
}

- (void)stopBinding
{
    [_observer stopObserving];
    _observer = nil;
}

+ (id)binderFromObject:(id)fromObject keyPath:(NSString *)fromKeyPath
              toObject:(id)toObject keyPath:(NSString *)toKeyPath
{
    return [[self alloc] initForBindingFromObject:fromObject keyPath:fromKeyPath
                                         toObject:toObject keyPath:toKeyPath
                              transformationBlock:nil];
}

+ (id)binderFromObject:(id)fromObject keyPath:(NSString *)fromKeyPath
              toObject:(id)toObject keyPath:(NSString *)toKeyPath
      valueTransformer:(NSValueTransformer *)valueTransformer
{
    return [[self alloc] initForBindingFromObject:fromObject keyPath:fromKeyPath
                                         toObject:toObject keyPath:toKeyPath
                              transformationBlock:^id(id value) {
                                  return [valueTransformer transformedValue:value];
                              }];
}

+ (id)binderFromObject:(id)fromObject keyPath:(NSString *)fromKeyPath
              toObject:(id)toObject keyPath:(NSString *)toKeyPath
   transformationBlock:(THBinderTransformationBlock)transformationBlock
{
    return [[self alloc] initForBindingFromObject:fromObject keyPath:fromKeyPath
                                         toObject:toObject keyPath:toKeyPath
                              transformationBlock:transformationBlock];
}

@end
