/* CQViewController */

#import <Cocoa/Cocoa.h>

@class ImageTaskManager;
@class ViewIconViewController;
@class PointerWrapper;

@protocol ImageDisplayer 
-(void)displayImage;
@end

/*!
	@class CQViewController
	@abstract Main Controller
*/
@interface CQViewController : NSObject <ImageDisplayer>
{
    IBOutlet NSImageView *imageViewer;
	IBOutlet NSTextField * fileSizeLabel;
	IBOutlet NSTextField * imageSizeLabel;
	IBOutlet NSWindow* viewerWindow;
	IBOutlet NSScrollView* scrollView;

	// Scale view controls
	IBOutlet NSView* scaleView;
	IBOutlet NSSlider* scaleSlider;

	// File view components:
	// * 
	IBOutlet NSPopUpButton* directoryDropdown;
	IBOutlet NSView* currentFileViewHolder;
	NSView* currentFileView;
	
	// * ViewAsImage specific components
	IBOutlet ViewIconViewController* viewAsIconsController;
	
	// Actual application data--NOT OUTLETS!
	NSImageRep* currentImageRep;
	NSString* currentImageFile;

	NSArray* currentDirectoryComponents;
	NSString* currentDirectory;

	// back and forward history
	NSMutableArray* backHistory;
	NSMutableArray* forwardHistory;
	
	// Scale data
	bool scaleProportionally;
	float scaleRatio;
	
	ImageTaskManager* imageTaskManager;
}

// Moving about in 
- (void)setCurrentDirectory:(NSString*)newCurrentDirectory;
- (void)setCurrentFile:(NSString*)newCurrentFile;
- (void)preloadFiles:(NSArray*)filesToPreload;

// Changing the user interface
- (void)setViewAsView:(NSView*)viewToSet;

// Redraws the text
- (void)redraw;

// Go menu actions
-(IBAction)goEnclosingFolder:(id)sender;
-(IBAction)goBack:(id)sender;
-(IBAction)goForward:(id)sender;

-(IBAction)deleteThisFile:(id)sender;

// Scaling stuff
- (IBAction)scaleView100Pressed:(id)sender;
- (IBAction)scaleViewPPressed:(id)sender;
- (IBAction)scaleViewSliderMoved:(id)sender;

// Window delegate method to redraw the image when we resize...
- (void)windowDidResize:(NSNotification*)notification;
-(void)displayImage;

@end
