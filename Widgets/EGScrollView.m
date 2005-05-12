//
//  EGScrollView.m
//  VitaminSEE
//
//  Created by Elliot Glaysher on 5/11/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "EGScrollView.h"

#define UnicodeLeft [NSString stringWithFormat:@"%C",0x2190]
#define UnicodeRight [NSString stringWithFormat:@"%C",0x2192]
#define UnicodeUp [NSString stringWithFormat:@"%C",0x2191]
#define UnicodeDown [NSString stringWithFormat:@"%C",0x2193]

#define   ARROW_UP_KEY        0x7E
#define   ARROW_DOWN_KEY      0x7D
#define   ARROW_LEFT_KEY      0x7B
#define   ARROW_RIGHT_KEY     0x7C

@implementation EGScrollView

-(void)noteMouseDown
{
	[[self window] makeFirstResponder:self];
}

// Move this to a NSScrollView subclass!?
- (BOOL)acceptsFirstResponder
{
	return YES;
}

-(BOOL)becomeFirstResponder
{
	shouldDrawFocusRing = YES;
	[self setNeedsDisplay:YES];
	return YES;
}

- (BOOL)canBecomeKeyView
{
	return YES;
}

- (BOOL)needsPanelToBecomeKey
{
	return YES;
}

-(void)keyDown:(NSEvent*)theEvent {
	if([theEvent keyCode] == ARROW_LEFT_KEY)
		[self scrollTheViewByX:-([self horizontalLineScroll]) y:0];
	else if([theEvent keyCode] == ARROW_RIGHT_KEY)
		[self scrollTheViewByX:[self horizontalLineScroll] y:0];
	else if([theEvent keyCode] == ARROW_UP_KEY)
		[self scrollTheViewByX:0 y:[self verticalLineScroll]];
	else if([theEvent keyCode] == ARROW_DOWN_KEY)
		[self scrollTheViewByX:0 y:-([self verticalLineScroll])];
	else
		[super keyDown:theEvent];
}

-(void)scrollTheViewByX:(float)x y:(float)y
{
	NSRect rect = [self documentVisibleRect];
	NSRect clipRect = [[self contentView] bounds];
	NSSize documentSize = [[self documentView] frame].size;
	
	if(documentSize.width > clipRect.size.width)
	{
		rect.origin.x += x;
		
		if(rect.origin.x < 0)
			rect.origin.x = 0;
		else if(rect.origin.x > documentSize.width - rect.size.width)
			rect.origin.x = documentSize.width - rect.size.width;
	}
	
	if(documentSize.height > clipRect.size.height)
	{
		rect.origin.y += y;
		
		if(rect.origin.y < 0)
			rect.origin.y = 0;
		else if(rect.origin.y > documentSize.height - rect.size.height)
			rect.origin.y = documentSize.height - rect.size.height;
	}

	[[self contentView] scrollToPoint:rect.origin];
	[self reflectScrolledClipView: [self contentView]];
}

- (BOOL)needsDisplay; 
{
    NSResponder *resp = nil; 
    if ([[self window] isKeyWindow]) { 
        resp = [[self window] firstResponder]; 
        if (resp == lastResp) return [super needsDisplay]; 
    } else if (lastResp == nil) { 
        return [super needsDisplay]; 
    } 
    shouldDrawFocusRing = (resp != nil && [resp isKindOfClass: [NSView class]] && 
                           [(NSView *)resp isDescendantOf: self]); // [sic] 
    lastResp = resp; 

	NSRect boundsWithSideView = [self bounds];
//	boundsWithSideView.origin.x -= 10;
//	boundsWithSideView.origin.y -= 10;	
//	boundsWithSideView.size.width += 10;
//	boundsWithSideView.size.height += 20;
    [self setKeyboardFocusRingNeedsDisplayInRect:boundsWithSideView]; 
    return YES; 
} 

- (void)drawRect:(NSRect)rect {
    [super drawRect: rect]; 
//    NSLog(@"%@ drawing focus ring? %hd", self, shouldDrawFocusRing); 
    if (shouldDrawFocusRing) { 
        NSSetFocusRingStyle(NSFocusRingOnly); 
        NSRectFill(rect);
    } 
} 

@end
