//
//  Util.m
//  CQView
//
//  Created by Elliot on 2/6/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "Util.h"
#import "NSString+FileTasks.h"
#import <stdlib.h>

struct DS buildImageSize(int boxWidth, int boxHeight, int imageWidth, int imageHeight,
					BOOL canScaleProportionally, float ratioToScale,
					BOOL*canGetAwayWithQuickRender)
{
//	NSLog(@"Going to build size with box:[%d,%d] image:[%d, %d] canScale:%d ratio:%f",
//		  boxWidth, boxHeight, imageWidth, imageHeight, canScaleProportionally, ratioToScale);
	struct DS display;
	
	if(canScaleProportionally == YES)
	{
		// Set the size of the image to the size of the image scaled by our 
		// ratio and then tell the imageViewer to scale it to that size.
		display.width = imageWidth * ratioToScale;
		display.height = imageHeight * ratioToScale;
		if(display.width < boxWidth && display.height < boxHeight)
			*canGetAwayWithQuickRender = YES; 
	}
	else
	{
		// Set the size of the display version of the image so that it fits 
		// within the constraints of the NSScaleView that contains this 
		// NSImageView.
		float heightRatio = buildRatio(boxHeight, imageHeight);
		float widthRatio = buildRatio(boxWidth, imageWidth);
		if(imageWidth <= boxWidth && imageHeight <= boxHeight)
		{
			// The image is smaller then the conrentSize and we should just
			// use the size of the image.
			display.width = imageWidth;
			display.height = imageHeight;
			*canGetAwayWithQuickRender = YES;
		}
		else
		{
			// The image needs to be scaled to fit in the box.
			canGetAwayWithQuickRender = NO;

			float ratio = min(heightRatio, widthRatio);
			display.width = imageWidth * ratio;
			display.height = imageHeight * ratio;
		}
	}	

	return display;
}

float buildRatio(int first, int second)
{
	float firstRatio = (float)(first) / (float)(second);
	float secondRatio = (float)(second) / (float)(first);
	return min(secondRatio, firstRatio);
}

BOOL imageRepIsAnimated(NSImageRep* rep)
{
	if([rep isKindOfClass:[NSBitmapImageRep class]] &&
	   [[(NSBitmapImageRep*)rep valueForProperty:NSImageFrameCount] intValue] > 1)
		return YES;
	else
		return NO;
}

// FIXME: We need a working function to provide an image of files with crap...
// 
NSImage* buildImageFromNormalFile(NSString* path, NSSize size)
{
    NSImage *nodeImage = nil;
    
    nodeImage = [[NSWorkspace sharedWorkspace] iconForFile:path];
    if (!nodeImage) {
        // No icon for actual file, try the extension.
        nodeImage = [[NSWorkspace sharedWorkspace] iconForFileType:[path pathExtension]];
    }
    [nodeImage setSize: size];
	
	if ([path isLink]) {
        NSImage *arrowImage = [NSImage imageNamed: @"FSIconImage-LinkArrow"];
        NSImage *nodeImageWithArrow = [[[NSImage alloc] initWithSize: size] autorelease];
        
        [arrowImage setScalesWhenResized: YES];
        [arrowImage setSize: size];
        
        [nodeImageWithArrow lockFocus];
        [nodeImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
        [arrowImage compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver
			];
        [nodeImageWithArrow unlockFocus];
        
        nodeImage = nodeImageWithArrow;
    }
    
    if (nodeImage==nil) {
        nodeImage = [NSImage imageNamed:@"FSIconImage-Default"];
    }
    
    return nodeImage;
}