//
//  TBPluginInterface.h
//  TalkingBook Framework
//
//  Created by Kieren Eaton on 19/05/09.
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

#import <Cocoa/Cocoa.h>
@class TBBookData;

@protocol TBPluginInterface 

+ (BOOL)initializeClass:(NSBundle *)theBundle;
+ (void)terminateClass;

// return an enumerated list of instances of all the classes available in the bundle
+ (NSArray *)plugins;

#pragma mark -
#pragma mark Views

// return an instance of the view used in the text window.
// this will allow different plugins to have complete control over the display 
// of the view
- (NSView *)bookTextView;

// return an instance of the view used in the information window.
// this will allow plugins to have their own information laid out as they like
- (NSView *)bookInfoView;

// pass in the plugin for which the book information view will be updated
// this causes the plugin to update its data in the information view.
// Structured this way to allow the principal class not to have to track 
// which plugin is being used. 
- (void)updateInfoFromPlugin:(id)aPlugin;


#pragma mark -
#pragma mark Information

// return a textual description of the Format the book was authored with
- (NSString *)FormatDescription;

// reset the plugin to a state ready for loading a book. 
- (void)reset;

// allow the plugin to use the shared book instance
- (void)setSharedBookData:(id)anInstance;

#pragma mark -
#pragma mark Loading & Saving

// return YES if the book was recognized and opened correctly 
- (BOOL)openBook:(NSURL *)bookURL;

// returns the URL of the file that was deemed by the plugin as the correct one to load first
// used for passing the correct URL for loading to things like recent documents lists
- (NSURL *)loadedURL;

// returns the current time position of the audio file as a QTTime String.
// this can be nil if the book is text only
- (NSString *)currentPlaybackTime;

// returns a string defining the current playback control point
- (NSString *)currentControlPoint;

// this method is used to pass in the control point and time the book should
// start playback from
- (void)jumpToControlPoint:(NSString *)aPoint andTime:(NSString *)aTime;



#pragma mark -
#pragma mark Playback

// start or continue playback of the book
- (void)startPlayback;

// stop playback of the book
- (void)stopPlayback;

#pragma mark -
#pragma mark Navigation

// move to the next element for playback
// used with user navigation 
- (void)nextReadingElement;

// move to the previous element for playback
// used with user navigation
- (void)previousReadingElement;

// move up a level in the book structure if appropriate
// (level 1 is the top level)
- (void)upLevel;

// move down a level in the book structure if appropriate
- (void)downLevel;

   

@end