//
//  Util.m
//  Prototype
//
//  Created by Elliot Glaysher on 9/18/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "Util.h"
#include <stdint.h>

BOOL imageRepIsAnimated(NSImageRep* rep)
{
	if([rep isKindOfClass:[NSBitmapImageRep class]] &&
	   [[(NSBitmapImageRep*)rep valueForProperty:NSImageFrameCount] intValue] > 1)
		return YES;
	else
		return NO;
}

BOOL floatEquals(float one, float two, float tolerance)
{
	return fabs(one - two) < tolerance;
}
