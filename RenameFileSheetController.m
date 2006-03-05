/////////////////////////////////////////////////////////////////////////
// File:          $Name$
// Module:        Implements the renaming sheet. Ripped off from GotoFileSheet.
// Part of:       VitaminSEE
//
// Revision:      $Revision: 331 $
// Last edited:   $Date: 2006-01-24 21:36:22 -0600 (Tue, 24 Jan 2006) $
// Author:        $Author: elliot $
// Copyright:     (c) 2005 Elliot Glaysher
// Created:       2/2/06
//
/////////////////////////////////////////////////////////////////////////
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
////////////////////////////////////////////////////////////////////////

#import "RenameFileSheetController.h"
#import "FileOperations.h"
#import "EGPath.h"
#import "ViewerDocument.h"

@interface RenameFileSheetController (Extensions)
-(void)setupExtensions;
-(void)addExtension;
-(void)removeExtension;
@end

@implementation RenameFileSheetController

-(id)initWithFileOperations:(id)operations
{
	if(self = [super initWithWindowNibName:@"RenameFileSheet"])
	{
		[self window];
		
		// We don't retain because it's owned by the ComponentManager
		fileOperations = operations;
	}
	
	return self;
}

//-----------------------------------------------------------------------------

-(void)dealloc
{
	[initialPath release];
	// fileOperations wasn't retained.
	[doc release];	
	[trueExtension release];
	
	[super dealloc];
}

//-----------------------------------------------------------------------------

-(IBAction)clickOK:(id)sender
{
	cancel = false;
	[NSApp endSheet:[self window]];
}

//-----------------------------------------------------------------------------

-(IBAction)clickCancel:(id)sender
{
	cancel = true;
	[NSApp endSheet:[self window]];
}

//-----------------------------------------------------------------------------

-(IBAction)clickHideExtensions:(id)sender
{
	// Here we have to rework the proposed filename based on the check box.
	NSString* currentExtension = [[folderName stringValue] pathExtension];

	if([sender state] == NSOnState) 
	{
		// The button is now on. We need to try to hide the extension.
		if([currentExtension isEqualToString:trueExtension])
		{
			[self removeExtension];
		}
	}
	else
	{
		// The button is now off. We need to try to add the extension.
		[self addExtension];
	}
}

//-----------------------------------------------------------------------------

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	// Get the current extension as is.
	NSString* currentExtension = [[folderName stringValue] pathExtension];
	
	if([hideExtensionButton state] == NSOnState)
	{
		// Detect whether user is trying to add an extension
		if([currentExtension isEqualToString:trueExtension])
		{
			// They added the correct extension, turn the check box off
			[hideExtensionButton setState:NSOffState];
		}
	}
	else 
	{
		// Detect whether the file no longer has an extension
		if(![currentExtension isEqualToString:trueExtension])
			[hideExtensionButton setState:NSOnState];
	}
}

//-----------------------------------------------------------------------------

/** This is the entry point from whoever is calling the RenameSheetController.
 * It displays the renaming sheet and makes it modal.
 */
-(void)showSheet:(NSWindow*)window 
	initialValue:(EGPath*)initial
  notifyWhenDone:(id)document
{
	// First, set the callbacks for later when OUR callbacks are called
	initialPath = [initial retain];	
	doc = [document retain];

	// Setup the extensions so we know how we're supposed to display the name
	[self setupExtensions];
	
	// Clear the 
	NSString* firstName = [[initialPath fileSystemPath] lastPathComponent];
	if(hideExtensionOrig)
		firstName = [firstName stringByDeletingPathExtension];
	
	NSString* format = NSLocalizedString(@"Rename '%@' to:", 
										 @"Label on RenameFileSheetController");
	[labelName setStringValue:[NSString stringWithFormat:format, firstName]];
	[folderName setStringValue:firstName];

	[NSApp beginSheet:[self window]
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

//-----------------------------------------------------------------------------

-(void)sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode
	   contextInfo:(void*)contextInfo
{
	// Let's grab the data out of the text box and call the selector with an
	// NSString of the target directory
	NSString* rawName = [folderName stringValue];
	
	// Close the sheet
	[sheet orderOut:self];	

	if(!cancel) 
	{
		// Disallow attempts to move directories by being clever
		if([rawName rangeOfString:@"/"].location != NSNotFound ||
		   [rawName isEqualTo:@""]) 
		{
			AlertSoundPlay();
			return;
		}
		
		
		// Now we reconstruct the new name based off of the properties of
		// the "Hide Extensions" checkbox.
		BOOL hideExtension = [hideExtensionButton state] == NSOnState;
		if(hideExtension)
			rawName = [rawName stringByAppendingPathExtension:trueExtension];
		
		if(hideExtensionOrig != hideExtension)
			[self undoableSetExtensionHidden:initialPath hidden:hideExtension];
		
		if(![rawName isEqualTo:[[initialPath fileSystemPath] lastPathComponent]])
		{
			if([fileOperations renameFile:initialPath to:rawName]) 
			{	
				// Rename succeded. Display this new file!
				NSString* newPath = [[[initialPath fileSystemPath]			
					stringByDeletingLastPathComponent] 
						stringByAppendingPathComponent:rawName];
				
				[self undoableFocusOnFile:newPath oldPath:initialPath doc:doc];
			}			
		}
	}
}

//-----------------------------------------------------------------------------

-(void)undoableFocusOnFile:(NSString*)newPath oldPath:(EGPath*)oldPath
					   doc:(id)document
{
	// If we undo this rename, we want to make sure to focus on the old
	// file.
	NSUndoManager* um = [doc undoManager];
	[[um prepareWithInvocationTarget:self] undoableFocusOnFile:[oldPath fileSystemPath]
													   oldPath:[EGPath pathWithPath:newPath]
														   doc:document];
	[document focusOnFile:[EGPath pathWithPath:newPath]];	
}

//-----------------------------------------------------------------------------

-(void)undoableSetExtensionHidden:(EGPath*)file hidden:(BOOL)hidden
{
	NSUndoManager* um = [doc undoManager];
	NSFileManager* manager = [NSFileManager defaultManager];
	[[um prepareWithInvocationTarget:self] undoableSetExtensionHidden:file
															   hidden:!hidden];
	
	NSDictionary *dic = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:hidden]
													forKey:NSFileExtensionHidden];
	
	[manager changeFileAttributes:dic atPath:[file fileSystemPath]];
}

@end

//-----------------------------------------------------------------------------

@implementation RenameFileSheetController (Extensions)

-(void)setupExtensions
{
	// Make note of the original extension of the file
	trueExtension = [[[initialPath fileSystemPath] pathExtension] retain];
	
	// First we need the property dictionary for this file.
	NSFileManager* manager = [NSFileManager defaultManager];
	NSString* filePath = [initialPath fileSystemPath];
	NSDictionary *fattrs = [manager fileAttributesAtPath:filePath
											traverseLink:NO];
	
	hideExtensionOrig = [[fattrs objectForKey:NSFileExtensionHidden] boolValue];
	BOOL isDir = [[fattrs objectForKey:NSFileType] isEqual:NSFileTypeDirectory];
	
	if(hideExtensionOrig)
		[hideExtensionButton setState:NSOnState];
	else
		[hideExtensionButton setState:NSOffState];
	
	if(isDir)
		[hideExtensionButton setEnabled:NO];
}

//-----------------------------------------------------------------------------

-(void)removeExtension
{
	[folderName setStringValue:
		[[folderName stringValue] stringByDeletingPathExtension]];
}

//-----------------------------------------------------------------------------

-(void)addExtension
{
	[folderName setStringValue:
		[[folderName stringValue] stringByAppendingPathExtension:trueExtension]];
}

@end