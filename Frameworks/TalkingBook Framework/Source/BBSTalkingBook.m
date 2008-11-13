//
//  BBSTalkingBook.m
//  BBSTalkingBook
//
//  Created by Kieren Eaton on 5/05/08.
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

#import "BBSTalkingBook.h"
#import "BBSTBControlDoc.h"
#import "BBSTBPackageDoc.h"
#import "BBSTBOPFDocument.h"
#import "BBSTBNCXDocument.h"
#import "BBSTBNCCDocument.h"
#import "BBSTBSMILDocument.h"
#import <QTKit/QTKit.h>

//@class BBSTBTextDocument;



@interface BBSTalkingBook ()


- (void)audioFileDidEnd:(NSNotification *)notification;
- (void)loadStateDidChange:(NSNotification *)notification;
- (void)errorDialogDidEnd;
- (void)setDisplayDefaults;
- (void)resetBook;

- (void)setupAudioNotifications;
- (NSArray *)makeChaptersOfDuration:(QTTime)aDuration forMovie:(QTMovie *)aMovie;

- (TalkingBookControlDocType)typeOfControlDoc:(NSURL *)aURL;
- (void)setPreferredAudioAttributes;
- (BOOL)updateAudioFile:(NSString *)pathToFile;
- (void)updateForPosInBook;
- (void)updateChapterIndex;

- (BOOL)openControlDocument:(NSURL *)aDocUrl;

@property (readwrite, retain) NSSpeechSynthesizer *speechSynth;
@property (readwrite) QTTime _skipDuration;

@property (readwrite) NSInteger	maxLevels;

@property (readwrite) NSInteger _totalChapters;
@property (readwrite) NSInteger _currentChapterIndex;

@property (readwrite) TalkingBookType _controlMode;
@property (readwrite, retain) QTMovie *_currentAudioFile;

@property (readwrite, retain) BBSTBTextDocument	*textDoc;
@property (readwrite, retain) BBSTBSMILDocument *smilDoc;
@property (readwrite, retain) NSString *_bookPath;
@property (readwrite, retain) NSString *_currentSegmentFilename;

// Bindings related
@property (readwrite, retain) NSString	*bookTitle;
@property (readwrite, retain) NSString	*currentSectionTitle;
@property (readwrite, retain) NSString	*currentPageString;
@property (readwrite, retain) NSString	*currentLevelString;
@property (readwrite) BOOL		canPlay;
@property (readwrite) BOOL		isPlaying;
@property (readwrite) BOOL		hasNextChapter;
@property (readwrite) BOOL		hasPreviousChapter;
@property (readwrite) BOOL		hasLevelUp;
@property (readwrite) BOOL		hasLevelDown;
@property (readwrite) BOOL		hasNextSegment;
@property (readwrite) BOOL		hasPreviousSegment;

@end

@implementation BBSTalkingBook



- (id) init
{
	if (!(self=[super init])) return nil;

	speechSynth = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
	[speechSynth setDelegate:self];
	
	[self resetBook];
	bookIsAlreadyLoaded = NO;

	TalkingBookNotificationCenter = [NSNotificationCenter defaultCenter];
	
	return self;
}


- (BOOL)openWithFile:(NSURL *)aURL
{
	// set up the defaults for the bindings when opening the book
	[self setDisplayDefaults];
	
	_hasPageNavigation = NO;
	_hasPhraseNavigation = NO;
	_hasSentenceNavigation = NO;
	_hasWordNavigation = NO;
	
	if(_hasControlFile) 
	{
		_controlDoc = nil;
		_hasControlFile = NO;
	}
	
	if(_hasPackageFile) 
	{
		_packageDoc = nil;
		_hasPackageFile = NO;
	}
	
	if(smilDoc) smilDoc = nil;
	if(textDoc) textDoc = nil;
	
	BOOL fileOpenedOK = NO;
	bookIsAlreadyLoaded = NO;
	
	// check for a OPF, NCX or NCC.html file first
	// get the parent folder path as a string
	
	_bookPath = [[aURL path] stringByDeletingLastPathComponent];
	
	// when we do zip files we will check internally for one of the package or control files
	// also direct loading of .iso files would be good too
	
	NSURL *fileURL; 
	// check the extension first
	NSString *filename = [[NSString alloc] initWithString:[aURL path]];
	
	// do a sanity check to see if the user chose a NCX file and there 
	// is actually an OPF file available
	
	// check for an ncx file first
	if([self typeOfControlDoc:aURL] == ncxControlDocType)
	{
		// we assume that the opf file has the same filename as the ncx file sans extension
		NSFileManager *fm = [NSFileManager defaultManager];
		// delete the extension from the NCX filename
		NSMutableString *opfFilePath = [[NSMutableString alloc] initWithString:[filename stringByDeletingPathExtension]];
		// add the OPF extension to the filename
		[opfFilePath appendString:@".opf"];
		// check if the filename exists
		if ([fm fileExistsAtPath:opfFilePath] )
		{	
			// it exists so make a url of it
			fileURL = [[NSURL alloc] initFileURLWithPath:opfFilePath];
			_packageDoc = [[BBSTBOPFDocument alloc] init];
			_hasPackageFile = [_packageDoc openPackageFileWithURL:fileURL];
			if(_hasPackageFile)
			{
				
				fileOpenedOK = _hasPackageFile;
				// successfully opened the opf document so get the ncx filename from it
				NSString *ncxPathString = [[NSString alloc] initWithString:[_bookPath stringByAppendingPathComponent:[_packageDoc ncxFilename]]];
					
				// make a URL of the full path
				NSURL *ncxURL = [[NSURL alloc] initFileURLWithPath:ncxPathString];

				// open the control file
				_hasControlFile = [self openControlDocument:ncxURL];
			}
			else // package file failed opening so drop back to the NCX file 
			{	
				// open the control file
				_hasControlFile = [self openControlDocument:aURL];
				fileOpenedOK = _hasControlFile;
			}

		}
		else // no opf file found - so dropback to the ncx file.
		{	
			_hasControlFile = [self openControlDocument:aURL];
			fileOpenedOK = _hasControlFile;
		}
	}
	else
	{	
		// we have chosen some other sort of file so open and process it.
		// check if its an OPF package file
		if(YES == [[[filename pathExtension] lowercaseString] isEqualToString:@"opf"])
		{
			_packageDoc = [[BBSTBOPFDocument alloc] init];
			_hasPackageFile = [_packageDoc openPackageFileWithURL:aURL];
			if(_hasPackageFile)
			{				
				fileOpenedOK = _hasPackageFile;
				
				// get the book type so we know how to control acces to it
				_controlMode = [_packageDoc bookType];
				// successfully opened the opf document so get the ncx filename from it
				NSString *ncxPathString = [[NSString alloc] initWithString:[_bookPath stringByAppendingPathComponent:[_packageDoc ncxFilename]]];
						
				// make a URL of the full path
				NSURL *ncxURL = [[NSURL alloc] initFileURLWithPath:ncxPathString];
					
				_hasControlFile = [self openControlDocument:ncxURL];
				
			}
		}
		
		else //check for a control file
		{
			_hasControlFile = [self openControlDocument:aURL];
			fileOpenedOK = _hasControlFile;
		}
	}
	
	
	if (fileOpenedOK)
	{
		self.canPlay = YES;
		bookIsAlreadyLoaded = YES;
		
		fullBookPath = [aURL path];
		
		if(_hasPackageFile)
		{
			_mediaFormat = [_packageDoc bookMediaFormat];

			self.bookTitle = [_packageDoc bookTitle];
			self.currentLevelString = [NSString stringWithFormat:@"%d",[_controlDoc currentLevel]];
							
		}
		else if(_hasControlFile)
		{
			_mediaFormat = [_controlDoc bookMediaFormat];
			
			
			if(0 == [_controlDoc totalPages])
			{
				self.currentPageString = NSLocalizedString(@"No Page Numbers", @"no page numbers string");
			}
			else
			{
				
				//self.currentPageString = (0 != [_controlDoc totalPages]) ? [NSString stringWithFormat:@"%d",[_controlDoc totalPages]] : [NSString stringWithFormat:@"%d",[_controlDoc totalTargetPages]];
				//_hasPageNavigation = YES;
				//_maxLevelConMode = pageNavigationControlMode;
			}
			self.bookTitle = (_hasPackageFile) ? [_packageDoc bookTitle] : [_controlDoc bookTitle];
			self.currentLevelString = [NSString stringWithFormat:@"%d",[_controlDoc currentLevel]];
			
		}
		
		// check that we have some sort of audio media in the file
		if((TextNcxOrNccMediaFormat != _mediaFormat))
			[self setupAudioNotifications];
		
		
		//update the interface with the initial values
		[self updateForPosInBook];		
		
	}
	
	
	return fileOpenedOK;
	
}

- (BOOL)openControlDocument:(NSURL *)aDocUrl 
{
	BOOL loadedOK = NO;
	
	
	if(nil != aDocUrl)
	{
		TalkingBookControlDocType aType = [self typeOfControlDoc:aDocUrl];
		switch (aType)
		{
			case ncxControlDocType:
				_controlDoc = [[BBSTBNCXDocument alloc] init];
				break;
			case bookshareNcxControlDocType:
				break;
			case nccControlDocType:
				_controlDoc = [[BBSTBNCCDocument alloc] init];
			default:
				break;
		}
				
		// open the control file
		 loadedOK = (nil != _controlDoc) ? [_controlDoc openControlFileWithURL:aDocUrl] : NO;
	}
	return loadedOK;
}


#pragma mark -
#pragma mark Play Methods

- (void)playAudio
{
	if(self.isPlaying == NO)
	{
		if(_currentAudioFile) // check if we have an audio file to play
		{
			[_currentAudioFile play];
			self.isPlaying = YES;
		}
	}
	else // isPlaying == YES
	{
		[_currentAudioFile play];
		self.isPlaying = YES;
	}
	
	[self updateForPosInBook];
}

- (void)pauseAudio
{	
	[_currentAudioFile stop];
	self.isPlaying = NO;
	
}

#pragma mark -
#pragma mark Navigation Methods

- (BOOL)nextSegment
{
	BOOL	fileDidUpdate = NO;
	if(YES == _hasControlFile)
	{	
		// get the filename of the next audio file to play from the ncx file
		[_controlDoc moveToNextSegment];

		fileDidUpdate = [self updateAudioFile:[_controlDoc currentAudioFilename]];
	}
	
	return fileDidUpdate;
}

- (BOOL)nextSegmentOnLevel
{
	BOOL fileDidUpdate = NO;
	if(YES == _hasControlFile)
	{	
		// move to the next segment at the current level
		[_controlDoc setLoadFromCurrentLevel:YES];
		[_controlDoc moveToNextSegment];
		
		// update the audio segment
		fileDidUpdate = [self updateAudioFile:[_controlDoc currentAudioFilename]];
	}
			
	return fileDidUpdate;
}

- (BOOL)previousSegment 
{
	BOOL	fileDidUpdate = NO;
	if(YES == _hasControlFile)
	{	
		// move to the previous segment of the book
		[_controlDoc moveToPreviousSegment];

		// update the audio segment 
		fileDidUpdate = [self updateAudioFile:[_controlDoc currentAudioFilename]];

	}
	
	return fileDidUpdate;
}

- (void)upOneLevel
{
	if(_hasControlFile)
	{
		[_controlDoc goUpALevel];
		
		self.currentLevelString = [NSString stringWithFormat:@"%d",[_controlDoc currentLevel]];
	}
	
	[self updateForPosInBook];
	
	if(speakUserLevelChange)
	{
		[_currentAudioFile stop];
		[speechSynth startSpeakingString:[NSString stringWithFormat:NSLocalizedString(@"Level %d", @"VO level string"),[_controlDoc currentLevel]]];
	}
	else
	{
		// update the audio segment 
		[self updateAudioFile:[_controlDoc currentAudioFilename]];
		[_currentAudioFile play];
	}

}

- (void)downOneLevel
{
	// check that we have a control document to use
	if(_hasControlFile)
	{
		// check that we can go down a level
		if([_controlDoc canGoDownLevel])
		{	
			[_controlDoc goDownALevel];
			
			self.currentLevelString = [NSString stringWithFormat:@"%d",[_controlDoc currentLevel]];
		}
		else if(_hasPageNavigation)
		{
			// jump to the next page
			
		}

		[self updateForPosInBook];
		
		if(speakUserLevelChange)
		{
			[_currentAudioFile stop];
			[speechSynth startSpeakingString:[NSString stringWithFormat:NSLocalizedString(@"Level %d", @"VO level string"),[_controlDoc currentLevel]]];
		}
		else
		{
			// update the audio segment 
			[self updateAudioFile:[_controlDoc currentAudioFilename]];
			[_currentAudioFile play];
		}
	}
	
}

- (BOOL)hasChapters
{
	return [_currentAudioFile hasChapters];
}

- (void)nextChapter
{
	if((_currentChapterIndex + 1) < _totalChapters)
	{
		_currentChapterIndex++;
		[_currentAudioFile setCurrentTime:[_currentAudioFile startTimeOfChapter:_currentChapterIndex]];
		self.hasNextChapter = (_currentChapterIndex < (_totalChapters - 1)) ? YES : NO;
		self.hasPreviousChapter = (_currentChapterIndex > 0) ? YES : NO;
	}
}

- (void)previousChapter
{
	if((_currentChapterIndex - 1) >= 0)
	{
		_currentChapterIndex--;
		[_currentAudioFile setCurrentTime:[_currentAudioFile startTimeOfChapter:_currentChapterIndex]];
		self.hasNextChapter = (_currentChapterIndex < (_totalChapters - 1)) ? YES : NO;
		self.hasPreviousChapter = (_currentChapterIndex > 0) ? YES : NO;
	}
}

- (void)gotoPage
{
	
}

#pragma mark -
#pragma mark Information Methods

- (NSDictionary *)getBookInfo
{

	return nil;
}


- (NSDictionary *)getCurrentPageInfo
{
	return nil;
}

#pragma mark -
#pragma mark Overridden Attribute Methods

- (void)setPlaybackRate:(float)aRate
{
	if(aRate != playbackRate)
	{
		playbackRate = aRate;
		[_currentAudioFile setRate:aRate];
		
		if(NO == isPlaying) 
		{	
			// this is a workaround for the current issue where setting the 
			// playback speed automatically starts playback
			[_currentAudioFile stop];
			[_currentAudioFile setAttribute:[NSNumber numberWithFloat:self.playbackRate] forKey:QTMoviePreferredRateAttribute];
		}
	}
}

- (void)setPlaybackVolume:(float)aLevel
{
	if(aLevel != playbackVolume)
	{
		playbackVolume = aLevel;
		[_currentAudioFile setVolume:aLevel];
	}
}

- (void)setPreferredVoice:(NSString *)aVoiceID;
{
	[speechSynth setVoice:aVoiceID];
	preferredVoice = aVoiceID;
}
- (void)setChapterSkipIncrement:(float)anIncrement;
{
	chapterSkipIncrement = anIncrement;
	_skipDuration = QTMakeTimeWithTimeInterval((double)anIncrement * (double)60);
}

- (void)setPlayPositionID:(NSString *)aPos
{
	if(_hasControlFile)
	{
		[_controlDoc setCurrentPositionID:aPos];
	}
}

- (NSString *)playPositionID
{
	if(_hasControlFile)
	{
		return [_controlDoc currentPositionID];
	}
	
	return nil;
}

- (NSString *)audioSegmentTimePosition
{
	
	return	QTStringFromTime([_currentAudioFile currentTime]);
}

#pragma mark -
#pragma mark Private Methods

- (void)setDisplayDefaults
{
	self.bookTitle = @"Olearia";
	self.currentLevelString = @"";
	self.currentPageString = @"";
	self.currentSectionTitle = @"";
	self.canPlay = NO;
	self.isPlaying = NO;
	self.hasNextChapter = NO;
	self.hasPreviousChapter = NO;
	self.hasLevelUp = NO;
	self.hasLevelDown = NO;
	self.hasNextSegment = NO;
	self.hasPreviousSegment = NO;
	
}

- (void)resetBook
{
	if(_currentAudioFile )
		[_currentAudioFile stop];
	_currentAudioFile = nil;
	_hasPackageFile = NO;
	_packageDoc = nil;
	_hasControlFile = NO;
	_controlDoc = nil;
	smilDoc = nil;
	textDoc = nil;
	bookIsAlreadyLoaded = NO;
	shouldJumpToTime = NO;

	_levelNavConMode = levelNavigationControlMode; // set the default level mode
	_maxLevelConMode = levelNavigationControlMode; // set the default max level mode. 
	_controlMode = UnknownBookType; // set the default book type
	_currentSegmentFilename = @"";
	_mediaFormat = unknownMediaFormat;
	
	_totalChapters = 0;
	
	[self setDisplayDefaults];
}


- (TalkingBookControlDocType)typeOfControlDoc:(NSURL *)aURL
{
	// set the default 
	TalkingBookControlDocType type = unknownControlDocType;
	
	NSString *filename = [aURL path];
	// check for an ncx extension
	if(YES == [[[filename pathExtension] lowercaseString] isEqualToString:@"ncx"])
	{
		type = ncxControlDocType;
	}
	// check for an ncc.html file
	else if(YES == [[[filename lastPathComponent] lowercaseString] isEqualToString:@"ncc.html"])
	{
		type = nccControlDocType;
	}
	
	return type;
}


- (BOOL)updateAudioFile:(NSString *)pathToFile
{
	NSError *theError = nil;
	BOOL loadedOK = NO;
	
	// check that we have not passed in a nil string
	if(pathToFile != nil)
	{
		// check if we have the same file path as we used for the previous segment
		if(NO == [_currentSegmentFilename isEqualToString:pathToFile])
		{
			_currentSegmentFilename = pathToFile;
			
			[_currentAudioFile stop]; // pause the playback if there is any currently playing
			
			_currentAudioFile = nil;
			_currentAudioFile = [QTMovie movieWithFile:pathToFile error:&theError];
			
		
			if(_currentAudioFile != nil)
			{
				// make the file editable and set the timescale for it 
				[_currentAudioFile setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieEditableAttribute];
				[self setPreferredAudioAttributes];
				if(([[_currentAudioFile attributeForKey:QTMovieLoadStateAttribute] longValue] == QTMovieLoadStateComplete) && (NO == [_currentAudioFile hasChapters]))
				{
					[TalkingBookNotificationCenter postNotificationName:QTMovieLoadStateDidChangeNotification object:_currentAudioFile];
				}
				[self updateForPosInBook];
				loadedOK = YES;
			}
		}
		else
		{
			loadedOK = YES;
			[self updateForPosInBook];
			shouldJumpToTime = YES;
			//audioSegmentTimePosition = [_controlDoc startTimeOfCurrentSegment];
		}
	}
	
	if(shouldJumpToTime) //
	{
		shouldJumpToTime = NO; // reset the flag
		[_currentAudioFile setCurrentTime:QTTimeFromString(audioSegmentTimePosition)];
	}

	if((nil == _currentAudioFile) || (loadedOK == NO))
	{	
		NSAlert *theAlert = [NSAlert alertWithError:theError];
		[theAlert setMessageText:NSLocalizedString(@"Audio File Error", @"audio error alert short msg")];
		[theAlert setInformativeText:NSLocalizedString(@"There was a problem loading an audio file.\n Please check the book format for problems.\nOlearia will now reset as this book will not play", @"audio error alert short msg")];
		[theAlert setAlertStyle:NSWarningAlertStyle];
		[theAlert setIcon:[NSImage imageNamed:@"olearia.icns"]];		
		[theAlert beginSheetModalForWindow:[NSApp keyWindow] modalDelegate:self didEndSelector:@selector(errorDialogDidEnd) contextInfo:nil];
		
		return NO;
	}
	
	return YES;
}

- (void)errorDialogDidEnd
{
	[self resetBook];
}


- (NSArray *)makeChaptersOfDuration:(QTTime)aDuration forMovie:(QTMovie *)aMovie
{
	
	NSMutableArray *tempChapts = [[NSMutableArray alloc] init];
	QTTime movieDur = [aMovie duration];
	if(NSOrderedAscending != QTTimeCompare(movieDur, aDuration))
	{	
		
		QTTime chapterStart = QTZeroTime;
		NSInteger chIndex = 0;
		while(NSOrderedAscending == QTTimeCompare(chapterStart, movieDur))
		{
			NSMutableDictionary *thisChapter = [[NSMutableDictionary alloc] init];
			
			[thisChapter setObject:[NSValue valueWithQTTime:(chapterStart)] forKey:QTMovieChapterStartTime];
			
			[thisChapter setObject:[[NSNumber numberWithInt:chIndex] stringValue] forKey:QTMovieChapterName];
			
			[tempChapts addObject:thisChapter];
			
			chIndex++;
			chapterStart = QTTimeIncrement(chapterStart, aDuration);
		}
		
	}
	return ([tempChapts count] > 1) ? tempChapts : nil;
}


- (void)setPreferredAudioAttributes
{
	[_currentAudioFile setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieRateChangesPreservePitchAttribute];
	[_currentAudioFile setAttribute:[NSNumber numberWithFloat:self.playbackVolume] forKey:QTMoviePreferredVolumeAttribute];
	[_currentAudioFile setVolume:self.playbackVolume];
	[_currentAudioFile setAttribute:[NSNumber numberWithFloat:self.playbackRate] forKey:QTMoviePreferredRateAttribute];
	[_currentAudioFile setDelegate:self];
}


- (void)setupAudioNotifications
{
	// watch for load state changes
	[TalkingBookNotificationCenter addObserver:self 
									  selector:@selector(loadStateDidChange:)
										  name:QTMovieLoadStateDidChangeNotification
										object:_currentAudioFile];

	// start watching for notifications for reaching the end of the audio file
	[TalkingBookNotificationCenter addObserver:self 
									  selector:@selector(audioFileDidEnd:) 
										  name:QTMovieDidEndNotification 
										object:_currentAudioFile];

	// watch for chapter change notifications
	[TalkingBookNotificationCenter addObserver:self 
									  selector:@selector(updateChapterIndex) 
										  name:QTMovieChapterDidChangeNotification 
										object:_currentAudioFile];
	}

- (void)updateChapterIndex
{
	_currentChapterIndex = [_currentAudioFile chapterIndexForTime:[_currentAudioFile currentTime]];
	self.hasNextChapter = (_currentChapterIndex < (_totalChapters - 1)) ? YES : NO;
	self.hasPreviousChapter = (_currentChapterIndex > 0) ? YES : NO;
}


- (void)updateForPosInBook
{
	if(_hasControlFile)
	{	
		self.currentSectionTitle = [_controlDoc segmentTitle];
		
		if(levelNavigationControlMode == _levelNavConMode)
			self.currentLevelString = [NSString stringWithFormat:@"%d",[_controlDoc currentLevel]];
		self.hasLevelUp = (([_controlDoc canGoUpLevel]) || (_levelNavConMode > levelNavigationControlMode)) ? YES : NO;
		
		
		if ([_controlDoc canGoDownLevel]) // check regular level down first
			self.hasLevelDown = YES;
		else // We have reached the bottom of the current levels so check if we have other forms of nagigation below this
			self.hasLevelDown = (_levelNavConMode < _maxLevelConMode) ? YES : NO;
		
		self.hasNextSegment = [_controlDoc canGoNext];
		self.hasPreviousSegment = [_controlDoc canGoPrev];
		self.hasNextChapter = (_currentChapterIndex < (_totalChapters - 1)) ? YES : NO;
		self.hasPreviousChapter = (_currentChapterIndex > 0) ? YES : NO;
		if(_hasPageNavigation)
		{
			self.currentPageString = [NSString stringWithFormat:NSLocalizedString(@"%d of %d", @"current page string"),[_controlDoc currentPageNumber],[_controlDoc totalPages]];
		}
	}
	
}

#pragma mark -
#pragma mark Delegate Methods

- (void)audioFileDidEnd:(NSNotification *)notification
{
	if(YES == [self nextSegment])
		[self playAudio];
}


- (void)loadStateDidChange:(NSNotification *)notification
{
	
	if([[[notification object] attributeForKey:QTMovieLoadStateAttribute] longValue] == QTMovieLoadStateComplete)
	{
		
		if(_hasControlFile)
		{
			NSArray *chaptersArray;
			if(_levelNavConMode > levelNavigationControlMode) 
			{
				// populate the chapters array with a timescale the same as the movie file we just initialized
				long movieTimescale = [[_currentAudioFile attributeForKey:QTMovieTimeScaleAttribute] longValue];
				chaptersArray = [NSArray arrayWithArray:[_controlDoc chaptersForSegmentWithTimescale:movieTimescale]];
			}
			else // we are currently using basic level navigation 
			{
				// set the chapter markers to the ones set in the prefs
				chaptersArray = [NSArray arrayWithArray:[self makeChaptersOfDuration:_skipDuration forMovie:_currentAudioFile]];
			}
			
			if([chaptersArray count] > 0) // check we have some chapters to add
			{
				// get the track the chapter will be associated with
				QTTrack *musicTrack = [[_currentAudioFile tracksOfMediaType:QTMediaTypeSound] objectAtIndex:0];
				_currentChapterIndex = -1;
				NSDictionary *trackDict = [NSDictionary dictionaryWithObjectsAndKeys:musicTrack, QTMovieChapterTargetTrackAttribute,nil];
				// add the chapters track to the movie data
				// dont worry about errors because it doesnt really matter if we cant get chapter markers
				NSError *chaptersError = nil;
				[_currentAudioFile addChapters:chaptersArray withAttributes:trackDict error:&chaptersError];
				if(chaptersError == nil) // we successfully added the chapters to the file
				{
					_totalChapters = [_currentAudioFile chapterCount];
					_currentChapterIndex = 0;	
				}
			}
			[self updateForPosInBook];
		}
		
	}
	
}


- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)success
{
	if(_mediaFormat < TextPartialAudioMediaFormat)
	{
		[self updateAudioFile:[_controlDoc currentAudioFilename]];
		[_currentAudioFile play];
	}
	else
	{
		/// text only update calls here 
	}
	
}


@synthesize _skipDuration;
@synthesize _controlDoc,_packageDoc;
@synthesize speechSynth, preferredVoice;
@synthesize playbackRate, playbackVolume,  chapterSkipIncrement, maxLevels;
@synthesize _currentChapterIndex, _totalChapters;
@synthesize _controlMode;
@synthesize textDoc, smilDoc;
@synthesize _bookPath, _currentSegmentFilename, fullBookPath;
@synthesize bookIsAlreadyLoaded, speakUserLevelChange, overrideRecordedContent;

@synthesize _currentAudioFile;
//@synthesize currentPageIndex;
@synthesize playPositionID, audioSegmentTimePosition, shouldJumpToTime;

// bindings related
@synthesize bookTitle, currentSectionTitle;
@synthesize currentLevelString, currentPageString;
@synthesize canPlay, isPlaying;
@synthesize hasNextChapter, hasPreviousChapter;
@synthesize hasLevelUp, hasLevelDown;
@synthesize hasNextSegment, hasPreviousSegment;

@end