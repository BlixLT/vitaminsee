//
//  ImageTaskManager.m
//  CQView
//
//  Created by Elliot on 2/7/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ImageTaskManager.h"
#import "Util.h"
#import "IconFamily.h"
#import "CQViewController.h"
#import "NSString+FileTasks.h"

#define CACHE_SIZE 3

@interface ImageTaskManager (Private)
-(id)evictImages;
-(void)doBuildIcon:(NSDictionary*)options;
-(void)doPreloadImage:(NSString*)path;
-(void)doDisplayImage:(NSString*)imageToDisplay;
-(BOOL)newDisplayCommandInQueue;
-(void)sendDisplayCommandWithImage:(NSImage*)image width:(int)width height:(int)height;
@end

@implementation ImageTaskManager

-(id)initWithPortArray:(NSArray*)portArray
{
	if(self = [super init])
	{
		pthread_mutex_init(&imageCacheLock, NULL);
		pthread_mutex_init(&taskQueueLock, NULL);
		pthread_cond_init(&conditionLock, NULL);
		
		imageCache = [[NSMutableDictionary alloc] init];
		thumbnailQueue = [[NSMutableArray alloc] init];
		preloadQueue = [[NSMutableArray alloc] init];
		
		// spawn off a new thread
		[NSThread detachNewThreadSelector:@selector(taskHandlerThread:) 
								 toTarget:self
							   withObject:portArray];
	}
	return self;
}

-(void)dealloc
{
	// shut down taskHandlerThread...
	
	// destroy our mutexes!
	pthread_mutex_destroy(&imageCacheLock);
	pthread_mutex_destroy(&taskQueueLock);
	pthread_cond_destroy(&conditionLock);
	
	// destroy our mutexed data!
	[imageCache release];
	[thumbnailQueue release];
	[preloadQueue release];
}

-(void)taskHandlerThread:(id)portArray
{
	NSDictionary* currentTask;
	
	// Okay, first we get the distributed object CQViewController up and running...
	NSAutoreleasePool *npool = [[NSAutoreleasePool alloc] init];
	NSConnection *serverConnection = [NSConnection
		connectionWithReceivePort:[portArray objectAtIndex:0]
						 sendPort:[portArray objectAtIndex:1]];
	
	cqViewController = [serverConnection rootProxy];
	[cqViewController setProtocolForProxy:@protocol(ImageDisplayer)];
	
	// Handle queue
	while(1)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Let's wait for stuff
		pthread_mutex_lock(&taskQueueLock);
		while(fileToDisplayPath == nil && [thumbnailQueue count] == 0 &&
			  [preloadQueue count] == 0)
		{
			if(pthread_cond_wait(&conditionLock, &taskQueueLock))
				NSLog(@"Invalid wait!?");
		}
		
		// Okay, taskQueueLock is locked. Let's try individual tasks.
		if(fileToDisplayPath != nil)
		{
			// Unlock the mutex
			NSString* path = [[fileToDisplayPath copy] autorelease];
			[fileToDisplayPath release];
			fileToDisplayPath = nil;
			pthread_mutex_unlock(&taskQueueLock);
			
			[self doDisplayImage:path];
		}
		else if([thumbnailQueue count])
		{
			NSDictionary* action = [[thumbnailQueue objectAtIndex:0] retain];
			[thumbnailQueue removeObjectAtIndex:0];
			pthread_mutex_unlock(&taskQueueLock);
			
			[self doBuildIcon:action];
			[action release];
		}
		else if([preloadQueue count])
		{
			NSString* path = [[preloadQueue objectAtIndex:0] retain];
			[preloadQueue removeObjectAtIndex:0];
			pthread_mutex_unlock(&taskQueueLock);
			
			[self doPreloadImage:path];
			[path release];
		}
		else
		{
			// Unlock the mutex
			pthread_mutex_unlock(&taskQueueLock);
		}

		[pool release];
	}
}

-(void)setScaleRatio:(float)newScaleRatio
{
	pthread_mutex_lock(&imageScalingProperties);
	scaleRatio = newScaleRatio;
	pthread_mutex_unlock(&imageScalingProperties);
}

-(void)setScaleProportionally:(BOOL)newScaleProportionally
{
	pthread_mutex_lock(&imageScalingProperties);
	scaleProportionally = newScaleProportionally;
	pthread_mutex_unlock(&imageScalingProperties);
}

-(void)setContentViewSize:(NSSize)newContentViewSize
{
	pthread_mutex_lock(&imageScalingProperties);
	contentViewSize = newContentViewSize;
	pthread_mutex_unlock(&imageScalingProperties);	
}

-(void)displayImageWithPath:(NSString*)path
{
	pthread_mutex_lock(&taskQueueLock);
	
	// Make this the NEXT thing we do.
	[fileToDisplayPath release];
	[path retain];
	fileToDisplayPath = path;
	
	// Note that we are OUT of here...
	pthread_cond_signal(&conditionLock);
	pthread_mutex_unlock(&taskQueueLock);
}

// fixme: make this function more intelligent so that it will remove items that
// are going to get thrown away anyway...
-(void)preloadImage:(NSString*)path
{	
	pthread_mutex_lock(&taskQueueLock);

	while([preloadQueue count] > CACHE_SIZE)
		[preloadQueue removeObjectAtIndex:0];
	
	// Add the object
	[preloadQueue addObject:path];
	
	// Note that we are OUT of here...
	pthread_cond_signal(&conditionLock);
	pthread_mutex_unlock(&taskQueueLock);
}

-(void)buildThumbnail:(NSString*)path forCell:(id)cell
{
	NSDictionary* currentTask = [NSDictionary dictionaryWithObjectsAndKeys:
		@"PreloadImage", @"Type", path, @"Path",
		cell, @"Cell", nil];
	
	pthread_mutex_lock(&taskQueueLock);
	//	NSLog(@"Going to preload: %@", path);
	// Add the object
	[thumbnailQueue addObject:currentTask];
	
	// Note that we are OUT of here...
	pthread_cond_signal(&conditionLock);
	pthread_mutex_unlock(&taskQueueLock);	
}

-(NSImage*)getCurrentImageWithWidth:(int*)width height:(int*)height
{
	if(width)
		*width = currentImageWidth;
	if(height)
		*height = currentImageHeight;
	
	return currentImage;
}

-(id)getCurrentThumbnailCell
{
	return currentIconCell;
}

-(NSImage*)getCurrentThumbnail
{
	return currentIconFamilyThumbnail;
}

@end

@implementation ImageTaskManager (Private)

-(id)evictImages
{
	// ASSUMPTION: imageCacheLock is ALREADY locked!
	if([imageCache count] > CACHE_SIZE)
	{
		NSString* oldestPath = nil;
		NSDate* oldestDate = [NSDate date]; // set oldest as now, so anything older
		
		NSEnumerator* e = [imageCache keyEnumerator];
		NSString* cur;
		while(cur = [e nextObject]) 
		{
			NSDictionary* cacheEntry = [imageCache objectForKey:cur];
			if([oldestDate compare:[cacheEntry objectForKey:@"Date"]] == NSOrderedDescending)
			{
				// this is older!
				oldestDate = [cacheEntry objectForKey:@"Date"];
				oldestPath = cur;
			}
		}
		
		// Let's get rid of the oldest path...
		[imageCache removeObjectForKey:oldestPath];
	}
}

-(void)doBuildIcon:(NSDictionary*)options
{
	NSString* path = [options objectForKey:@"Path"];
	NSImage* thumbnail;
	IconFamily* iconFamily;
	
	// Build the thumbnail and set it to the file...
	if([path isImage] && ![IconFamily fileHasCustomIcon:path])
	{
		NSImage* image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
		iconFamily = [IconFamily iconFamilyWithThumbnailsOfImage:image];
		[iconFamily setAsCustomIconForFile:path];
		thumbnail = [[iconFamily imageWithAllReps] retain];
	}
	else
	{
		thumbnail = [path iconImageOfSize:NSMakeSize(16, 16)];
	}
	
	currentIconFamilyThumbnail = thumbnail;
	currentIconCell = [options objectForKey:@"Cell"];
	[cqViewController setIcon];
}

-(void)doPreloadImage:(NSString*)path
{
	pthread_mutex_lock(&imageCacheLock);
	// If the image hasn't already been loaded into the cache...
	if(![imageCache objectForKey:path])
	{
		pthread_mutex_unlock(&imageCacheLock);
		// Preload the image
		NSImageRep* rep = [NSImageRep imageRepWithContentsOfFile:path];
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSDate date], @"Date", rep, @"Image", nil];

		pthread_mutex_lock(&imageCacheLock);
		[self evictImages];
		[imageCache setObject:dict forKey:path];
	}
	pthread_mutex_unlock(&imageCacheLock);	
}

-(void)doDisplayImage:(NSString*)path
{
	// Before we aquire our internal lock, tell the main application to start
	// spinning...
	[cqViewController startProgressIndicator];

	NSImageRep* imageRep;
	pthread_mutex_lock(&imageCacheLock);
	NSDictionary* cacheEntry = [imageCache objectForKey:path];
	
	// If the image isn't in the cache...
	if(!cacheEntry)
	{
		pthread_mutex_unlock(&imageCacheLock);
				
		// Load the file, since it obviously hasn't been loaded.
		imageRep = [NSImageRep imageRepWithContentsOfFile:path];
		cacheEntry = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSDate date], @"Date", imageRep, @"Image", nil];
		
		pthread_mutex_lock(&imageCacheLock);
		// Evict an old cache entry
		[self evictImages];
		
		// Add the image to the cache so subsquent hits won't require reloading...
		[imageCache setObject:cacheEntry forKey:path];
	}
//	else
//		NSLog(@"Using cached version of '%@'", path);
	
	imageRep = [cacheEntry objectForKey:@"Image"];
	
	// Unlock the image cache. We don't need it anymore...
	pthread_mutex_unlock(&imageCacheLock);	

	// Check to see if we should go on. Has someone made a different request
	// in the time where we've been loading the image?
	if([self newDisplayCommandInQueue])
		return;
	
	// Now we start with the resizing procedure

	// We need to lock during the reading of the following properties...
	NSSize sizeOfDisplayBox;
	BOOL canScaleProportionally;
	float ratioToScale;
	pthread_mutex_lock(&imageScalingProperties);
	sizeOfDisplayBox = contentViewSize;
	canScaleProportionally = scaleProportionally;
	ratioToScale = scaleRatio;
	pthread_mutex_unlock(&imageScalingProperties);

	int imageX = [imageRep pixelsWide];
	int imageY = [imageRep pixelsHigh];
	int displayBoxWidth = sizeOfDisplayBox.width;
	int displayBoxHeight = sizeOfDisplayBox.height;
	
//	NSSize buildImageSize(int boxWidth, int boxHeight, int imageWidth, int imageHeight,
//						  BOOL canScaleProportionally, float ratioToScale,
//						  BOOL*canGetAwayWithQuickRender);
	BOOL canGetAwayWithQuickRender;	
	struct DS display = buildImageSize(displayBoxWidth, displayBoxHeight, imageX, 
									   imageY, canScaleProportionally, ratioToScale,
									   &canGetAwayWithQuickRender);
	
	NSLog(@"Image:[%d, %d] Dispaly:[%d, %d]", imageX, imageY, display.width, display.height);
	
	NSImage* imageToRet;
	if(imageRepIsAnimated(imageRep) || canGetAwayWithQuickRender)
	{
		// Draw the image by just making an NSImage from the imageRep. This is
		// done when the image will fit in the viewport, or when we are 
		// rendering an animated GIF.
		imageToRet = [[[NSImage alloc] init] autorelease];
		[imageToRet addRepresentation:imageRep];
		
		// Scale it anyway, because some pictures LIE about their size.
		[imageToRet setScalesWhenResized:YES];
		[imageToRet setSize:NSMakeSize(display.width, display.height)];
		
		[imageToRet retain];
		[self sendDisplayCommandWithImage:imageToRet width:imageX height:imageY];
		[imageToRet release];
	}
	else
	{
		// First, we draw the image with no interpolation, and send that representation
		// to the screen for SPEED so it LOOKS like we are doing something.
		imageToRet = [[[NSImage alloc] initWithSize:NSMakeSize(display.width,
			display.height)] autorelease];
		[imageToRet lockFocus];
		{
			[[NSGraphicsContext currentContext] 
				setImageInterpolation:NSImageInterpolationNone];
			[imageRep drawInRect:NSMakeRect(0,0,display.width,display.height)];
		}
		[imageToRet unlockFocus];		
		[self sendDisplayCommandWithImage:imageToRet width:imageX height:imageY];
		
		// Now give us a chance to BAIL if we've already been given another display
		// command
		if([self newDisplayCommandInQueue])
			return;
		
		// Draw the image onto a new NSImage using smooth scaling. This is done
		// whenever the image isn't animated so that the picture will have 
		// some antialiasin lovin' applied to it.
		imageToRet = [[[NSImage alloc] initWithSize:NSMakeSize(display.width,
			display.height)] autorelease];
		[imageToRet lockFocus];
		{
			[[NSGraphicsContext currentContext] 
				setImageInterpolation:NSImageInterpolationHigh];
			[imageRep drawInRect:NSMakeRect(0,0,display.width,display.height)];
		}
		[imageToRet unlockFocus];
		
		// Now display the final image:
		[self sendDisplayCommandWithImage:imageToRet width:imageX height:imageY];
	}
	
	// An image has been displayed so stop the spinner
	[cqViewController stopProgressIndicator];	
}

-(BOOL)newDisplayCommandInQueue
{
	BOOL retVal = NO;
	pthread_mutex_lock(&taskQueueLock);
	retVal = fileToDisplayPath != nil;
	pthread_mutex_unlock(&taskQueueLock);
	return retVal;
}

-(void)sendDisplayCommandWithImage:(NSImage*)image width:(int)width height:(int)height
{
	[currentImage release];
	[image retain];
	currentImage = image;
	
	currentImageWidth = width;
	currentImageHeight = height;
	
	[cqViewController displayImage];
}

@end