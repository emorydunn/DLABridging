//
//  DLABInputCallback.h
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
 * IDeckLinkInputCallback
 */

/* =================================================================================== */

@protocol DLABInputCallbackDelegate <NSObject>
@required
- (void) didChangeVideoInputFormat:(BMDVideoInputFormatChangedEvents)events displayMode:(IDeckLinkDisplayMode*)displayMode flags:(BMDDetectedVideoInputFormatFlags)flags;
- (void) didReceiveVideoInputFrame:(IDeckLinkVideoInputFrame*)videoFrame audioInputPacket: (IDeckLinkAudioInputPacket*)audioPacket;
@optional
@end

/* =================================================================================== */

class DLABInputCallback : public IDeckLinkInputCallback
{
public:
    DLABInputCallback(id<DLABInputCallbackDelegate> delegate);
    
    // IDeckLinkInputCallback
    HRESULT VideoInputFormatChanged(BMDVideoInputFormatChangedEvents notificationEvents, IDeckLinkDisplayMode *newDisplayMode, BMDDetectedVideoInputFormatFlags detectedSignalFlags);
    HRESULT VideoInputFrameArrived(IDeckLinkVideoInputFrame* videoFrame, IDeckLinkAudioInputPacket* audioPacket);
    
    // IUnknown
    HRESULT QueryInterface(REFIID iid, LPVOID *ppv);
    ULONG AddRef();
    ULONG Release();
    
private:
    id<DLABInputCallbackDelegate> delegate;
    int32_t refCount;
};
