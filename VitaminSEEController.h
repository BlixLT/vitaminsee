/* VitaminSEEController */

#import <Cocoa/Cocoa.h>

@class ImageTaskManager;
@class ViewIconViewController;
@class PointerWrapper;
@class SortManagerController;
@class SS_PrefsController;

@protocol ImageDisplayer 
-(void)displayImage;
-(void)setIcon;
@end

/*!
	@class VitaminSEEController
	@abstract Main Controller
*/
@interface VitaminSEEController : NSObject <ImageDisplayer>
{
	IBOutlet NSWindow* mainVitaminSeeWindow;
	
	// Menu items we need to attatch items to
	IBOutlet NSMenuItem* homeFolderMenuItem;
	IBOutlet NSMenuItem* pictureFolderMenuItem;
	
	
    IBOutlet NSImageView *imageViewer;
	IBOutlet NSTextField * fileSizeLabel;
	IBOutlet NSTextField * imageSizeLabel;
	IBOutlet NSWindow* viewerWindow;
	IBOutlet NSScrollView* scrollView;

	// Integrated plugins.
	id _sortManagerController;
	id _keywordManagerController;

	// File view components:
	// * 
	IBOutlet NSPopUpButton* directoryDropdown;
	IBOutlet NSView* currentFileViewHolder;
	NSView* currentFileView;
	
	// * ViewAsImage specific components
	IBOutlet ViewIconViewController* viewAsIconsController;

	IBOutlet NSProgressIndicator* progressIndicator;
	IBOutlet NSTextField * progressCurrentTask;
		
	// Actual application data--NOT OUTLETS!
	NSImageRep* currentImageRep;
	NSString* currentImageFile;

	NSArray* currentDirectoryComponents;
	NSString* currentDirectory;

	// Scale data
//	ScalingMethod scaleMethod;
	bool scaleProportionally;
	float scaleRatio;

	NSUndoManager* pathManager;
	
	ImageTaskManager* imageTaskManager;
	
	SS_PrefsController *prefs;
	
	// Loaded plugins:
	NSMutableArray* loadedFilePlugins;
	
	// Dynamically loaded interface elemenets.
	// Goto sheet
	IBOutlet NSWindow* gotoFolderSheet;
	IBOutlet NSTextField* gotoPath;
}

-(NSWindowController*)sortManagerController;

// Moving about in 
- (void)setCurrentDirectory:(NSString*)newCurrentDirectory file:(NSString*)newCurrentFile;
- (void)setCurrentFile:(NSString*)newCurrentFile;
- (void)preloadFiles:(NSArray*)filesToPreload;

// Changing the user interface
- (void)setViewAsView:(NSView*)viewToSet;

// Redraws the text
- (void)redraw;

// File menu options
-(IBAction)openFolder:(id)sender;
-(IBAction)closeWindow:(id)sender;

// View menu options
-(IBAction)revealInFinder:(id)sender;

// Go menu actions
-(IBAction)goEnclosingFolder:(id)sender;
-(IBAction)goBack:(id)sender;
-(IBAction)goForward:(id)sender;
// ----------------------
-(IBAction)goToHomeFolder:(id)sender;
-(IBAction)goToPicturesFolder:(id)sender;
// ----------------------
-(IBAction)goToFolder:(id)sender;

-(IBAction)toggleVitaminSee:(id)sender;
-(IBAction)toggleSortManager:(id)sender;
-(IBAction)toggleKeywordManager:(id)sender;

-(IBAction)zoomIn:(id)sender;
-(IBAction)zoomOut:(id)sender;
-(IBAction)zoomToFit:(id)sender;
-(IBAction)actualSize:(id)sender;

// Window delegate method to redraw the image when we resize...
- (void)windowDidResize:(NSNotification*)notification;
-(void)displayImage;
-(void)setIcon;

// Progress indicator control
-(void)startProgressIndicator:(NSString*)statusText;
-(void)stopProgressIndicator;

-(IBAction)showPreferences:(id)sender;
-(IBAction)deleteFileClicked:(id)sender;
@end
