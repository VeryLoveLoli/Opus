//
//  Opus.h
//  Opus
//
//  Created by 韦烽传 on 2021/3/5.
//

#import <Foundation/Foundation.h>

//! Project version number for Opus.
FOUNDATION_EXPORT double OpusVersionNumber;

//! Project version string for Opus.
FOUNDATION_EXPORT const unsigned char OpusVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <Opus/PublicHeader.h>

#import <Opus/opus_c.h>
#import <Opus/opus_multistream.h>
#import <Opus/opus_types.h>
#import <Opus/opus_defines.h>
#import <Opus/opus_projection.h>
