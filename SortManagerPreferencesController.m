//
//  SortManagerPreferencesController.m
//  CQView
//
//  Created by Elliot on 2/22/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "SortManagerPreferencesController.h"


@implementation SortManagerPreferencesController

-(IBAction)add:(id)sender
{
	// Ask the user what directories to add. Use a panel instead of a sheet for
	// two reasons:
	//
	// a) iTunes Preference pane looks like us and IT opens a new panel instead
	//    of a sheet. I doubt an Apple app would go agaisnt the HIG.
	// b) This is easier. I'd have to modify the framework so that these plugins
	//    are aware of the parent window.
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setAllowsMultipleSelection:YES];
	
	int result = [panel runModalForDirectory:[NSHomeDirectory() 
		stringByAppendingPathComponent:@"Pictures"]
										file:nil
									   types:nil];
	if(result == NSOKButton) {
		NSArray *directoriesToAdd = [panel filenames];
		NSEnumerator *e = [directoriesToAdd objectEnumerator];
		NSString* path;
		while(path = [e nextObject])
		{
			NSDictionary* dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:path,
				@"Path", [path lastPathComponent], @"Name", nil];
			[listOfDirectories addObject:dict];			
		}
	}
}

/////////////////////////////////////////// Protocol: SS_PreferencePaneProtocol

+(NSArray*)preferencePanes
{
	return [NSArray arrayWithObjects:[[[SortManagerPreferencesController alloc]
		init] autorelease], nil];
}

- (NSView *)paneView
{
    BOOL loaded = YES;
    
    if (!prefView)
        loaded = [NSBundle loadNibNamed:@"SortManagerPreferences" owner:self];
    
    if (loaded)
        return prefView;
    
    return nil;
}

- (NSString *)paneName
{
    return @"Sort Manager";
}

- (NSImage *)paneIcon
{
	// Fix this...
    return [[[NSImage alloc] initWithContentsOfFile:
        [[NSBundle bundleForClass:[self class]] pathForImageResource:@"General_Prefs"]
        ] autorelease];
}

- (NSString *)paneToolTip
{
    return @"Sort Manager Preferences";
}

- (BOOL)allowsHorizontalResizing
{
    return NO;
}

- (BOOL)allowsVerticalResizing
{
    return NO;
}

@end
