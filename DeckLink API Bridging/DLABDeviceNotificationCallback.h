//
//  DLABDeviceNotificationCallback.h
//  DLABridging
//
//  Created by Takashi Mochizuki on 2017/08/26.
//  Copyright © 2017年 Takashi Mochizuki. All rights reserved.
//

/* This software is released under the MIT License, see LICENSE.txt. */

#import <Foundation/Foundation.h>
#import <DeckLinkAPI.h>

/*
 * Internal use only
 * This is C++ subclass with ObjC Protocol from
 * IDeckLinkDeviceNotificationCallback
 */

/* =================================================================================== */

@protocol DLABDeviceNotificationCallbackDelegate <NSObject>
@required
- (void) didAddDevice:(IDeckLink*)deckLink;
- (void) didRemoveDevice:(IDeckLink*)deckLink;
@optional
@end

/* =================================================================================== */

class DLABDeviceNotificationCallback : public IDeckLinkDeviceNotificationCallback
{
public:
    DLABDeviceNotificationCallback(id<DLABDeviceNotificationCallbackDelegate> delegate);
    
    // IDeckLinkDeviceNotificationCallback
    HRESULT DeckLinkDeviceArrived(IDeckLink *deckLink);
    HRESULT DeckLinkDeviceRemoved(IDeckLink *deckLink);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    id<DLABDeviceNotificationCallbackDelegate> delegate;
    int32_t refCount;
};
