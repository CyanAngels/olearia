//
//  BBSTBOPFDocument.m
//  BBSTalkingBook
//
//  Created by Kieren Eaton on 15/04/08.
//  Copyright 2008 BrainBender Software. All rights reserved.
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

#import <Cocoa/Cocoa.h>

#import "BBSTBOPFDocument.h"
#import "BBSTalkingBookTypes.h"
#import "NSXMLElement-BBSExtensions.h"

@interface BBSTBOPFDocument ()



@property (readwrite, retain) NSDictionary *manifest; 	
@property (readwrite, retain) NSDictionary *guide;
@property (readwrite, retain) NSArray *spine;
@property (readwrite, retain) NSArray *tour;
@property (readwrite, retain) NSXMLNode *metaDataNode;

@property (readwrite, retain) NSString *bookTitle;
@property (readwrite, retain) NSString *bookSubject;
@property (readwrite, retain) NSString *bookTotalTime;
@property (readwrite) TalkingBookType bookType;
@property (readwrite) TalkingBookMediaFormat bookMediaFormat;

@property (readwrite, retain) NSString *ncxFilename;
@property (readwrite, retain) NSString *xmlContentFilename;

@property (readwrite) NSInteger	currentPosInSpine;

- (NSArray *)processSpineSection:(NSXMLElement *)aRootElement;
- (NSArray *)processTourSection:(NSXMLElement *)aRootElement;
- (NSDictionary *)processManifestSection:(NSXMLElement *)aRootElement;
- (BOOL)processMetadataSection:(NSXMLElement *)aRootElement;
- (NSDictionary *)processGuideSection:(NSXMLElement *)aRootElement;

- (NSInteger)prevSpinePos;
- (NSInteger)nextSpinePos;
- (NSString *)filenameForCurrentSpinePos;
- (NSString *)filenameForID:(NSString *)anID;

@end



@implementation BBSTBOPFDocument

@synthesize spine,manifest,tour,guide;

@synthesize currentPosInSpine;
@synthesize metaDataNode;
@synthesize bookType,bookMediaFormat;
@synthesize bookTitle,bookTotalTime,bookSubject;
@synthesize ncxFilename, xmlContentFilename;

- (id) init
{
	if (!(self=[super init])) return nil;
		
	return self;
}

/*
 xpath / xquery statements
 
 get the xml filename 
 //manifest/item[@media-type="application/x-dtbook+xml"]/data(@href)
 get the ncx filename
 //manifest/item[@media-type="application/x-dtbncx+xml"]/data(@href)

 
 
 
 */


- (BOOL)openPackageFileWithURL:(NSURL *)aURL;
{
	BOOL isOK = NO;
	
	NSError *theError;
	
	// open the validated opf URL
	NSXMLDocument	*xmlOpfDoc = [[NSXMLDocument alloc] initWithContentsOfURL:aURL options:NSXMLDocumentTidyXML error:&theError];
	
	if(xmlOpfDoc != nil)
	{
		// get the root element of the tree
		NSXMLElement *opfRoot = [xmlOpfDoc rootElement];
		
		// check we have any valid metadata before adding the rest.
		if([self processMetadataSection:opfRoot])
		{
			self.manifest = [NSDictionary dictionaryWithDictionary:[self processManifestSection:opfRoot]];
			self.spine = [NSArray arrayWithArray:[self processSpineSection:opfRoot]];
			self.guide = [NSDictionary dictionaryWithDictionary:[self processGuideSection:opfRoot]];
			currentPosInSpine = -1;
			
			
			
			
			NSMutableArray *tempData = [[NSMutableArray alloc] init];
			
			// get the media format of the book.
			[tempData addObjectsFromArray:[opfRoot objectsForXQuery:@"/package/metadata/x-metadata/meta[@name=\"dtb:multimediaType\"]/data(@content)" error:nil]];
			
			// try to get the string and if it exists convert it to lowercase
			NSString *mediaTypeStr = (1 == [tempData count]) ? [[tempData objectAtIndex:0] lowercaseString] : nil;	
			if(mediaTypeStr != nil)
			{
				// set the mediaformat accordingly
				if([mediaTypeStr isEqualToString:@"audiofulltext"])
					self.bookMediaFormat = AudioFullTextMediaFormat;
				else if([mediaTypeStr isEqualToString:@"audioparttext"])
					self.bookMediaFormat = AudioPartialTextMediaFormat;
				else if([mediaTypeStr isEqualToString:@"audioonly"])
					self.bookMediaFormat = AudioOnlyMediaFormat;
				else if([mediaTypeStr isEqualToString:@"audioncc"])
					self.bookMediaFormat = AudioNcxOrNccMediaFormat;
				else if([mediaTypeStr isEqualToString:@"textpartaudio"])
					self.bookMediaFormat = TextPartialAudioMediaFormat;
				else if([mediaTypeStr isEqualToString:@"textncc"])
					self.bookMediaFormat = TextNcxOrNccMediaFormat;
				else 
					self.bookMediaFormat = unknownMediaFormat;
			}
			else
			{
				self.bookMediaFormat = unknownMediaFormat;
			}
			
			
			
			[tempData removeAllObjects];
			// get the ncx filename
			[tempData addObjectsFromArray:[opfRoot objectsForXQuery:@"//manifest/item[@media-type=\"application/x-dtbncx+xml\"]/data(@href)" error:nil]]; 
			// there will only ever be 1 ncx file
			self.ncxFilename = ([tempData count] == 1) ? [tempData objectAtIndex:0] : nil;
			
			[tempData removeAllObjects];
			// get the xml content filename
			[tempData addObjectsFromArray:[opfRoot objectsForXQuery:@"//manifest/item[@media-type=\"application/x-dtbook+xml\"]/data(@href)" error:nil]];
			// there will only be one xml content file
			self.xmlContentFilename = ([tempData count] == 1) ? [tempData objectAtIndex:0] : nil;
			
			// release the tempdata array
			tempData = nil;
			
			//NSLog(@" manifest = \n%@",[manifest allKeysForObject:@"application/x-dtbook+xml"]);
			isOK = YES;
		}
	}
	else // we got a nil return so display the error to the user
	{
		NSAlert *theAlert = [NSAlert alertWithError:theError];
		[theAlert setMessageText:@"Package File Error"];
		[theAlert setInformativeText:@"Failed to open OPF file.\n Please check book structure or try another book."];
		[theAlert beginSheetModalForWindow:[NSApp keyWindow] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	}
	
	
	return isOK;
}


/*
- (void) dealloc
{	
	// cleanup nice
	// check what we may have used
	
	[spine release];
	[manifest release];
	[guide release];
	[tour release];
	[OPFBookTypeString release];
	[OPFMediaFormatString release];
	[bookTitle release];
	[bookSubject release];
	[bookTotalTime release];
	
	[super dealloc];
}
*/

#pragma mark -
#pragma mark Private Methods

- (NSInteger)prevSpinePos
{
	return ((currentPosInSpine - 1) < 0) ?  0 : (currentPosInSpine - 1);
	
}

- (NSInteger)nextSpinePos
{
	NSUInteger newPos = (currentPosInSpine + 1);
	return (newPos == [self.spine count]) ? [self.spine count] : newPos;
	
}

- (NSString *)nextSpineID
{
	NSInteger newPos = [self nextSpinePos];
	if(newPos == currentPosInSpine)
		return nil; // we are at the end of the spine
	
	self.currentPosInSpine = newPos;
	return [spine objectAtIndex:currentPosInSpine];
}

- (NSString *)prevSpineID
{ 
	NSInteger newPos = [self prevSpinePos];
	if(newPos == currentPosInSpine)
		return nil; // we are at the beginning of the spine
	
	self.currentPosInSpine = newPos;
	return [spine objectAtIndex:currentPosInSpine];
}

#pragma mark -
#pragma mark Public Accessors

- (NSString *)nextAudioSegmentFilename
{
	//NSString *spineId;
	// first get the ID reference from the spine
	// check if we are at the first element of the spine
	NSInteger newPos = [self nextSpinePos];
	if(newPos > currentPosInSpine)
	{	
		self.currentPosInSpine = newPos;
		//spineId = [NSString stringWithString:[spine objectAtIndex:currentPosInSpine]];
	
		// check if we got an ID ref back
		//if(spineId != nil)
		//{
			// return the filename from the manifest
			return [self filenameForCurrentSpinePos];
		//}

	}
	
	return nil;

}

- (NSString *)prevAudioSegmentFilename
{
	//NSString *spineId;
	// first get the ID reference from the spine

	NSInteger newPos = [self prevSpinePos];
	if(newPos < currentPosInSpine)
	{	
		self.currentPosInSpine = newPos;
		//spineId = [NSString stringWithString:[spine objectAtIndex:currentPosInSpine]];
	
		// check if we got an 
		//if(spineId != nil)
		//{
			// return the filename from the manifest
			return [self filenameForCurrentSpinePos];
		//}
		
	
	}
	
	return nil;

}


// get the filename for an associated id from the manifest
- (NSString *)filenameForID:(NSString *)anID
{
	return [[manifest objectForKey:anID] objectForKey:@"href"];
}

- (NSString *)filenameForCurrentSpinePos
{
	// a nil value indicates there was no id or filename
	return [self filenameForID:[self.spine objectAtIndex:currentPosInSpine]];
}

#pragma mark -
#pragma mark Dynamic Methods

/*
// get the name of the ncx file as stored in the manifest
- (NSString *)ncxFilename
{
	// get the ncx filename
	NSString *ncxFile= [NSString stringWithString:[manifest valueForKeyPath:@"ncx.href"]];
	// check if it wasnt there 
	if(([ncxFile isEqualToString:@""]) || (ncxFile == nil))
		return nil;
	
	return ncxFile;
}
*/
 
#pragma mark -
#pragma mark Private Methods
		
- (BOOL)processMetadataSection:(NSXMLElement *)aRootElement
{	
	metaDataNode = nil;

	metaDataNode = [[aRootElement nodesForXPath:@"metadata" error:nil] objectAtIndex:0];
	//[metaDataNode detach];
	
	if(metaDataNode != nil)
	{
		// get the dc:Format node string
		NSMutableArray *nodeObjects = [[NSMutableArray alloc] initWithArray:[metaDataNode objectsForXQuery:@"//dc-metadata/data(*:Format)" error:nil]];
		NSString *bookFormatString = ([nodeObjects count] > 0) ? [nodeObjects objectAtIndex:0] : @"" ;
		
		// check the type for DTB 2002 specifier
		if(YES == [[bookFormatString uppercaseString] isEqualToString:@"ANSI/NISO Z39.86-2002"])
		{	
			// it may be a bookshare book 
			// check the identifier node for a bookshare scheme attribute containing "BKSH"
			// check if the array returned is not nil ie contains the identifier node
			if([metaDataNode objectsForXQuery:@"//dc-metadata/*:Identifier[@scheme=\"BKSH\"]/." error:nil] != nil)
			{
				// change the book type to Bookshare
				self.bookType = BookshareType;
			}
			else
			{
				// set the type to DTB 2002
				self.bookType = DTB2002Type;
			}
			
		}
		// check for DTB 2005 spec identifier
		else if(YES == [[bookFormatString uppercaseString] isEqualToString:@"ANSI/NISO Z39.86-2005"])
		{
			self.bookType = DTB2005Type;
		}
		else
		{
			// we dont know what type it is so set the unknown type
			self.bookType = UnknownBookType;
		}
		
		// sanity check to see that we know what type of book we are opening
		if(self.bookType != UnknownBookType)
		{
			// set the book title
			[nodeObjects removeAllObjects];
			[nodeObjects setArray:[metaDataNode objectsForXQuery:@"//dc-metadata/data(*:Title)" error:nil]];
			self.bookTitle = ([nodeObjects count] > 0) ? [nodeObjects objectAtIndex:0] : @"No Title"; 
		
			// set the subject
			[nodeObjects removeAllObjects];
			[nodeObjects setArray:[metaDataNode objectsForXQuery:@"//dc-metadata/data(*:Subject)" error:nil]];
			self.bookSubject =  ([nodeObjects count] > 0) ? [nodeObjects objectAtIndex:0] : @"No Subject";

			[nodeObjects removeAllObjects];
			[nodeObjects setArray:[metaDataNode objectsForXQuery:@"//x-metadata/meta[@name=\"dtb:multimediaType\"]/data(@content)" error:nil]];
			NSString *mediaStr = ([nodeObjects count] > 0) ? [nodeObjects objectAtIndex:0] : nil;
			if(mediaStr != nil)
			{
				if([mediaStr isEqualToString:@"audioFullText"] == YES)
					self.bookMediaFormat = AudioFullTextMediaFormat;
				else if([mediaStr isEqualToString:@"audioPartText"] == YES)
					self.bookMediaFormat = AudioPartialTextMediaFormat;
				else if([mediaStr isEqualToString:@"audioOnly"] == YES)
					self.bookMediaFormat = AudioOnlyMediaFormat;
				else if([mediaStr isEqualToString:@"audioNCX"] == YES)
					self.bookMediaFormat = AudioNcxOrNccMediaFormat;
				else if([mediaStr isEqualToString:@"textPartAudio"] == YES)
					self.bookMediaFormat = TextPartialAudioMediaFormat;
				else if([mediaStr isEqualToString:@"textNCX"] == YES)
					self.bookMediaFormat = TextNcxOrNccMediaFormat;
				else 
					self.bookMediaFormat = unknownMediaFormat;
			}
			else
			{
				self.bookMediaFormat = unknownMediaFormat;
			}
			
		}
		
				
		
	}
		
	return (metaDataNode != nil) ? YES : NO;
}

- (NSArray *)processSpineSection:(NSXMLElement *)aRootElement
{
	NSMutableArray * spineContents = nil;
	
	NSArray *spineNodes = [aRootElement nodesForXPath:@"spine" error:nil];
	// check if there is a spine node
	if ([spineNodes count] == 1)
	{
		
		NSArray *spineElements = [[spineNodes objectAtIndex:0] nodesForXPath:@"itemref" error:nil];
		// check if there are some itemref nodes
		if ([spineElements count] > 0)
		{
			spineContents = [[NSMutableArray alloc] init];
			for(NSXMLElement *anElement in spineElements)
			{
				// get the element contained in the node then add its string contents to the temp array
				[spineContents addObject:[[[anElement attributes] objectAtIndex:0] stringValue]];
			}
		}
	}
		
	// return the array which may be nil if there was no spine 
	return spineContents; 
	
}

- (NSDictionary *)processManifestSection:(NSXMLElement *)aRootElement
{
	NSMutableDictionary * manifestContents = nil;
	
	NSArray *manifestNodes = [aRootElement nodesForXPath:@"manifest" error:nil];
	// check if there is a manifest node - there will be only one
	if([manifestNodes count] == 1)
	{
		NSArray *manifestElements = [[manifestNodes objectAtIndex:0] nodesForXPath:@"item" error:nil];
		// check if there are item nodes
		if ([manifestElements count] > 0)
		{
			manifestContents = [[NSMutableDictionary alloc] init];
			for(NSXMLElement *anElement in manifestElements)
			{
				// get the values and keys and add them tou our dictionary 
				NSMutableDictionary *nodeContents = [[NSMutableDictionary alloc] init];
				[nodeContents setValue:[[anElement attributeForName:@"href"] stringValue] forKey:@"href"];
				[nodeContents setValue:[[anElement attributeForName:@"media-type"] stringValue] forKey:@"media-type"];
				[manifestContents setObject:(NSDictionary *)nodeContents forKey:[[anElement attributeForName:@"id"] stringValue]];
			}
		}
	}
	// return the dict which may be nil if there was no manifest 
	return manifestContents;
}


- (NSDictionary *)processGuideSection:(NSXMLElement *)aRootElement
{
	NSMutableDictionary *guideContents = nil;

	NSArray *guideNodes = [aRootElement nodesForXPath:@"guide" error:nil];
	// check if there is a manifest node - there will be only one
	if([guideNodes count] == 1)
	{
		NSArray *guideElements = [[guideNodes objectAtIndex:0] nodesForXPath:@"reference" error:nil];
		// check if there are item nodes
		if ([guideElements count] > 0)
		{
			guideContents = [[NSMutableDictionary alloc] init];
			for(NSXMLElement *anElement in guideElements)
			{
				NSMutableDictionary *nodeContents = [[NSMutableDictionary alloc] init];
				[nodeContents setValue:[[anElement attributeForName:@"type"] stringValue] forKey:@"type"];
				[nodeContents setValue:[[anElement attributeForName:@"href"] stringValue] forKey:@"href"];
				[guideContents setObject:(NSDictionary *)nodeContents forKey:[[anElement attributeForName:@"title"] stringValue]];
			}
		}
	}
	return guideContents;
}

- (NSArray *)processTourSection:(NSXMLElement *)aRootElement
{
	
	NSMutableArray *tourContents = nil;
	
	return tourContents;
}



@end

