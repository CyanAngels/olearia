//
//  TBStdFormats.m
//  stdDaisyFormats
//
//  Created by Kieren Eaton on 13/04/09.
//  Copyright 2009 BrainBender Software. All rights reserved.
//
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "TBStdFormats.h"
#import "DTB202BookPlugin.h"
#import "DTB2002BookPlugin.h"
#import "DTB2005BookPlugin.h"
#import "TBBooksharePlugin.h"
#import "TBNIMASPlugin.h"
#import "TBNavigationController.h"

static NSBundle* pluginBundle = nil;

@interface TBStdFormats()
- (NSMutableArray *)insertIntoArray:(NSArray *)anArray;

@end


@implementation TBStdFormats

+ (BOOL)initializeClass:(NSBundle*)theBundle 
{		
	if (pluginBundle) 
	{
		// return no if the plugin is already instantiated
		return NO;
	}
	
	pluginBundle = [theBundle retain];
	return YES;
}

+ (void)terminateClass 
{
	// sanity check to see that the bundle is instantiated before we release it 
 	if (pluginBundle) 
	{
		[pluginBundle release];
		pluginBundle = nil;
	}
}



+ (NSArray *)plugins 
{
	NSMutableArray* plugs = [[[NSMutableArray alloc] init] autorelease];
	
	plugs = [[DTB202BookPlugin bookType] insertIntoArray:plugs];
	plugs = [[DTB2002BookPlugin bookType] insertIntoArray:plugs];
	plugs = [[DTB2005BookPlugin bookType] insertIntoArray:plugs];
	plugs = [[TBBooksharePlugin bookType] insertIntoArray:plugs];
	plugs = [[TBNIMASPlugin bookType] insertIntoArray:plugs];
	
	return [plugs count] ? plugs : nil;
}

+ (id)bookType
{
	// subclasses will return an instance of themselves via this method
	NSLog(@"Super Class %@ used instead of subclass",[self className]);
	return nil;	
}

- (id)variantOfType
{
	// plugins that are variants of standard types will return their superclass here 
	// for the concrete subclasses they will use this superclass method
	return nil;
}

- (NSView *)textView;
{
	return nil;
}

- (NSView *)bookInfoView;
{
	// check if we should load the view nib
	if(!infoView)
		if (![NSBundle loadNibNamed:@"InformationView" owner:self]) 
			return nil;

	return infoView;
}

- (void)updateInfoFromPlugin:(TBStdFormats *)aPlugin
{
	[infoView updateInfoFromPlugin:aPlugin];
}

- (NSString *)FormatDescription
{
	return NSLocalizedString(@"No Book Format Description",@"No Book Format Description");
}

- (BOOL)canOpenBook:(NSURL *)bookURL;
{
	NSLog(@"Super Class method %@ in Class %@ used instead of subclass method",@selector(_cmd),[self className]);
	return NO;
}

- (void)reset
{
	if(navCon)
		[navCon resetController];
}

- (BOOL)openBook:(NSURL *)bookURL
{
	NSLog(@"Super Class method %@ in Class %@ used instead of subclass method",@selector(_cmd),[self className]);
	return NO;
}

- (NSXMLNode *)infoMetadataNode
{
#ifdef DEBUG
	NSLog(@"Super Class method infoMetadataNode in Class %@ used instead of subclass method",[self className]);
#endif
	return nil;
}

- (BOOL)processMetadata
{
#ifdef DEBUG	
	NSLog(@"Super Class method processMetadata in Class %@ used instead of subclass method",[self className]);
#endif
	return NO;
}

- (void)startPlayback
{	
	bookData.isPlaying = YES;
}

- (void)stopPlayback
{	
	bookData.isPlaying = NO;
}

- (NSURL *)loadedURL
{
#ifdef DEBUG	
	NSLog(@"Super Class method loadedURL in Class %@ used instead of subclass method",[self className]);
#endif
	return nil;
}

#pragma mark - 
#pragma mark Navigation

- (void)moveToControlPosition:(NSString *)aNodePath
{
	// dummy method
#ifdef DEBUG	
	NSLog(@"Super Class method moveToPosition in Class %@ used instead of subclass method",[self className]);
#endif
}

- (NSString *)currentControlPosition
{
	// return an empty node string by default
	return @"";
}

- (void)nextReadingElement
{
	[navCon nextElement];
}
- (void)previousReadingElement
{
	[navCon previousElement];
}

- (void)upLevel
{
	[navCon goUpLevel];
}

- (void)downLevel
{
	[navCon goDownLevel];
}

#pragma mark -
#pragma mark Private Methods

- (NSMutableArray *)insertIntoArray:(NSArray *)anArray
{
	NSMutableArray *currentTypes = [NSMutableArray arrayWithArray:anArray];
	// check if the type is a variant of another type (possibly Standard Type)
	if([self variantOfType])
	{	
		[currentTypes insertObject:self atIndex:0];
	}
	else
	{
		// not a variant so just ad it to the end of the array as long as its not nil
		if(self)
			[currentTypes addObject:self];
	}
	
	return currentTypes;
}

- (void)setupPluginSpecifics
{ /* Dummy Method Placeholder */}



- (id) init
{
	if(!(self = [super init])) return nil;
	
	bookData = [TBSharedBookData sharedInstance];
	fileUtils = [[TBFileUtils alloc] init];
	
	return self;
}


- (void) dealloc
{
	[bookData release];
	[fileUtils release];
	if(validFileExtensions) 
		[validFileExtensions release];
	
	[super dealloc];
}



@synthesize bookData;
@synthesize validFileExtensions;
@synthesize navCon;


@end