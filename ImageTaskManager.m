//
//  ImageTaskManager.m
//  CQView
//
//  Created by Elliot on 2/7/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "ImageTaskManager.h"

#import "IconFamily.h"


@implementation ImageTaskManager

-(id)init
{
	if(self = [super init])
	{
		pthread_mutex_init(&taskQueueLock, NULL);
		pthread_mutex_init(&imageCacheLock, NULL);
		pthread_cond_init(&conditionLock, NULL);
		
		imageCache = [[NSMutableDictionary alloc] init];
		taskQueue = [[NSMutableArray alloc] init];
		
		// spawn off a new thread
		[NSThread detachNewThreadSelector:@selector(taskHandlerThread:) 
								 toTarget:self
							   withObject:nil];
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
	[taskQueue release];
}

-(void)taskHandlerThread:(id)incoming
{
	NSDictionary* currentTask;
	// Handle queue
	while(1)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		// Let's wait for stuff
		pthread_mutex_lock(&taskQueueLock);
		while([taskQueue count] == 0)
		{
			if(pthread_cond_wait(&conditionLock, &taskQueueLock))
				NSLog(@"Invalid wait!?");
		}

		NSLog(@"There are %i pending tasks", [taskQueue count]);
		NSLog(@"The queue state is %@", taskQueue);
		// Get a task out of our task queue...
		currentTask = [[taskQueue objectAtIndex:0] retain];
		[taskQueue removeObjectAtIndex:0];

		NSLog(@"The current task is %@", currentTask);
		// what kind of task is this?
		NSString* type = [currentTask objectForKey:@"Type"];
		NSString* path = [currentTask objectForKey:@"Path"];
		pthread_mutex_unlock(&taskQueueLock);
		
		if([type isEqual:@"BuildIcon"])
		{
			// Build an icon for this file.
			NSImage* image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
			IconFamily* iconFamily = [IconFamily iconFamilyWithThumbnailsOfImage:image];
			[iconFamily setAsCustomIconForFile:path];
			
			// We need some kind of way to tell if this completed!
		}
		else if([type isEqual:@"PreloadImage"])
		{
			[self doPreloadImage:path];
			// Load the ImageRep into the
			// [self evictOldImage];
		}
		else
			NSLog(@"WARNING! I don't know how to do task type '%@'", type);

		[currentTask release];
		[pool release];
	}
}

-(void)preloadImage:(NSString*)path
{	
	pthread_mutex_lock(&imageCacheLock);
	NSDictionary* currentTask = [NSDictionary dictionaryWithObjectsAndKeys:
		@"PreloadImage", @"Type", path, @"Path", nil];

	// Add the object
	[taskQueue addObject:currentTask];
	NSLog(@"Adding task %@", currentTask);
	
	// Note that we are OUT of here...
	pthread_cond_signal(&conditionLock);
	pthread_mutex_unlock(&imageCacheLock);
}

-(NSImageRep*)getImage:(NSString*)path
{
	NSImageRep* imageRep;
	pthread_mutex_lock(&imageCacheLock);
	NSDictionary* cacheEntry = [imageCache objectForKey:path];
	
	// If the image isn't in the cache...
	if(!cacheEntry)
	{
		NSLog(@"ImageRep wasn't there, but there are %i cache entries", [imageCache count]);

		// Load the file, since it obviously hasn't been loaded.
		imageRep = [NSImageRep imageRepWithContentsOfFile:path];
		cacheEntry = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSDate date], @"Date", imageRep, @"Image", nil];
				
		// Evict an old cache entry
		[self evictImages];
		
		// Add the image to the cache so subsquent hits won't require reloading...
		[imageCache setObject:cacheEntry forKey:path];
	}
	else
		NSLog(@"%@ was in the cache", path);
	
	imageRep = [cacheEntry objectForKey:@"Image"];
	
	// Unlock so braindeadness doesn't occur.
	pthread_mutex_unlock(&imageCacheLock);
	return imageRep;
}

@end

@implementation ImageTaskManager (Private)

-(id)evictImages
{
	// ASSUMPTION: imageCacheLock is ALREADY locked!
	if([imageCache count] > 5)
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

-(void)doPreloadImage:(NSString*)path
{
	pthread_mutex_lock(&imageCacheLock);
	// If the image hasn't already been loaded into the cache...
	if(![imageCache objectForKey:path])
	{
		NSLog(@"Starting to Preload %@", path);		
		// Preload the image
		NSImageRep* rep = [NSImageRep imageRepWithContentsOfFile:path];
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSDate date], @"Date", rep, @"Image", nil];

		[self evictImages];
		[imageCache setObject:dict forKey:path];
		NSLog(@"Finished Preloading %@", path);
	}
	pthread_mutex_unlock(&imageCacheLock);	
}

@end