//
//  ViewerDocument.h
//  Prototype
//
//  Created by Elliot Glaysher on 8/11/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FileList.h"

@class VitaminSEEWindowController;

// Notifications that are posted to a ViewerDocument's NotificationCenter

#define EGViewerImageFileSet @"EGViewerImageFileSet"
#define EGViewerWindowBecameMainWindow @"EGViewerWindowBecameMainWindow"
#define EGViewerWindowLostMainWindow @"EGViewerWindowLostMainWindow"
#define EGViewerWindowClosed @"EGViewerWindowClosed"

@interface ViewerDocument : NSDocument <FileListDelegate> {
	VitaminSEEWindowController* window;
	NSNotificationCenter* viewerNotifications;
	
	// The document ID. This is how we identify ourselves. This doesn't change
	NSNumber* documentID;
	
	// The document owns the current file list
	id<FileList> fileList;
	
	// CurrentFile we're looking at.
	EGPath* currentFile;
	
	// Scale data
	NSString* scaleMode;
	float scaleRatio;
}

-(id)init;
-(id)initWithPath:(NSString*)path;

-(NSNumber*)documentID;

-(void)startProgressIndicator;
-(void)stopProgressIndicator;

-(BOOL)validateAction:(SEL)action;
@end
