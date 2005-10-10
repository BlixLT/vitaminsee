/*
 *  FileView.h
 *  CQView
 *
 *  Created by Elliot on 3/6/05.
 *  Copyright 2005 Elliot Glaysher. All rights reserved.
 *
 */

#import "PluginBase.h"

/*
 A file view presents a set of files to the user. Multiple files can be selected,
 but only one can be viewed at a time.
 
 */
@class EGPath;

/** The FileViewFactory protocol must be implemented by the Principle Class of the 
 * 
 *
 */
@protocol FilveViewFactory <PluginBase>
-(id)createView;
@end

@protocol FileView <PluginBase>

// 
-(BOOL)canGoNextFile;
-(void)goNextFile;

-(BOOL)canGoPreviousFile;
-(void)goPreviousFile;

// File selection
-(BOOL)fileIsInView:(NSString*)fileIsInView;
-(NSArray*)selectedFiles;

// Capabilities
-(BOOL)canSetCurrentDirectory;
-(BOOL)canGoEnclosingFolder;

// Setting and getting the file view
-(void)setCurrentDirectory:(EGPath*)directory currentFile:(NSString*)file;
-(void)goEnclosingFolder;

// Files need to be added and removed from lists.
// fixme: Can I remove these if I force views to listen to NSWorkspace?
-(void)removeFile:(NSString*)path;
-(void)addFile:(NSString*)path;

// View that gets displayed on the left hand side
-(NSView*)view;

// Set the thumbnail for file. If the 
-(void)setThumbnail:(NSImage*)image forFile:(NSString*)path;

@end
