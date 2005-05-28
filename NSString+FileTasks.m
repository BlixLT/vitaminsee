/////////////////////////////////////////////////////////////////////////
// File:          $Name$
// Module:        NSString additions. Most of these are from Apple, but some are
//                mine.
// Part of:       VitaminSEE
//
// Revision:      $Revision$
// Last edited:   $Date$
// Author:        $Author$
// Copyright:     (c) 2005 Elliot Glaysher
// Created:       2/9/05
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
//
// IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
// consideration of your agreement to the following terms, and your use, installation, 
// modification or redistribution of this Apple software constitutes acceptance of these 
// terms.  If you do not agree with these terms, please do not use, install, modify or 
// redistribute this Apple software.
// 
// In consideration of your agreement to abide by the following terms, and subject to these 
// terms, Apple grants you a personal, non-exclusive license, under Apple’s copyrights in 
// this original Apple software (the "Apple Software"), to use, reproduce, modify and 
// redistribute the Apple Software, with or without modifications, in source and/or binary 
// forms; provided that if you redistribute the Apple Software in its entirety and without 
// modifications, you must retain this notice and the following text and disclaimers in all 
// such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
// or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
// the Apple Software without specific prior written permission from Apple. Except as expressly
// stated in this notice, no other rights or licenses, express or implied, are granted by Apple
// herein, including but not limited to any patent rights that may be infringed by your 
// derivative works or by other works in which the Apple Software may be incorporated.
// 
// The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
// EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
// USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
// 
// IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
//		  OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
// REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
// WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
// OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
////////////////////////////////////////////////////////////////////////

#import "NSString+FileTasks.h"

static NSArray* hiddenFiles = 0;
static NSArray* fileExtensions = 0;

@implementation NSString (FileTasks)

-(BOOL)isDir
{
	// fixme: Think about replacing this with an lstat based line for even more speed...
	BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:self
													   isDirectory:&isDir];
    return (exists && isDir);
}

-(BOOL)isImage
{
	if(!fileExtensions)
		fileExtensions = [[NSImage imageUnfilteredFileTypes] retain];

	return [fileExtensions containsObject:[self pathExtension]]; 
		
	//[	NSLog(@"File: %@", );
	//	NSString *fileExtentsion = [[self pathExtension] uppercaseString];
//	return [fileExtentsion isEqualToString:@"PNG"] || 
//		[fileExtentsion isEqualToString:@"JFIF"] ||
//		[fileExtentsion isEqualToString:@"JPEG"] ||
//		[fileExtentsion isEqualToString:@"JPG"] || 
//		[fileExtentsion isEqualToString:@"GIF"] ||
//		[fileExtentsion isEqualToString:@"TIF"] ||
//		[fileExtentsion isEqualToString:@"TIFF"] ||
//		[fileExtentsion isEqualToString:@"BMP"] ||
//		[fileExtentsion isEqualToString:@"ICNS"] ||
//		[fileExtentsion isEqualToString:@"PDF"] ||
//		[fileExtentsion isEqualToString:@"PSD"] ||
//		[fileExtentsion isEqualToString:@"TGA"];
}

-(BOOL)isVisible
{
	if(!hiddenFiles)
		hiddenFiles = [[NSArray arrayWithObjects:@".vol", @"automount",
			@"bin", @"cores", @"Desktop DB", @"Desktop DF", @"Desktop Folder", @"dev",
			@"etc", @"lost+found", @"mach", @"mach_kernel", @"mach.sym", @"opt",
			@"private", @"sbin", @"tmp", @"Trash", @"usr", @"var", @"VM Storage",
			@"Volumes", nil] retain];
	
	// Make this as sophisticated for example to hide more files you don't think the user should see!
    NSString *lastPathComponent = [self lastPathComponent];
	NSString *curDir = [self stringByDeletingLastPathComponent];

	BOOL shouldHide = NO;
	if([curDir isEqual:@"/"])
		shouldHide = [hiddenFiles containsObject:lastPathComponent];

	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"ShowHiddenFiles"]
		boolValue])
		return YES;
	else
		return !shouldHide && ([lastPathComponent length] ? ([lastPathComponent characterAtIndex:0]!='.') : NO);
}

-(BOOL)isReadable
{
	return [[NSFileManager defaultManager] isReadableFileAtPath:self];
}

- (BOOL)isLink 
{
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] 
		fileAttributesAtPath:self traverseLink:NO];
    return [[fileAttributes objectForKey:NSFileType] 
		isEqualToString:NSFileTypeSymbolicLink];
}

-(int)fileSize
{
	return [[[[NSFileManager defaultManager] 
		fileAttributesAtPath:self 
				traverseLink:YES] objectForKey:NSFileSize] intValue];
}

// We don't return an autoreleased NSImage since autoreleased things don't seem
// to be released properly across threads.
//
// 4/16: The previous comment doesn't make sense. Was I drunk when I wrote that?
- (NSImage*)iconImageOfSize:(NSSize)size {
    NSString *path = self;
    NSImage *nodeImage = nil;
    
    nodeImage = [[NSWorkspace sharedWorkspace] iconForFile:path];
    if (!nodeImage) {
        // No icon for actual file, try the extension.
        nodeImage = [[NSWorkspace sharedWorkspace] iconForFileType:[path pathExtension]];
    }
    [nodeImage setSize: size];
    
    if ([self isLink]) {
        NSImage *arrowImage = [NSImage imageNamed: @"FSIconImage-LinkArrow"];
        NSImage *nodeImageWithArrow = [[[NSImage alloc] initWithSize: size] autorelease];
        
		[arrowImage setScalesWhenResized: YES];
		[arrowImage setSize: size];
		
        [nodeImageWithArrow lockFocus];
		[nodeImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
        [arrowImage compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
        [nodeImageWithArrow unlockFocus];
		
		nodeImage = nodeImageWithArrow;
    }
    
    if (nodeImage==nil) {
        nodeImage = [NSImage imageNamed:@"FSIconImage-Default"];
    }
    
    return nodeImage;
}

@end
