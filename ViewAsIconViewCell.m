//
//  ViewAsIconViewCell.m
//  CQView
//
//  Created by Elliot on 2/9/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ViewAsIconViewCell.h"
#import "NSAttributedString+Truncation.h"
#import "NSString+FileTasks.h"
#import "VitaminSEEController.h"

#include <limits.h>

#define ICON_INSET_VERT		2.0	/* The size of empty space between the icon end the top/bottom of the cell */ 
#define ICON_SIZE 		128.0	/* Our Icons are ICON_SIZE x ICON_SIZE */
#define ICON_INSET_HORIZ	4.0	/* Distance to inset the icon from the left edge. */
#define ICON_TEXT_SPACING	2.0	/* Distance between the end of the icon and the text part */

// Taking 0.1% of a function that takes 7.0% of runtime. We can optimize out these
// variables.
NSSize IMAGE_SIZE = {128.0f, 128.0f};

@implementation ViewAsIconViewCell

-(id)init
{
	if(self = [super init])
	{
		iconImage = nil;
		[self setWraps:YES];
		[self setAlignment:NSCenterTextAlignment];
		[self resetTitleCache];
		loadOwnIconOnDisplay = NO;
	}
	return self;
}

-(void)dealloc
{
	[title release];
	[iconImage release];
	[thisCellsFullPath release];
}

-(NSString*)cellPath
{
	return thisCellsFullPath;
}

-(void)setTitle:(NSString*)newTitle
{
	[title release];
	title = newTitle;
	[title retain];
	[self resetTitleCache];
}

-(void)resetTitleCache
{
	cachedTitleWidth = FLT_MAX;
}

-(void)setCellPropertiesFromPath:(NSString*)path
{
	// Keep this path...
	[thisCellsFullPath release];
	[path retain];
	thisCellsFullPath = path;
	
	[title release];
	title = [path lastPathComponent];
	[title retain];

	[self setStringValue:[thisCellsFullPath lastPathComponent]];
	
	// If we are responsible for loading our own icon, then load it.
	if(loadOwnIconOnDisplay)
		[self setIconImage:[path iconImageOfSize:IMAGE_SIZE]];
	
	// We are going to have to do something with images here...
	[self setEnabled:[thisCellsFullPath isReadable]];
	
	// In the ViewAsIconView, there are no left directories...
	[self setLeaf:YES];	
}

-(void)loadOwnIconOnDisplay
{
	loadOwnIconOnDisplay = YES;	
}

- (void)setIconImage:(NSImage*)image {
    [iconImage release];
    iconImage = image;
	[iconImage retain];
    
    // Make sure the image is going to display at the size we want.
    [iconImage setSize:IMAGE_SIZE];
}

- (NSImage*)iconImage {
    return iconImage;
}

-(void)setHighlighted:(BOOL)flag
{
//	NSLog(@"Setting highlight!");
	[super setHighlighted:flag];
	selected = flag;
}

-(BOOL)isHighlighted
{
	return selected;
}

- (NSSize)cellSizeForBounds:(NSRect)aRect {
    // Make our cells a bit higher than normal to give some additional space for the icon to fit.
    NSSize theSize = [super cellSizeForBounds:aRect];
    theSize.height += ICON_SIZE + ICON_INSET_VERT * 2.0 + 10;
    return theSize;
}

// WE ARE SPENDING 16% OF TOTAL RUNTIME HERE. OPTIMIZE THE FUCK OUT OF THIS!
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView 
{
	// Make this a global constant?
	NSRect	imageFrame, notTextFrame, textFrame;

	// Divide the cell into 2 parts, the image part (on the left) and the text part.
	NSDivideRect(cellFrame, &notTextFrame, &textFrame, 
				 128 + 4.0f * 2.0f,
				 NSMinYEdge);
	imageFrame = notTextFrame;
//	imageFrame.origin.x += (cellFrame.size.width - IMAGE_SIZE.width) / 2.0f;
	imageFrame.origin.x += (int)(cellFrame.size.width - IMAGE_SIZE.width) / 2;
	imageFrame.size = IMAGE_SIZE;
	
	imageFrame.origin.y += 4.0f;
	
	// Adjust the image frame top account for the fact that we may or may not be in a flipped control view, since when compositing
	// the online documentation states: "The image will have the orientation of the base coordinate system, regardless of the destination coordinates".
	// ASSUMPTION: WE ARE IN FLIPPED COORDINATES!
	imageFrame.origin.y += IMAGE_SIZE.width;

	// Highlighting is f'ing bork. Ask if we're the selected cell instead.
	if ([(NSMatrix*)controlView selectedCell] == self) {
		// use highlightColorInView instead of [NSColor selectedControlColor] since NSBrowserCell slightly dims all cells except those in the right most column.
		// The return value from highlightColorInView will return the appropriate one for you. 
		[[self highlightColorInView: controlView] set];
		NSRectFill(notTextFrame);
	}
	
	// Blit the image. We regretably have to lock on this since otherwise we
	// have a FREQUENT deadlock with one of IconFamily's carbon functions.
	pthread_mutex_lock(&imageTaskLock);
		[iconImage compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	pthread_mutex_unlock(&imageTaskLock);
	
	float newWidth = textFrame.size.width - 30.5f;

	// Shark revealed that the -[NSAttributedString trunacteForWidth:] was
	// eating up a bunch of CPU time, so we cache the display title. This 
	// regretably won't help with the first display since we have no idea what
	// textFrame.size is going to be, but it should speed up later later redraws
	// (which there are quite a number of)
	if(newWidth < cachedTitleWidth)
	{
		// Create our string and store it for later use.
		NSAttributedString* aString = [[[[NSAttributedString alloc] 
			initWithString:title] autorelease] truncateForWidth:newWidth];
		cachedTitleWidth = [aString size].width;
		[cachedCellTitle release];
		cachedCellTitle = [[aString string] retain];
		[self setAlignment:NSCenterTextAlignment];
	}
	
	[self setStringValue:cachedCellTitle];
	[super drawInteriorWithFrame:textFrame inView:controlView];
	[self setStringValue:title];
}


@end
