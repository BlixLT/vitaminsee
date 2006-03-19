//
//  UKUpdateChecker.m
//  NiftyFeatures
//
//  Created by Uli Kusterer on Sun Nov 23 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.
//

#import "UKUpdateChecker.h"


@implementation UKUpdateChecker


// -----------------------------------------------------------------------------
//	-startup
//		This object has been created and loaded at startup. If this is first
//		launch, ask user whether we should check for updates periodically at
//		startup and adjust the prefs accurately.
//
//		If the user wants us to check for updates periodically, check whether
//		it is time and if so, initiate the check.
// 
//      ERG: This method used to be the -awakeFromNib; it has been changed for
//      integration purposes, since I want this to be called AFTER the first
//      document window
//
//	REVISIONS:
//		2004-03-19	witness	  Documented.
//      2006-03-14  eglaysher Integrated into VitaminSEE
// -----------------------------------------------------------------------------

-(void)startup
{
	NSNumber	*   doCheck = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKUpdateChecker:CheckAtStartup"];
	NSString	*   appName = [[NSFileManager defaultManager] displayNameAtPath: [[NSBundle mainBundle] bundlePath]]; 
	NSNumber	*   lastCheckDateNum = [[NSUserDefaults standardUserDefaults] objectForKey: @"UKUpdateChecker:LastCheckDate"];
	NSDate		*   lastCheckDate = nil;
	
	if( doCheck == nil )		// No setting in prefs yet? First launch! Ask!
	{
		if( NSRunAlertPanel( NSLocalizedStringFromTable(@"CHECK_FOR_UPDATES_TITLE", @"UKUpdateChecker", @"Asking whether to check for updates at startup - dialog title"),
							NSLocalizedStringFromTable(@"CHECK_FOR_UPDATES_TEXT", @"UKUpdateChecker", @"Asking whether to check for updates at startup - dialog text"),
							NSLocalizedString(@"Yes",nil), NSLocalizedString(@"No",nil), nil, appName ) == NSAlertDefaultReturn )
			doCheck = [NSNumber numberWithBool:YES];
		else
			doCheck = [NSNumber numberWithBool:NO];
		
		// Save user's preference to prefs file:
		[[NSUserDefaults standardUserDefaults] setObject: doCheck forKey: @"UKUpdateChecker:CheckAtStartup"];
	}
	
	// If user wants us to check for updates at startup, do so:
	if( [doCheck boolValue] )
	{
		NSTimeInterval  timeSinceLastCheck;
		
		// Determine how long since last check:
		if( lastCheckDateNum == nil )
			lastCheckDate = [NSDate distantPast];  // If there's no date in prefs, use something guaranteed to be past.
		else
			lastCheckDate = [NSDate dateWithTimeIntervalSinceReferenceDate: [lastCheckDateNum doubleValue]];
		timeSinceLastCheck = -[lastCheckDate timeIntervalSinceNow];
		
		// If last check was more than DAYS_BETWEEN_CHECKS days ago, check again now:
		if( timeSinceLastCheck > (3600 *24 *DAYS_BETWEEN_CHECKS) )
		{
			[NSThread detachNewThreadSelector: @selector(checkForUpdatesAndNotify:) toTarget: self withObject: [NSNumber numberWithBool: NO]];
			[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithDouble: [NSDate timeIntervalSinceReferenceDate]] forKey: @"UKUpdateChecker:LastCheckDate"];
		}
	}
}


// -----------------------------------------------------------------------------
//	checkForUpdates:
//		IBAction to hook up to the "check for updates" menu item.
//
//	REVISIONS:
//		2004-03-19	witness	Documented.
// -----------------------------------------------------------------------------

-(IBAction) checkForUpdates: (id)sender
{
	[NSThread detachNewThreadSelector: @selector(checkForUpdatesAndNotify:) toTarget: self withObject: [NSNumber numberWithBool: YES]];
	// YES means we *also* tell the user about failure, since this is in response to a menu item.
}


// -----------------------------------------------------------------------------
//	latestVersionsDictionary:
//		Load a dictionary containing info on the latest versions of this app.
//
//		This first tries to get MacPAD-compatible version information. If the
//		developer didn't provide that, it will try the old UKUpdateChecker
//		scheme instead.
//
//	REVISIONS:
//		2004-03-19	witness	Documented.
// -----------------------------------------------------------------------------

-(NSDictionary*)	latestVersionsDictionary
{
	NSString*   fpath = [[NSBundle mainBundle] pathForResource: UKUpdateCheckerURLFilename ofType: @"url"];
	
	// Do we have a MacPAD.url file?
	if( [[NSFileManager defaultManager] fileExistsAtPath: fpath] )  // MacPAD-compatible!
	{
		NSString*		urlfile = [NSString stringWithContentsOfFile: fpath];
		NSArray*		lines = [urlfile componentsSeparatedByString: @"\n"];
		NSString*		urlString = [lines lastObject];   // Either this is the only line, or the line following [InternetShortcut]
		
		if( [urlString characterAtIndex: [urlString length] -1] == '/'		// Directory path? Append bundle identifier and .plist to get an actual file path to download.
			|| [urlString characterAtIndex: [urlString length] -1] == '=' ) // CGI parameter?
			urlString = [[urlString stringByAppendingString: [[NSBundle mainBundle] bundleIdentifier]] stringByAppendingString: @".plist"];
	
		return [NSDictionary dictionaryWithContentsOfURL: [NSURL URLWithString: urlString]];	// Download info from that URL.
	}
	else	// Old-style UKUpdateChecker stuff:
	{
		NSURL*			versDictURL = [NSURL URLWithString: NSLocalizedString(@"UPDATE_PLIST_URL", @"URL where the plist with the latest version numbers is.")];
		NSDictionary*   allVersionsDict = [NSDictionary dictionaryWithContentsOfURL: versDictURL];
		return [allVersionsDict objectForKey: [[NSBundle mainBundle] bundleIdentifier]];
	}
}


// -----------------------------------------------------------------------------
//	latestVersionsDictionary:
//		This does the actual update checking. This is called in a new thread
//		usually to make sure the user doesn't have to wait to work with their
//		app until this has succeeded or even worse timed out with an error.
//
//	REVISIONS:
//		2004-10-19	witness	Documented, made to run in another thread,
//							extracted actual notification into method
//							notifyAboutUpdateToNewVersion:.
// -----------------------------------------------------------------------------

-(void)		checkForUpdatesAndNotify: (NSNumber*)doNotifyBool
{
	NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
	BOOL			doNotify = [doNotifyBool boolValue];
	// Load a .plist of application version info from a web URL:
    NSDictionary *  appVersionDict = [self latestVersionsDictionary];
	BOOL			succeeded = NO;
    
    if( appVersionDict != nil )		// We were able to download a dictionary?
	{
		// Extract version number and URL from dictionary:
		NSString *newVersion = [appVersionDict valueForKey: UKUpdateCheckerVersionPlistKey];
        NSString *newUrl = [appVersionDict valueForKey: UKUpdateCheckerURLPlistKey];
        
		if( !newVersion || !newUrl )	// Dictionary doesn't contain new MacPAD stuff? Use old UKUpdateChecker stuff instead.
		{
			newVersion = [appVersionDict valueForKey:UKUpdateCheckerOldVersionPlistKey];
			newUrl = [appVersionDict valueForKey:UKUpdateCheckerOldURLPlistKey];
		}
		
		// Is it current? Then tell the user, or just quietly go on, depending on doNotify:
        if( [newVersion isEqualToString: [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]] )
		{
            if( doNotify )
				[self performSelectorOnMainThread: @selector(notifyAboutUpdateToNewVersion:)
							withObject:[NSDictionary dictionaryWithObjectsAndKeys: nil] waitUntilDone: YES];
			succeeded = YES;
        }
		else if( newVersion != nil )	// If there's an entry for this app:
		{
			// Ask user whether they'd like to open the URL for the new version:
			[self performSelectorOnMainThread: @selector(notifyAboutUpdateToNewVersion:)
						 withObject: [NSDictionary dictionaryWithObjectsAndKeys:
															newVersion, UKUpdateCheckerVersionPlistKey,
															newUrl, UKUpdateCheckerURLPlistKey,
															nil] waitUntilDone: YES];

            succeeded = YES;	// Otherwise, it's still a success.
        }
    }
	
	// Failed? File not found, no internet, there is no entry for our app?
	if( !succeeded && doNotify )
		[self performSelectorOnMainThread: @selector(notifyAboutUpdateToNewVersion:)
			withObject: [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool: YES], @"isError", nil] waitUntilDone: YES];

	[pool release];
}


// -----------------------------------------------------------------------------
//	notifyAboutUpdateToNewVersion:
//		This actually tells the user about new updates, and is therefore called
//		on the main thread.
//
//	REVISIONS:
//		2004-10-19	witness	Documented, extracted from checkForUpdatesAndNotify:.
//      2006-03-18  ERG     Added boolValue call to isError so it isn't hardcoded
//                          true, even though this doesn't appear to hurt...
// -----------------------------------------------------------------------------

-(void)	notifyAboutUpdateToNewVersion: (NSDictionary*)info
{
	NSString*	appName = [[NSFileManager defaultManager] displayNameAtPath: [[NSBundle mainBundle] bundlePath]];
	NSString*	newVersion = [info objectForKey: UKUpdateCheckerVersionPlistKey];
	NSString*	newUrl = [info objectForKey: UKUpdateCheckerURLPlistKey];
	BOOL		isError = [[info objectForKey: @"isError"] boolValue];
	
	if( newVersion == nil && !isError )
		NSRunAlertPanel(NSLocalizedStringFromTable(@"UP_TO_DATE_TITLE", @"UKUpdateChecker", @"When soft is up-to-date - dialog title"),
				NSLocalizedStringFromTable(@"UP_TO_DATE_TEXT", @"UKUpdateChecker", @"When soft is up-to-date - dialog text"),
				NSLocalizedStringFromTable(@"OK", @"UKUpdateChecker", @""), nil, nil, appName );
	else if( newVersion != nil && !isError )
	{
		int button = NSRunAlertPanel(
				NSLocalizedStringFromTable(@"NEW_VERSION_TITLE", @"UKUpdateChecker", @"A New Version is Available - dialog title"),
				NSLocalizedStringFromTable(@"NEW_VERSION_TEXT", @"UKUpdateChecker", @"A New Version is Available - dialog text"),
				NSLocalizedStringFromTable(@"OK", @"UKUpdateChecker", @""), NSLocalizedStringFromTable(@"Cancel", @"UKUpdateChecker", @""), nil,
				appName, newVersion );
		if( NSOKButton == button )	// Yes?
			[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:newUrl]];   //Open!
	}
	else
	{
		NSRunAlertPanel( NSLocalizedStringFromTable(@"UPDATE_ERROR_TITLE", @"UKUpdateChecker", @"When update test failed - dialog title"),
						 NSLocalizedStringFromTable(@"UPDATE_ERROR_TEXT", @"UKUpdateChecker", @"When update test failed - dialog text"),
						 @"OK", nil, nil, appName );
	}
}

@end
