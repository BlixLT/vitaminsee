//
//  KeywordManager.h
//  CQView
//
//  Created by Elliot on 3/3/05.
//  Copyright 2005 Elliot Glaysher. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CurrentFilePlugin.h"

@class KeywordNode;

@interface KeywordManagerController : NSWindowController <CurrentFilePlugin>
{
	IBOutlet NSTextField* fileNameTextField;
	IBOutlet NSTextView* currentKeywordsTextView;
	IBOutlet NSOutlineView* outlineView;

	PluginLayer* pluginLayer;
//	VitaminSEEController* pluginLayer;	
	KeywordNode* keywordRoot;
	
	BOOL keywordsDirty;
	NSString* currentPath;
	NSMutableArray* keywords;
}

-(IBAction)cellClicked:(id)sender;
-(IBAction)keywordTextViewChanged:(id)sender;
-(IBAction)fileChanged:(id)sender;

-(void)saveKeywords;
-(void)loadKeywords;

-(void)enableAllCells;
-(void)disableAllCells;

-(void)loadKeywordTree;
-(void)loadKeywordsIntoTextViewFromList;
-(void)loadKeywordsIntoListFromTextView;

-(void)fileSetTo:(NSString*)newPath;

// Get the plugin name
-(NSString*)name;

// Most plugins will have a show window
-(void)activate;

// Context menu items for this plugin.
-(NSArray*)contextMenuItems;

@end
