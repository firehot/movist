//
//  Movist
//
//  Copyright 2006, 2007 Yong-Hoe Kim. All rights reserved.
//      Yong-Hoe Kim  <cocoable@gmail.com>
//
//  This file is part of Movist.
//
//  Movist is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  Movist is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "FullNavView.h"

#import "AppController.h"
#import "MMovieView.h"
#import "FullNavItems.h"
#import "FullNavListView.h"

@interface FullNavTitleView : NSView
{
    NSImage* _icon;
    NSString* _title;
}

- (void)setIcon:(NSImage*)icon title:(NSString*)title;

@end

@implementation FullNavTitleView

- (void)drawRect:(NSRect)rect
{
    NSMutableParagraphStyle* paragraphStyle;
    paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];

    NSRect br = [self bounds];
    NSMutableDictionary* attrs;
    attrs = [[[NSMutableDictionary alloc] init] autorelease];
    [attrs setObject:[NSColor colorWithDeviceWhite:0.95 alpha:1.0]
              forKey:NSForegroundColorAttributeName];
    [attrs setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
    [attrs setObject:[NSFont boldSystemFontOfSize:60 * br.size.width / 640.0]
              forKey:NSFontAttributeName];

    NSRect tr;
    tr.size = [_title sizeWithAttributes:attrs];
    if (_icon) {
        const int ICON_SIZE = [self bounds].size.height;
        const int ICON_MARGIN = ICON_SIZE * 0.15;
        NSRect rc;
        rc.size.width = ICON_SIZE;
        rc.size.height= ICON_SIZE;
        float width = rc.size.width + ICON_MARGIN + tr.size.width;
        if (br.size.width < width) {
            tr.size.width -= width - br.size.width;
            width -= width - br.size.width;
        }
        rc.origin.x = br.origin.x + (br.size.width - width) / 2;
        rc.origin.y = br.origin.y + (br.size.height - rc.size.height) / 2;
        [_icon drawInRect:rc fromRect:NSZeroRect
                operation:NSCompositeSourceOver fraction:1.0];

        tr.origin.x = rc.origin.x + rc.size.width + ICON_MARGIN;
    }
    else {
        if (br.size.width < tr.size.width) {
            tr.size.width -= tr.size.width - br.size.width;
        }
        tr.origin.x = br.origin.x + (br.size.width - tr.size.width) / 2;
    }
    tr.origin.y = br.origin.y + (br.size.height - tr.size.height)/ 2;
    [_title drawInRect:tr withAttributes:attrs];

    //[[NSColor grayColor] set];
    //NSFrameRect([self bounds]);
}

- (void)setIcon:(NSImage*)icon title:(NSString*)title
{
    [icon retain], [_icon release], _icon = icon;
    [title retain], [_title release], _title = title;
    [self display];
}

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark

@interface FullNavListContainerView : NSView
{
}

@end

@implementation FullNavListContainerView
/*
- (void)drawRect:(NSRect)rect
{
    [[NSColor greenColor] set];
    NSFrameRect([self bounds]);
}
*/
@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark

@implementation FullNavView

- (id)initWithFrame:(NSRect)rect movieView:(MMovieView*)movieView
{
    if (self = [super initWithFrame:rect]) {
        _movieView = [movieView retain];

        float titleHeight   = (float)(int)(rect.size.height * 0.095);
        float gap           = (float)(int)(rect.size.height * 0.025);
        float listHeight    = (float)(int)(rect.size.height * 0.66);
        float BOTTOM_MARGIN = (float)(int)(rect.size.height * 0.115);

        // list view
        rect = [self bounds];
        rect.origin.y = BOTTOM_MARGIN;
        rect.size.height = listHeight;
        NSView* lcv = [[FullNavListContainerView alloc] initWithFrame:rect];
        _listView = [[FullNavListView alloc] initWithFrame:[lcv bounds]
                                                    window:[movieView window]];
        [self addSubview:[lcv autorelease]];
        [lcv addSubview:_listView];

        // title view
        rect.origin.y += listHeight + gap;
        rect.size.height = titleHeight;
        _titleView = [[FullNavTitleView alloc] initWithFrame:rect];
        [self addSubview:_titleView];

        // list array
        _listArray = [[NSMutableArray alloc] initWithCapacity:4];
        [self initListRoot];
    }
    return self;
}

- (void)dealloc
{
    [_movieView release];
    [_listArray release];
    [super dealloc];
}
/*
- (void)drawRect:(NSRect)rect
{
    [[NSColor grayColor] set];
    NSFrameRect([self bounds]);
}
*/
- (void)setHidden:(BOOL)hidden
{
    (hidden) ? [_listView hideSelBox] : [_listView showSelBox];
    [super setHidden:hidden];
}

- (void)keyDown:(NSEvent*)event
{
    //TRACE(@"%s \"%@\" (modifierFlags=%u)", __PRETTY_FUNCTION__,
    //      [event characters], [event modifierFlags]);
    unichar key = [[event characters] characterAtIndex:0];
    //unsigned int modifierFlags = [event modifierFlags] &
    //    (NSCommandKeyMask | NSAlternateKeyMask | NSControlKeyMask | NSShiftKeyMask);
    switch (key) {
        case NSUpArrowFunctionKey :         // up arrow
            [self selectUpper];
            break;
        case NSDownArrowFunctionKey :       // down arrow
            [self selectLower];
            break;
        case ' ' :                          // space: toggle play/pause
        case NSCarriageReturnCharacter :    // return : toggle full-screen
        case NSEnterCharacter :             // enter (in keypad)
        //case NSRightArrowFunctionKey :      // right arrow
            [self openCurrent];
            break;
        case 27 :                           // ESC
        //case NSBackspaceCharacter :         // backsapce
        //case NSLeftArrowFunctionKey :       // left arrow
            if (![self closeCurrent]) {
                [[NSApp delegate] endFullNavigation];
            }
            break;
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark list

- (void)initListRoot
{
    NSMutableArray* items = [NSMutableArray arrayWithCapacity:6];

    // home Movies folder
    NSString* path = [@"~/Movies" stringByExpandingTildeInPath];
    NSString* name = nil;
    [items addObject:[FullNavDirectoryItem fullNavDirectoryItemWithPath:path name:name]];
/*
    // iTunes Movies folder
    path = [@"~/Music/iTunes/iTunes Music/Movies" stringByExpandingTildeInPath];
    name = [NSString stringWithFormat:@"iTunes %@", [(FullNavDirectoryItem*)[items lastObject] name]];
    [items addObject:[FullNavDirectoryItem fullNavDirectoryItemWithPath:path name:name]];

    // iTunes Podcast folder (for video podcast)
    path = [@"~/Music/iTunes/iTunes Music/Podcast" stringByExpandingTildeInPath];
    name = nil;
    [items addObject:[FullNavDirectoryItem fullNavDirectoryItemWithPath:path name:name]];
*/
    [self addNavListWithParentItem:nil items:items];
}

- (void)updateListUI
{
    FullNavList* list = [_listArray lastObject];
    FullNavItem* item = [list parentItem];
    NSImage* icon = nil;
    NSString* title = nil;
    if (!item) {
        icon = [NSImage imageNamed:@"Movist"];
        title = NSLocalizedString(@"Movist", nil);
    }
    else {
        if ([item isMemberOfClass:[FullNavDirectoryItem class]]) {
            NSString* path = [(FullNavDirectoryItem*)item path];
            icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
        }
        title = [item name];
    }
    [_titleView setIcon:icon title:title];
    [_listView setNavList:list];
    [self showPreview];
}

- (void)addNavListWithParentItem:(FullNavItem*)parentItem items:(NSArray*)items
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    [_listArray addObject:[[FullNavList alloc] initWithParentItem:parentItem items:items]];
    [self updateListUI];
}

- (void)removeLastNavList
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    if ([self canCloseCurrent]) {    // cannot remove root list
        [_listArray removeLastObject];
        [self updateListUI];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark selection

- (void)selectUpper
{
    FullNavList* list = (FullNavList*)[_listArray lastObject];
    if (0 < [list selectedIndex]) {
        //[self hidePreview];
        [list selectUpper];
        [self showPreview];
        [_listView slideSelBox];
        //[_listView setNeedsDisplay:TRUE];
    }
}

- (void)selectLower
{
    FullNavList* list = (FullNavList*)[_listArray lastObject];
    if ([list selectedIndex] < [list count] - 1) {
        //[self hidePreview];
        [list selectLower];
        [self showPreview];
        [_listView slideSelBox];
        //[_listView setNeedsDisplay:TRUE];
    }
}

- (void)selectMovie:(NSURL*)movieURL
{
    FullNavList* list = (FullNavList*)[_listArray lastObject];

    // assume movieURL is file URL.
    NSString* path = [movieURL path];
    FullNavFileItem* item;
    int i, count = [list count];
    for (i = 0; i < count; i++) {
        item = (FullNavFileItem*)[list itemAtIndex:i];
        if ([path isEqualToString:[item path]]) {
            break;
        }
    }
    if (i < count && i != [list selectedIndex]) {
        //if (![self isHidden]) {
        //    [self hidePreview];
        //}
        [list selectAtIndex:i];
        if (![self isHidden]) {
            [self showPreview];
            [_listView slideSelBox];
            //[_listView setNeedsDisplay:TRUE];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark open & close

#define FADE_DURATION   0.25

- (BOOL)canCloseCurrent { return (1 < [_listArray count]); }

- (void)openCurrent
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    NSWindow* window = [self window];
    FullNavList* list = (FullNavList*)[_listArray lastObject];
    FullNavItem* item = [list selectedItem];
    if (item == nil) {
        // do nothing
    }
    else if ([item hasSubContents]) {
        // enter into sub-contents
        [[window screen] fadeOut:FADE_DURATION];

        [self addNavListWithParentItem:item items:[item subContents]];

        [window flushWindow];
        [[window screen] fadeIn:FADE_DURATION];
    }
    else {
        // open current movie
        [[window screen] fadeOut:FADE_DURATION];

        [self hidePreview];
        [self setHidden:TRUE];
        [_listView hideSelBox];
        [_movieView hideLogo];
        [_movieView setFrame:[[window contentView] bounds]];
        [_movieView setHidden:FALSE];
        [window makeFirstResponder:_movieView];

        [_movieView display];
        [window flushWindow];
        [[window screen] fadeIn:FADE_DURATION];

        if ([item isMemberOfClass:[FullNavFileItem class]]) {
            [[NSApp delegate] openFile:[(FullNavFileItem*)item path]];
        }
        else if ([item isMemberOfClass:[FullNavURLItem class]]) {
            [[NSApp delegate] openURL:[(FullNavURLItem*)item URL]];
        }
    }
}

- (BOOL)closeCurrent
{
    TRACE(@"%s", __PRETTY_FUNCTION__);
    NSWindow* window = [self window];
    NSScreen* screen = [window screen];
    if ([self isHidden]) {
        // exit from full-screen movie
        [[_movieView movie] setRate:0.0];
        [screen fadeOut:FADE_DURATION];

        [self hidePreview];     // hide _movieView
        [self setHidden:FALSE];
        [self showPreview];
        [_listView showSelBox];
        [window makeFirstResponder:self];

        [window flushWindow];
        [screen fadeIn:FADE_DURATION];
        return TRUE;
    }
    else if ([self canCloseCurrent]) {
        // exit from sub-contents
        [screen fadeOut:FADE_DURATION];

        [self hidePreview];
        [self removeLastNavList];

        [window flushWindow];
        [screen fadeIn:FADE_DURATION];
        return TRUE;
    }
    return FALSE;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark preview

- (void)endPreviewTimer
{
    if (_previewTimer) {
        if ([_previewTimer isValid]) {
            [_previewTimer invalidate];
        }
        _previewTimer = nil;
    }
}

- (void)showPreview:(NSTimer*)timer
{
    [self endPreviewTimer];
    [_movieView setError:nil info:nil]; // clear previous error

    FullNavItem* item = [(FullNavList*)[_listArray lastObject] selectedItem];
    if (item == nil) {
        // do nothing
    }
    else if ([item hasSubContents]) {
        [self hidePreview];
    }
    else {
        if ([item isMemberOfClass:[FullNavFileItem class]]) {
            [[NSApp delegate] openFile:[(FullNavFileItem*)item path]
                             addSeries:FALSE];
        }
        else if ([item isMemberOfClass:[FullNavURLItem class]]) {
            [[NSApp delegate] openURL:[(FullNavURLItem*)item URL]];
        }
        [_movieView setFrame:[self previewRect]];
        [_movieView setHidden:FALSE];
    }
}

- (void)showPreview
{
    [self endPreviewTimer];    // release previous timer
    _previewTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                target:self selector:@selector(showPreview:)
                                userInfo:nil repeats:FALSE];
}

- (void)hidePreview
{
    if (![_movieView isHidden]) {
        [[NSApp delegate] closeMovie];
        [_movieView setError:nil info:nil];
        [_movieView display];
        [_movieView setHidden:TRUE];
    }
}

- (NSRect)previewRect
{
    NSSize movieSize;
    MMovie* movie = [(AppController*)[NSApp delegate] movie];
    if (movie) {
        [movie setMuted:TRUE]; // always muted in preview
        movieSize = [movie size];
    }
    else {
        movieSize = NSMakeSize(640, 360);
    }
    NSRect rc = [[_movieView superview] bounds];
    rc.size.width /= 2;

    float IN_MARGIN  = (float)(int)(rc.size.width * 0.075);
    float OUT_MARGIN = (float)(int)(rc.size.width * 0.195);
    rc.origin.x += OUT_MARGIN, rc.size.width -= OUT_MARGIN + IN_MARGIN;
    float height = rc.size.width * movieSize.height / movieSize.width;
    rc.origin.y += (rc.size.height - height) / 2, rc.size.height = height;
    return rc;
}

@end
