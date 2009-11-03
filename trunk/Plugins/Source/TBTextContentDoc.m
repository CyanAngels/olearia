//
//  TBTextContentDoc.m
//  StdDaisyFormats
//
//  Created by Kieren Eaton on 13/07/09.
//  Copyright 2009 BrainBender Software. All rights reserved.
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

#import "TBTextContentDoc.h"
#import "NSXMLNode-TBAdditions.h"

@interface TBTextContentDoc ()


@end

@interface TBTextContentDoc (Private)

- (NSUInteger)itemsOnCurrentLevel;
- (NSUInteger)itemIndexOnCurrentLevel;
- (BOOL)isHeadingNode:(NSXMLNode *)aNode;
- (BOOL)moveToNextSuitableNode;

@end


@implementation TBTextContentDoc

- (id)init
{
	if (!(self=[super init])) return nil;
	
	bookData = [TBBookData sharedBookData];
	_contentStr = [[[NSString alloc] init] retain];
	
	_singleSpecifiers = [[NSArray arrayWithObjects:@"pagenum",@"sent",@"img",@"prodnote",@"caption",@"docauthor",@"doctitle",@"span",nil] retain];
	//_prefixSpecifiers = [[NSArray arrayWithObjects:nil] retain];
	_specifiers = [[NSArray arrayWithObjects:@"p",@"imggroup",@"level",@"h",nil] retain];
	
	return self;
}

- (void) dealloc
{
	[_specifiers release];
	//[_prefixSpecifiers release];
	[xmlTextDoc release];
	_contentStr = nil;
	_currentNode = nil;
	
	[super dealloc];
}


- (BOOL)openWithContentsOfURL:(NSURL *)aURL
{
	BOOL loadedOk = NO;
	NSError *theError = nil;
	
	xmlTextDoc = [[NSXMLDocument alloc] initWithContentsOfURL:aURL options:NSXMLDocumentTidyXML error:&theError];
	
	if(xmlTextDoc)
	{	
	
		NSArray *startNodes = nil;
		startNodes = [xmlTextDoc nodesForXPath:@"(/dtbook[1]|/dtbook3[1])/book[1]/*" error:nil];
		_currentNode = (startNodes) ? [startNodes objectAtIndex:0] : nil;
		
		if(nil != _currentNode)
		{	
			
			[self moveToNextSuitableNode];
			[self updateDataForCurrentPosition];
			_endOfBook = NO;
			loadedOk = YES;
			
		}
	}
	else // we got a nil return so display the error to the user
	{
		NSAlert *theAlert = [NSAlert alertWithError:theError];
		[theAlert setMessageText:LocalizedStringInTBStdPluginBundle(@"Error Opening Text Content", @"text content open fail alert short msg")];
		[theAlert setInformativeText:LocalizedStringInTBStdPluginBundle(@"There was a problem opening the textual content file (.xml).\n This book may still play if it has audio content.", @"text content open fail alert long msg")];
		[theAlert beginSheetModalForWindow:[NSApp keyWindow] 
							 modalDelegate:nil 
							didEndSelector:nil 
							   contextInfo:nil];
	}
	
	return loadedOk;
}



//- (void)startSpeakingFromIdTag:(NSString *)aTag
//{
//	if(bookData.talkingBookSpeechSynth.delegate != self)
//		[[bookData talkingBookSpeechSynth] setDelegate:self];
//	
//	[[bookData talkingBookSpeechSynth] stopSpeaking];
//	[self jumpToNodeWithIdTag:aTag];
//	[self updateDataForCurrentPosition];
//	[[bookData talkingBookSpeechSynth] startSpeakingString:_contentStr];
//}
//
//
//- (void)startSpeaking
//{
//	// check if we are the main synths delegate so we can set ourselves
//	// to watch for delegate notifications
//	if(bookData.talkingBookSpeechSynth.delegate != self)
//		[[bookData talkingBookSpeechSynth] setDelegate:self];
//	
//	[self updateDataForCurrentPosition];
//	[[bookData talkingBookSpeechSynth] startSpeakingString:_contentStr];
//}


@end

@implementation TBTextContentDoc (Synchronization)

- (void)jumpToNodeWithPath:(NSString *)fullPathToNode
{
	NSArray *nodes = nil;
	if(nil != fullPathToNode)
		nodes = [xmlTextDoc nodesForXPath:fullPathToNode error:nil];
	_currentNode = ([nodes count] > 0) ? [nodes objectAtIndex:0] : _currentNode;
}

- (void)jumpToNodeWithIdTag:(NSString *)aTag
{
	if(aTag)
	{	
		NSString *queryStr = [NSString stringWithFormat:@"/dtbook[1]/book[1]//*[@id='%@']",aTag];
		NSArray *tagNodes = nil;
		tagNodes = [xmlTextDoc nodesForXPath:queryStr error:nil];
		
		_currentNode = ([tagNodes count]) ? [tagNodes objectAtIndex:0] : _currentNode;
		_contentStr = [_currentNode contentValue];
	}
	
}

// this method is used when a user changes the position in the 
// document and we have to establish the current positional data
// from the path we are now at
- (void)updateDataAfterJump
{
	NSXMLNode *tempNode = _currentNode;
	BOOL levelHasBeenSet = NO;
	
	while(![[tempNode name] isEqualToString:@"book"])
	{
		//NSLog(@"node path -> %@",[tempNode XPath]);
		if([[tempNode name] hasPrefix:@"level"])
		{	
			if(!levelHasBeenSet)
			{	
				bookData.currentLevel = [[[tempNode name] substringFromIndex:5] integerValue];
				bookData.hasLevelUp = (bookData.currentLevel > 1) ? YES : NO;
				
				levelHasBeenSet = YES;
				
			}
		}
		
		if([[tempNode name] isEqualToString:@"pagenum"])
		{	
			bookData.currentPageNumber = [[tempNode contentValue] intValue];
		}
		else if([self isHeadingNode:tempNode])
		{	
			bookData.sectionTitle = [tempNode contentValue];
		}
		
		tempNode = [tempNode parent];

		
	}
	
	
	
}


// this method is used when auto navigating through the document
- (void)updateDataForCurrentPosition 
{

	
	if([[_currentNode name] hasPrefix:@"level"])
	{	
		bookData.currentLevel = [[[_currentNode name] substringFromIndex:5] integerValue];
		[self moveToNextSuitableNode];
	}
	
	if([[_currentNode name] isEqualToString:@"pagenum"])
	{	
		bookData.currentPageNumber = [[_currentNode stringValue] intValue];
		_contentStr = [[NSString stringWithFormat:@"Page, %d",bookData.currentPageNumber] copy];
	}
	else if([self isHeadingNode:_currentNode])
	{	
		bookData.sectionTitle = [_currentNode stringValue];
		_contentStr = [[NSString stringWithFormat:@"Heading, %@",bookData.sectionTitle] copy];
	}
	else if([[_currentNode name] isEqualToString:@"img"])
	{
		NSXMLNode *tempNode = [(NSXMLElement *)_currentNode attributeForName:@"alt"];
		_contentStr = [[NSString stringWithFormat:@"Image caption, %@",[tempNode contentValue]] copy];
	}
	else
		_contentStr = [_currentNode contentValue];
	
}

- (NSString *)currentIdTag
{
	
	//NSArray *idTags = nil;
	NSString *aTag = nil;
	aTag = [[(NSXMLElement *)_currentNode attributeForName:@"id"] stringValue];
	//idTags = [_currentNode objectsForXQuery:@"./data(@id)" error:nil];
	
	return aTag;
	//return ([idTags count]) ? [idTags objectAtIndex:0] : nil;
}

@end


@implementation TBTextContentDoc (Navigation)


@end


@implementation TBTextContentDoc (Information)

- (BOOL)canGoNext
{
	// return YES if we can go forward in the navmap
	return ([self itemIndexOnCurrentLevel] < ([self itemsOnCurrentLevel] - 1)) ? YES : NO; 
}

- (BOOL)canGoPrev
{
	// return YES if we can go backwards
	return ([self itemIndexOnCurrentLevel] > 0) ? YES : NO;
}

- (BOOL)canGoUpLevel
{
	// return Yes if we are at a lower level
	return (bookData.currentLevel > 1) ? YES : NO;
}

- (BOOL)canGoDownLevel
{
	// return YES if there is level? node as the next node
	NSString *newLevelString = [NSString stringWithFormat:@"level%d",bookData.currentLevel+1];
	return ([[[_currentNode nextNode] name] isEqualToString:newLevelString]);
}


- (NSString *)contentText
{
	
	return _contentStr;
}

@end

@implementation TBTextContentDoc (Private)

- (NSUInteger)itemsOnCurrentLevel
{
	return [[_currentNode parent] childCount]; 
}

- (NSUInteger)itemIndexOnCurrentLevel
{
	// returns an index of the current node relative to the other nodes on the same level
	return [_currentNode index];
}


- (BOOL)isHeadingNode:(NSXMLNode *)aNode
{
	NSString *nodeName = [aNode name];
	if((nil != nodeName) && ([nodeName length] >= 2))
	{
		unichar checkChar =  [nodeName characterAtIndex:0];
		unichar levelChar =  [nodeName characterAtIndex:1];
		
		// check if we have a 'h' as the first character which denotes a level header AND the second character is a digit
		return (('h' == checkChar) && (isdigit(levelChar))) ? YES : NO; 

	}
	
	return NO;
}

- (BOOL)moveToNextSuitableNode
{
	BOOL foundNode = NO;
	NSXMLNode *tempNode = _currentNode;

	if (([[tempNode name] isEqualToString:@"frontmatter"]) || ([[tempNode name] isEqualToString:@"bodymatter"])) 
	{
		tempNode = [tempNode childAtIndex:0];
		
	}

		if([tempNode nextNode] != nil)
		{
			
			//if([[tempNode nextNode] kind] == NSXMLTextKind)
			//{	
			//tempNode = [tempNode nextNode];
				//NSLog(@"node name -> %@",[tempNode name]);
			
			
			while ((!foundNode))
			{
				tempNode = [tempNode nextNode];
				if ([_specifiers containsObject:[tempNode name]])
				{
					if ([tempNode childCount] > 1)
					{
						_currentNode = [tempNode childAtIndex:0];
						foundNode = YES;
					}
					else 
					{
						_currentNode = tempNode;
						foundNode = YES;
					}

					
				}	
				else if([_singleSpecifiers containsObject:[tempNode name]])
				{
					_currentNode = tempNode;
					foundNode = YES;
				}
				
			}
			
	}

	return foundNode;	
}

//- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)success
//{
//	if((sender == bookData.talkingBookSpeechSynth))
//	{	
//		if (!_endOfBook)
//		{
//			if (success)
//			{
//				if([self moveToNextSuitableNode])
//				{	
//					[self updateDataForCurrentPosition];
//					[[bookData talkingBookSpeechSynth] startSpeakingString:_contentStr];
//				}
//			}
//			
//			
//		}
//		else
//		{
//			_contentStr = @"End of book.";
//			_endOfBook = YES;
//			[[bookData talkingBookSpeechSynth] startSpeakingString:_contentStr];
//			
//			// remove ourselves as the speech synth delegate
//			[[bookData talkingBookSpeechSynth] setDelegate:nil];
//			// post a notification back to the controller that the book has finished
//		}
//		
//	}
//	
//}


@end

