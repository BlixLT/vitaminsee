//
//  ThumbnailManager.m
//  VitaminSEE
//
//  Created by Elliot Glaysher on 11/26/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ThumbnailManager.h"
#import "NSObject+Invocations.h"
#import "EGPath.h"
#import "IconFamily.h"
#import "FileList.h"

@interface ThumbnailManager (Private)
+(void)addThumbnailToCache:(NSImage*)image file:(EGPath*)path;
+(NSImage*)buildThumbnail:(EGPath*)path;
+(EGPath*)getNextThumbnailToBuild;
+(EGPath*)getNextPriorityBuild;
+(void)removePathFromBuildQueue:(EGPath*)path;
+(void)notifySubscribersThat:(EGPath*)nextToBuild hasImage:(NSImage*)image;

+(void)resetBuildQueueEnumerator;
+(void)resetPriorityQueueEnumerator;

+(void)doBuildThumbnailIconFor:(EGPath*)path;
@end

static NSSize ICON_SIZE = {128.0f, 128.0f};

/** Subscriber List:
 * {
 *   'directory' => [
 *     SUBSCRIBER1, SUBSCRIBER2  
 *   ]
 * }
 */
pthread_mutex_t subscriberListLock;
static NSMutableDictionary* subscriberList;

/** Thumbnail Cache Index:
 * {
 *   'directory' => {
 *       'file' => NSImage, 'file' =>, NSImage
 *   }
 * }
 */
pthread_rwlock_t thumbnailCacheLock;
static NSMutableDictionary* thumbnailCache;

/** Thumbnail Build Queue:
 * {
 *   'dir' => Set[
 *     EGPATH, EGPATH
 *   ],
 *   'dir' => Set[
 *     EGPATH, EGPATH
 *   ]
 * }
 */
pthread_mutex_t thumbnailBuildQueueLock;
pthread_cond_t thumbnailBuildQueueCondition;
static NSEnumerator* thumbnailBuildQueueValueEnumerator;
static NSMutableDictionary* thumbnailBuildQueue;

/** Thumbnail Priority Build Stack:
 * {
 *   'dir' => [
 *     EGPATH, EGPATH
 *   ],
 *   'dir' => [
 *     EGPATH, EGPATH
 *   ]
 * }
 *
 * The Priority Build Stacks are first-in-last-out structures; the idea being
 * that if a thumbnail was requested recently, it probably wasn't just scrolled
 * by.
 */
static NSEnumerator* thumbnailPriorityBuildEnumerator;
static NSMutableDictionary* thumbnailPriorityBuildStack;

// Configuration stuff
//static BOOL shouldBuildThumbnails;

enum ThumbnailStorageType {
	THUMBNAILSTORAGE_DONT_STORE,
	THUMBNAILSTORAGE_STORE_RESOURCEFORK
};
static enum ThumbnailStorageType thumbnailStorageType;

@implementation ThumbnailManager

+(void)initialize
{
	thumbnailStorageType = THUMBNAILSTORAGE_STORE_RESOURCEFORK;
	
	pthread_mutex_init(&subscriberListLock, NULL);
	subscriberList = [[NSMutableDictionary alloc] init];
	
	pthread_rwlock_init(&thumbnailCacheLock, NULL);
	thumbnailCache = [[NSMutableDictionary alloc] init];
	
	pthread_mutex_init(&thumbnailBuildQueueLock, NULL);
	pthread_cond_init(&thumbnailBuildQueueCondition, NULL);
	thumbnailBuildQueue = [[NSMutableDictionary alloc] init];
	thumbnailPriorityBuildStack = [[NSMutableDictionary alloc] init];
	thumbnailBuildQueueValueEnumerator = 0;
	
	// Subscribe to updates to the main notification of changes to user defaults
	// and alert 
	// FIXME: TODO
	
	
	// Spawn off the worker thread.
	[NSThread detachNewThreadSelector:@selector(taskHandlerThread:)
							 toTarget:[ThumbnailManager class]
						   withObject:nil];
}

//-----------------------------------------------------------------------------

+(void)taskHandlerThread:(id)nothing
{	
	NSAutoreleasePool* npool = [[NSAutoreleasePool alloc] init];
	
	// Don't delude ourselves. We're not as important as displaying images
	[NSThread setThreadPriority:0.2];
	
	// Handle queue
	while(1)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Let's wait for stuff
		pthread_mutex_lock(&thumbnailBuildQueueLock);
		while([thumbnailBuildQueue count] == 0 &&
			  [thumbnailPriorityBuildStack count] == 0)
		{
			if(pthread_cond_wait(&thumbnailBuildQueueCondition,
								 &thumbnailBuildQueueLock))
				NSLog(@"Invalid wait!?");
		}
		
		if([thumbnailPriorityBuildStack count])
		{
			EGPath* nextToBuild = [[self getNextPriorityBuild] retain];
			
			// Unlock the mutex
			pthread_mutex_unlock(&thumbnailBuildQueueLock);
		
			[self doBuildThumbnailIconFor:nextToBuild];
			[nextToBuild release];
		}
		else if([thumbnailBuildQueue count])
		{
			// Object retained because it gets released during
			// -addThumbnailToCache:file:
			EGPath* nextToBuild = [[self getNextThumbnailToBuild] retain];

			// Unlock the mutex
			pthread_mutex_unlock(&thumbnailBuildQueueLock);

			[self doBuildThumbnailIconFor:nextToBuild];
			[nextToBuild release];
		}
		else
		{
			// Unlock the mutex
			pthread_mutex_unlock(&thumbnailBuildQueueLock);
		}
		
		[pool release];
	}
	
	[npool release];
}

//-----------------------------------------------------------------------------

+(void)subscribe:(id)object toDirectory:(EGPath*)directory
{
	pthread_mutex_lock(&subscriberListLock);
	{
		NSMutableArray* subscribers = [subscriberList objectForKey:directory];
		
		// Check to see if anybody is subscribed (meaning that there's an array
		// of subscribers associated with this directory)
		if(subscribers)
		{
			// Check to see if this object is already subscribed.
			if(![subscribers containsObject:object])
				[subscribers addObject:object];
		}
		else
		{
			// Nobody is subscribed to this directory. Build all the data 
			// structures for this directory.
			
			// Build a subscription object
			[subscriberList setObject:[NSMutableArray arrayWithObject:object]
							   forKey:directory];

			// Build the thumbnail cache
			pthread_rwlock_wrlock(&thumbnailCacheLock);
			{
				[thumbnailCache setObject:[NSMutableDictionary dictionary]
								   forKey:directory];
			}
			pthread_rwlock_unlock(&thumbnailCacheLock);
			
			// Build the set of files that need to have thumbnails generated.
			NSArray* files = [directory directoryContents];
			NSSet* buildSet = [NSMutableSet setWithArray:files];
			pthread_mutex_lock(&thumbnailBuildQueueLock);
			{
				[thumbnailBuildQueue setObject:buildSet forKey:directory];
				[self resetBuildQueueEnumerator];
			}
			pthread_mutex_unlock(&thumbnailBuildQueueLock);
			
			// Notify the thumbnail thread that it has work to do.
			pthread_cond_signal(&thumbnailBuildQueueCondition);
		}
	}
	pthread_mutex_unlock(&subscriberListLock);
}

//-----------------------------------------------------------------------------

+(void)unsubscribe:(id)object fromDirectory:(EGPath*)directory
{
//	NSLog(@"%@ is unsubscribed to %@", object, directory);
	pthread_mutex_lock(&subscriberListLock);
	{
		// Make sure that we are unsubscribing from a directory that somebody
		// (us) has subscribed to
		NSMutableArray* subscribers = [subscriberList objectForKey:directory];
		if(subscribers && [subscribers containsObject:object]) 
		{
			// Remove object from the list of subscribers, and check to see if
			// we need to destroy all the data structures for this directory
			// since nobody is subscribed to it anymore.
			[subscribers removeObject:object];
			if([subscribers count] == 0)
			{
				NSLog(@"Removing all data structures for %@", directory);
				// Subscribers is now invalid.
				[subscriberList removeObjectForKey:directory];
				subscribers = 0;
				
				pthread_rwlock_wrlock(&thumbnailCacheLock);
				{
					[thumbnailCache removeObjectForKey:directory];
				}
				pthread_rwlock_unlock(&thumbnailCacheLock);
				
				pthread_mutex_lock(&thumbnailBuildQueueLock);
				{	
					[thumbnailBuildQueue removeObjectForKey:directory];
					[self resetBuildQueueEnumerator];
				}
				pthread_mutex_unlock(&thumbnailBuildQueueLock);
			}
		}
	}
	pthread_mutex_unlock(&subscriberListLock);
}

//-----------------------------------------------------------------------------

+(NSImage*)getThumbnailFor:(EGPath*)path
{
	// First check to see if the thumbnail is in the cache. If it is not, do
	// the loading ourselves...
	NSImage* thumbnail;
	NSMutableDictionary* directoryCache;
	EGPath* dirPath = [path pathByDeletingLastPathComponent];
	pthread_rwlock_rdlock(&thumbnailCacheLock);
	{
		directoryCache = [thumbnailCache objectForKey:dirPath];
	}	
	pthread_rwlock_unlock(&thumbnailCacheLock);

	thumbnail = [directoryCache objectForKey:path];
	// Return the image if we found it in the cache
	if(thumbnail)
		return thumbnail;
	
	// So the image isn't in the cache yet. 
	NSImage* image = [path iconImageOfSize:ICON_SIZE];
	if([path isImage]) 
	{
		if([path hasThumbnailIcon])
		{
			if(directoryCache)
			{
				pthread_rwlock_wrlock(&thumbnailCacheLock);
				{
					[directoryCache setObject:image forKey:path];
				}	
				pthread_rwlock_unlock(&thumbnailCacheLock);		
			}
		}
		else
		{
			// If this is an image, but doesn't have a thumbnail, put it in the
			// priority thumbnail build stack, so it gets generated ASAP.
			pthread_mutex_lock(&thumbnailBuildQueueLock);
			{
				NSMutableArray* stack = [thumbnailPriorityBuildStack 
					objectForKey:dirPath];
				
				// We may need to build the stack for this directory
				if(!stack)
				{
					stack = [NSMutableArray array];
					[thumbnailPriorityBuildStack setObject:stack 
													forKey:dirPath];
					[self resetPriorityQueueEnumerator];
				}
				
				[stack addObject:path];			
			}
			pthread_mutex_unlock(&thumbnailBuildQueueLock);
			
			// Notify the thumbnail thread that it has work to do.
			pthread_cond_signal(&thumbnailBuildQueueCondition);
		}
	}
	
	return image;
}

//-----------------------------------------------------------------------------

@end

//-----------------------------------------------------------------------------

@implementation ThumbnailManager (Private)

//-----------------------------------------------------------------------------

/** Adds an image to the cache and removes it from the build queue.
 */
+(void)addThumbnailToCache:(NSImage*)image file:(EGPath*)path
{
	if(image)
	{
		EGPath* directory = [path pathByDeletingLastPathComponent];

		// Add the image to the cache!
		pthread_rwlock_wrlock(&thumbnailCacheLock);
		{
			NSMutableDictionary* dict = [thumbnailCache objectForKey:directory];		
			[dict setObject:image forKey:path];
		}
		pthread_rwlock_unlock(&thumbnailCacheLock);
	}
	
	// Note that whether we remove the path from the build queue is independent
	// of whether a valid thumbnail was generated. If it fails once, it's 
	// probably going to keep on failing.
	[self removePathFromBuildQueue:path];
}

//-----------------------------------------------------------------------------

+(void)removePathFromBuildQueue:(EGPath*)path
{
	EGPath* directory = [path pathByDeletingLastPathComponent];
	
	// Remove this image from the build queue
	pthread_mutex_lock(&thumbnailBuildQueueLock);
	{
		NSMutableSet* buildSet = [thumbnailBuildQueue objectForKey:directory];
		
		if(buildSet) {
			// Remove the object if it exists
			if([buildSet member:path])
				[buildSet removeObject:path];
			
			// Clean up the the set if if's emtpy
			if([buildSet count] == 0)
				[thumbnailBuildQueue removeObjectForKey:directory];
		}
	}
	pthread_mutex_unlock(&thumbnailBuildQueueLock);
}

//-----------------------------------------------------------------------------

/** Builds a thumbnail (checking with the ImageLoader's cache 
 */
+(NSImage*)buildThumbnail:(EGPath*)path
{
	// I don't think there IS an autorelease...
	NSData* data = [path dataRepresentationOfPath];
	//[[NSData alloc] initWithContentsOfFile:path];
	if(!data) 
	{
		NSLog(@"WARNING! Couldn't load file %@ so we could make a thumbnail...", path);
		return 0;
	}
	NSImage* image = [[NSImage alloc] initWithData:data];
	[data release];
	if(!image) 
	{
		NSLog(@"WARNING! Couldn't make an image from the data in %@ so we could make a thumbnail...", path);
		return 0;
	}
	
	// Set icon
	IconFamily* iconFamily = [[IconFamily alloc] initWithThumbnailsOfImage:image];
	NSImage* thumbnail;
	if(iconFamily)
	{
		if([path isNaturalFile]) // && shouldSaveIconToDisk)
		{
//			NSLog(@"Setting the thumbnail for %@", path);
			[iconFamily setAsCustomIconForFile:[path fileSystemPath]];
		}
		
		thumbnail = [iconFamily imageWithAllRepsNoAutorelease];
		//		NSLog(@"Found thumbnail: %@", thumbnail);
		[iconFamily release];
	}
	else
		NSLog(@"Couldn't build iconFamily for %@!", path);
	
	[image release];
	return thumbnail;
}

//-----------------------------------------------------------------------------

/** Get the next queue from the enumerator, starting over if we're
 * at the end of the enumerated list. Then get the next file from
 * that build queue.
 */
+(EGPath*)getNextThumbnailToBuild
{
	EGPath* nextToBuild;
	NSSet* buildQueue = [thumbnailBuildQueueValueEnumerator nextObject];
	if(!buildQueue) {
		[self resetBuildQueueEnumerator];
		buildQueue = [thumbnailBuildQueueValueEnumerator nextObject];
	}
	
	NSEnumerator* e = [buildQueue objectEnumerator];
	nextToBuild = [e nextObject];
	
	return nextToBuild;
}

//-----------------------------------------------------------------------------

/** Get the next priority build task, removing any exhausted build stacks as
 * neccessary.
 */
+(EGPath*)getNextPriorityBuild
{
	// Get the next build stack
//	EGPath* nextToBuild;
	NSMutableArray* buildStack = [thumbnailPriorityBuildEnumerator nextObject];
	if(!buildStack) {
		[self resetPriorityQueueEnumerator];
		buildStack = [thumbnailPriorityBuildEnumerator nextObject];
	}

	EGPath* ret = [[buildStack lastObject] retain];

	// If we got an actual object off the stack, then remove it from the stack
	// and check to see if we should remove the stack from rotation if it's
	// empty.
	if(ret)
	{
		[buildStack removeLastObject];
	
		if([buildStack count] == 0)
		{
			[thumbnailPriorityBuildStack removeObjectForKey:
				[ret pathByDeletingLastPathComponent]];
			[self resetPriorityQueueEnumerator];
		}
	}
	return [ret autorelease];	
}

//-----------------------------------------------------------------------------

+(void)resetBuildQueueEnumerator
{
	[thumbnailBuildQueueValueEnumerator release];
	thumbnailBuildQueueValueEnumerator = 
		[[thumbnailBuildQueue objectEnumerator] retain];				
}

//-----------------------------------------------------------------------------

+(void)resetPriorityQueueEnumerator
{
	[thumbnailPriorityBuildEnumerator release];
	thumbnailPriorityBuildEnumerator = 
		[[thumbnailPriorityBuildStack objectEnumerator] retain];
}

//-----------------------------------------------------------------------------

+(void)notifySubscribersThat:(EGPath*)nextToBuild hasImage:(NSImage*)image
{
	EGPath* directory = [nextToBuild pathByDeletingLastPathComponent];
	
	pthread_mutex_lock(&subscriberListLock);
	{
		NSMutableArray* subscribers = 
			[subscriberList objectForKey:directory];
		
		NSEnumerator* e = [subscribers objectEnumerator];
		id subscriber;
		while(subscriber = [e nextObject]) 
		{
			[[subscriber performOnMainThreadWaitUntilDone:NO]
				receiveThumbnail:image forFile:nextToBuild];
		}
	}
	pthread_mutex_unlock(&subscriberListLock);
}

//-----------------------------------------------------------------------------

+(void)doBuildThumbnailIconFor:(EGPath*)nextToBuild
{
	if([nextToBuild isImage]) 
	{
		NSImage* image;
		
		// Check to see if this file has an icon. (Make sure to do
		// it on the main thread; the Carbon Resource Manager isn't
		// thread safe!)
		if([[nextToBuild performOnMainThreadWaitUntilDone:YES] 
			hasThumbnailIcon])
		{
			// If there's already an thumbnail, load it and put it in 
			// the cache
			image = [nextToBuild iconImageOfSize:ICON_SIZE];
			[self addThumbnailToCache:image file:nextToBuild];
		}
		else 
		{
			// Build the new image for the file and stick it in the 
			// cache
			image = [self buildThumbnail:nextToBuild];
			[self addThumbnailToCache:image file:nextToBuild];
			[image release];
		}
		
		// Notify all people in the subscribers list
		[self notifySubscribersThat:nextToBuild hasImage:image];
	}
	else
	{
		// Remove the entry from the build queue. 
		[self removePathFromBuildQueue:nextToBuild];
	}	
}

@end
