//
//  DLABBrowser.mm
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import "DLABBrowser+Internal.h"

const char* kBrowserQueue = "DLABDevice.browserQueue";

@implementation DLABBrowser

- (instancetype) init
{
    self = [super init];
    if (self) {
        direction = DLABVideoIOSupportNone;
        _devices = [NSMutableArray array];
    }
    
    return self;
}

- (void) dealloc
{
    [self stop];
    
    if (callback) {
        callback->Release();
        callback = NULL;
    }
    if (discovery) {
        discovery->Release();
        discovery = NULL;
    }
}

/* =================================================================================== */
// MARK: - public method
/* =================================================================================== */

- (BOOL) startForInput
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportCapture;
    return [self startForDirection:newDirection];
}

- (BOOL) startForOutput
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportPlayback;
    return [self startForDirection:newDirection];
}

- (BOOL) start
{
    DLABVideoIOSupport newDirection = DLABVideoIOSupportCapture | DLABVideoIOSupportPlayback;
    return [self startForDirection:newDirection];
}

- (BOOL) stop
{
    if (direction == DLABVideoIOSupportNone) {
        return NO;
    }
    
    direction = DLABVideoIOSupportNone;
    
    // remove all registerd devices
    [_devices removeAllObjects];
    
    __block HRESULT result = E_FAIL;
    [self browser_sync:^{
        if (discovery) {
            if (callback) {
                result = discovery->UninstallDeviceNotifications();
                
                callback->Release();
                callback = NULL;
            }
            discovery->Release();
            discovery = NULL;
        }
    }];
    
    if (!result) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) startForDirection:(DLABVideoIOSupport) newDirection
{
    NSParameterAssert(newDirection);
    
    // Check parameters
    BOOL currentFlag = (direction != DLABVideoIOSupportNone);
    BOOL newFlag = ((newDirection & (DLABVideoIOSupportCapture|DLABVideoIOSupportPlayback)) == 0);
    if (currentFlag || newFlag) {
        return NO;
    }
    
    // initial registration should be done here
    [self registerDevicesForDirection:newDirection];
    
    __block HRESULT result = E_FAIL;
    [self browser_sync:^{
        if (!discovery && !callback) {
            discovery = CreateDeckLinkDiscoveryInstance();
            if (discovery) {
                callback = new DLABDeviceNotificationCallback(self);
                if (callback) {
                    result = discovery->InstallDeviceNotifications(callback);
                }
            }
        }
    }];
    
    if (!result) {
        direction = newDirection;
        return YES;
    } else {
        return NO;
    }
}

/* =================================================================================== */
// MARK: - public query
/* =================================================================================== */

- (NSArray*) allDevices
{
    __block NSArray* array = nil;
    [self browser_sync:^{
        array = [NSArray arrayWithArray:self.devices];
    }];
    if (array) {
        return array;
    } else {
        return nil;
    }
}

- (DLABDevice*) deviceWithModelName:(NSString*)modelName
                        displayName:(NSString*)displayName
{
    NSParameterAssert(modelName && displayName);
    
    for (DLABDevice* device in self.devices) {
        BOOL matchModelName = ([device.modelNameW compare: modelName] == NSOrderedSame);
        BOOL matchDisplayName = ([device.displayNameW compare: displayName] == NSOrderedSame);
        if (matchModelName && matchDisplayName) {
            return device;
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithPersistentID:(int64_t)persistentID
{
    for (DLABDevice* device in self.devices) {
        if (device.persistentIDW == persistentID) {
            return device;
        }
    }
    return nil;
}

- (DLABDevice*) deviceWithTopologicalID:(int64_t)topologicalID
{
    for (DLABDevice* device in self.devices) {
        if (device.topologicalIDW == topologicalID) {
            return device;
        }
    }
    return nil;
}

/* =================================================================================== */
// MARK: - private method - initial registration
/* =================================================================================== */

- (void) registerDevicesForDirection:(DLABVideoIOSupport) newDirection
{
    NSParameterAssert(newDirection);
    
    NSMutableArray* newDevices = [NSMutableArray array];
    
    // Iterate every DeckLinkDevice and register as initial state
    IDeckLinkIterator* iterator = CreateDeckLinkIteratorInstance();
    if (iterator) {
        IDeckLink* newDeckLink = NULL;
        while (iterator->Next(&newDeckLink) == S_OK) {
            // Avoid duplication
            if ([self deviceWithDeckLink:newDeckLink])
                continue;
            
            DLABDevice* newDevice = [[DLABDevice alloc] initWithDeckLink:newDeckLink];
            if (!newDevice)
                continue;
            
            BOOL captureFlag = ((newDirection & DLABVideoIOSupportCapture) &&
                                newDevice.supportCaptureW);
            BOOL playbackFlag = ((newDirection & DLABVideoIOSupportPlayback) &&
                                 newDevice.supportPlaybackW);
            
            if (captureFlag || playbackFlag) {
                [newDevices addObject:newDevice];
            }
        }
        iterator->Release();
    }
    
    if ([newDevices count]) {
        [self browser_sync:^{
            [self.devices addObjectsFromArray:newDevices];
        }];
    }
}

/* =================================================================================== */
// MARK: - private query
/* =================================================================================== */

- (DLABDevice*) deviceWithDeckLink:(IDeckLink *)deckLink
{
    NSParameterAssert(deckLink);
    
    for (DLABDevice* device in self.devices) {
        if (device.deckLink == deckLink) {
            return device;
        }
    }
    return nil;
}

/* =================================================================================== */
// MARK: - protocol DLABDeviceNotificationCallbackDelegate
/* =================================================================================== */

- (void) didAddDevice:(IDeckLink*)deckLink
{
    NSParameterAssert(deckLink);
    
    // Avoid duplication
    if ([self deviceWithDeckLink:deckLink])
        return;
    
    DLABDevice* device = [[DLABDevice alloc] initWithDeckLink:deckLink];
    if (device) {
        BOOL captureFlag = ((direction & DLABVideoIOSupportCapture) &&
                            device.supportCaptureW);
        BOOL playbackFlag = ((direction & DLABVideoIOSupportPlayback) &&
                             device.supportPlaybackW);
        
        if (captureFlag || playbackFlag) {
            [self browser_sync:^{
                [self.devices addObject:device];
                [_delegate didAddDevice:device browser:self];
            }];
        }
    }
}

- (void) didRemoveDevice:(IDeckLink*)deckLink
{
    NSParameterAssert(deckLink);
    
    DLABDevice* device = [self deviceWithDeckLink:deckLink];
    if (device) {
        [self browser_sync:^{
            [self.devices removeObject:device];
            [_delegate didRemoveDevice:device browser:self];
        }];
    }
}

/* =================================================================================== */
// MARK: - private - lazy instantiation
/* =================================================================================== */

- (dispatch_queue_t) browserQueue
{
    if (!_browserQueue) {
        browserQueueKey = &browserQueueKey;
        void *unused = (__bridge void*)self;
        _browserQueue = dispatch_queue_create(kBrowserQueue, DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_browserQueue, browserQueueKey, unused, NULL);
    }
    return _browserQueue;
}

/* =================================================================================== */
// MARK: - private - block helper
/* =================================================================================== */

- (void) browser_sync:(dispatch_block_t) block
{
    NSParameterAssert(block);
    
    dispatch_queue_t queue = self.browserQueue; // Allow lazy instantiation
    if (queue) {
        if (browserQueueKey && dispatch_get_specific(browserQueueKey)) {
            block();
        } else {
            dispatch_sync(queue, block);
        }
    } else {
        NSLog(@"ERROR: The queue is not available.");
    }
}

@end
