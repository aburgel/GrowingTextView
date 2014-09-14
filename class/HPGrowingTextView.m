//
//  HPTextView.m
//
//  Created by Hans Pinckaers on 29-06-10.
//
//	MIT License
//
//	Copyright (c) 2011 Hans Pinckaers
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

#import "HPGrowingTextView.h"

@interface HPGrowingTextView ()

- (void)commonInitialiser;
- (void)resizeTextView:(CGFloat)height;
- (void)growDidStop;

@end

@implementation HPGrowingTextView
{
    BOOL _isShowingPlaceholder;
    UIColor *_textColor;
}

// having initwithcoder allows us to use HPGrowingTextView in a Nib. -- aob, 9/2011
- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInitialiser];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInitialiser];
    }
    return self;
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
- (id)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer {
    if ((self = [super initWithFrame:frame])) {
        [self commonInitialiser:textContainer];
    }
    return self;
}

-(void)commonInitialiser {
    [self commonInitialiser:nil];
}

-(void)commonInitialiser:(NSTextContainer *)textContainer
#else
-(void)commonInitialiser
#endif
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
    _internalTextView = [[UITextView alloc] initWithFrame:self.bounds textContainer:textContainer];
#else
    _internalTextView = [[UITextView alloc] initWithFrame:self.bounds];
#endif
    _internalTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _internalTextView.delegate = self;
    _internalTextView.scrollEnabled = NO;
    _internalTextView.font = [UIFont fontWithName:@"Helvetica" size:13];
    _internalTextView.contentInset = UIEdgeInsetsZero;
    _internalTextView.showsHorizontalScrollIndicator = NO;
    _internalTextView.text = @"";
    [self addSubview:_internalTextView];

    _textColor = _internalTextView.textColor;

    _minHeight = _internalTextView.frame.size.height;
    _maxHeight = CGFLOAT_MAX;

    _animateHeightChange = YES;
    _animationDuration = 0.1f;
    _isShowingPlaceholder = NO;

    self.placeholderColor = [UIColor lightGrayColor];

    [self setMinNumberOfLines:1];
    [self setMaxNumberOfLines:3];
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (self.text.length == 0) {
        size.height = self.minHeight;
    }
    return size;
}

- (void)setContentInset:(UIEdgeInsets)inset {
    _contentInset = inset;

    CGRect insetFrame = UIEdgeInsetsInsetRect(self.internalTextView.frame, inset);
    self.internalTextView.frame = insetFrame;
}

- (void)setMaxNumberOfLines:(NSInteger)maxNumberOfLines {
    if (maxNumberOfLines == 0 && self.maxHeight > 0) return; // the user specified a maxHeight themselves.

    // Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = self.text;
    NSString *newText = @"-";

    self.internalTextView.delegate = nil;
    self.internalTextView.hidden = YES;

    for (NSInteger i = 1; i < maxNumberOfLines; ++i)
        newText = [newText stringByAppendingString:@"\n|W|"];

    self.internalTextView.text = newText;

    _maxHeight = [self measureHeight];

    self.internalTextView.text = saveText;
    self.internalTextView.hidden = NO;
    self.internalTextView.delegate = self;

    [self sizeToFit];

    _maxNumberOfLines = maxNumberOfLines;
}

- (void)setMaxHeight:(CGFloat)maxHeight
{
    _maxHeight = maxHeight;
    self.maxNumberOfLines = 0;
}

-(void)setMinNumberOfLines:(NSInteger)minNumberOfLines
{
    if (minNumberOfLines == 0 && self.minHeight > 0) return; // the user specified a minHeight themselves.

	// Use internalTextView for height calculations, thanks to Gwynne <http://blog.darkrainfall.org/>
    NSString *saveText = self.text;
    NSString *newText = @"-";

    self.internalTextView.delegate = nil;
    self.internalTextView.hidden = YES;

    for (NSInteger i = 1; i < minNumberOfLines; ++i)
        newText = [newText stringByAppendingString:@"\n|W|"];

    self.internalTextView.text = newText;

    _minHeight = [self measureHeight];

    self.internalTextView.text = saveText;
    self.internalTextView.hidden = NO;
    self.internalTextView.delegate = self;

    [self sizeToFit];

    _minNumberOfLines = minNumberOfLines;
}

- (void)setMinHeight:(CGFloat)minHeight
{
    _minHeight = minHeight;
    self.minNumberOfLines = 0;
}

- (void)setPlaceholder:(NSString *)placeholder {
    _placeholder = placeholder;
    if ( self.text == nil || self.text.length == 0 || _isShowingPlaceholder ) {
        self.text = _placeholder;
        self.internalTextView.textColor = self.placeholderColor;
        _isShowingPlaceholder = YES;
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self refreshHeight];
}

- (void)refreshHeight
{
	//size of content, so we can set the frame of self
	CGFloat newSizeH = [self measureHeight];
	if (newSizeH < self.minHeight || !self.internalTextView.hasText) {
        newSizeH = self.minHeight; // not smaller than minHeight
    }
    else if (self.maxHeight && self.internalTextView.frame.size.height > self.maxHeight) {
        newSizeH = self.maxHeight; // not taller than maxHeight
    }

	if (self.internalTextView.frame.size.height != newSizeH) {
        // [fixed] Pasting too much text into the view failed to fire the height change,
        // thanks to Gwynne <http://blog.darkrainfall.org/>

        if (newSizeH > self.maxHeight && self.internalTextView.frame.size.height <= self.maxHeight)
            newSizeH = self.maxHeight;

		if (newSizeH <= self.maxHeight) {
            if (self.animateHeightChange) {

                if ([UIView resolveClassMethod:@selector(animateWithDuration:animations:)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
                    [UIView animateWithDuration:self.animationDuration
                                          delay:0 
                                        options:(UIViewAnimationOptionAllowUserInteraction|
                                                 UIViewAnimationOptionBeginFromCurrentState)
                                     animations:^(void) {
                                         [self resizeTextView:newSizeH];
                                     }
                                     completion:^(BOOL finished) {
                                         if ([_delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
                                             [_delegate growingTextView:self didChangeHeight:newSizeH];
                                         }
                                     }];
#endif
                } else {
                    [UIView beginAnimations:@"" context:nil];
                    [UIView setAnimationDuration:self.animationDuration];
                    [UIView setAnimationDelegate:self];
                    [UIView setAnimationDidStopSelector:@selector(growDidStop)];
                    [UIView setAnimationBeginsFromCurrentState:YES];
                    [self resizeTextView:newSizeH];
                    [UIView commitAnimations];
                }
            } else {
                [self resizeTextView:newSizeH];
                // [fixed] The growingTextView:didChangeHeight: delegate method was not called at all when not animating height changes.
                // thanks to Gwynne <http://blog.darkrainfall.org/>

                if ([self.delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
                    [self.delegate growingTextView:self didChangeHeight:newSizeH];
                }
            }
		}

        // if our new height is greater than the maxHeight
        // sets not set the height or move things
        // around and enable scrolling
		if (newSizeH >= self.maxHeight) {
			if (!self.internalTextView.scrollEnabled){
				self.internalTextView.scrollEnabled = YES;
				[self.internalTextView flashScrollIndicators];
			}
		} else {
			self.internalTextView.scrollEnabled = NO;
		}

        // scroll to caret (needed on iOS7)
        if ([self respondsToSelector:@selector(snapshotViewAfterScreenUpdates:)])
        {
            CGRect r = [self.internalTextView caretRectForPosition:self.internalTextView.selectedTextRange.end];
            CGFloat caretY =  MAX(r.origin.y - self.internalTextView.frame.size.height + r.size.height + 8, 0);
            if (self.internalTextView.contentOffset.y < caretY && r.origin.y != INFINITY)
                self.internalTextView.contentOffset = CGPointMake(0, MIN(caretY, self.internalTextView.contentSize.height));
        }
	}

    // Tell the delegate that the text view changed
    if ([self.delegate respondsToSelector:@selector(growingTextViewDidChange:)]) {
		[self.delegate growingTextViewDidChange:self];
	}
}

// Code from apple developer forum - @Steve Krulewitz, @Mark Marszal, @Eric Silverberg
- (CGFloat)measureHeight {
    CGFloat height;
    if ([NSAttributedString class] && [NSAttributedString instancesRespondToSelector:@selector(boundingRectWithSize:options:context:)]) {
        CGRect frame = self.internalTextView.bounds;

        // The padding added around the text on iOS6 and iOS7 is different.
        CGSize fudgeFactor = CGSizeMake(10.0, 16.0);

        frame.size.height -= fudgeFactor.height;
        frame.size.width -= fudgeFactor.width;

        NSMutableAttributedString *textToMeasure;
        if (self.internalTextView.attributedText && self.internalTextView.attributedText.length > 0) {
            textToMeasure = [[NSMutableAttributedString alloc] initWithAttributedString:self.internalTextView.attributedText];
        }
        else {
            textToMeasure = [[NSMutableAttributedString alloc] initWithString:self.internalTextView.text attributes:@{NSFontAttributeName: self.internalTextView.font}];
        }

        if ([textToMeasure.string hasSuffix:@"\n"]) {
            [textToMeasure appendAttributedString:[[NSAttributedString alloc] initWithString:@"-" attributes:@{NSFontAttributeName: self.internalTextView.font}]];
        }

        // NSAttributedString class method: boundingRectWithSize:options:context is
        // available only on ios6.0 sdk.
        CGRect size = [textToMeasure boundingRectWithSize:CGSizeMake(CGRectGetWidth(frame), CGFLOAT_MAX)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                                  context:nil];

        height = ceil(CGRectGetHeight(size) + fudgeFactor.height);
    }
    else
    {
        height = self.internalTextView.contentSize.height;
    }

    return height + self.contentInset.top + self.contentInset.bottom;
}

- (void)resizeTextView:(CGFloat)height
{
    if ([self.delegate respondsToSelector:@selector(growingTextView:willChangeHeight:)]) {
        [self.delegate growingTextView:self willChangeHeight:height];
    }

    CGRect internalTextViewFrame = self.frame;
    internalTextViewFrame.size.height = height; // + padding
    self.frame = internalTextViewFrame;
}

- (void)growDidStop {
	if ([self.delegate respondsToSelector:@selector(growingTextView:didChangeHeight:)]) {
		[self.delegate growingTextView:self didChangeHeight:self.frame.size.height];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.internalTextView becomeFirstResponder];
}

- (BOOL)becomeFirstResponder {
    [super becomeFirstResponder];
    return [self.internalTextView becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
	[super resignFirstResponder];
	return [self.internalTextView resignFirstResponder];
}

- (BOOL)isFirstResponder {
    return [self.internalTextView isFirstResponder];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITextView properties
///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setText:(NSString *)newText {
    self.internalTextView.text = newText;

    if ( (!newText || newText.length == 0) && ![self.internalTextView isFirstResponder] )
    {
        self.internalTextView.text = self.placeholder;
        self.internalTextView.textColor = self.placeholderColor;
        _isShowingPlaceholder = YES;
    }
    else if ( _isShowingPlaceholder )
    {
        self.internalTextView.textColor = self.textColor;
        _isShowingPlaceholder = NO;
    }

    // include this line to analyze the height of the textview.
    // fix from Ankit Thakur
    [self textViewDidChange:self.internalTextView];
}

- (NSString *)text {
    if ( _isShowingPlaceholder )
        return @"";

    return self.internalTextView.text;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setFont:(UIFont *)afont {
	self.internalTextView.font = afont;

	[self setMaxNumberOfLines:_maxNumberOfLines];
	[self setMinNumberOfLines:_minNumberOfLines];
}

- (UIFont *)font {
	return self.internalTextView.font;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setTextColor:(UIColor *)color {
    _textColor = color;
	self.internalTextView.textColor = color;
}

- (UIColor *)textColor {
	return _textColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:backgroundColor];
	self.internalTextView.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor {
    return self.internalTextView.backgroundColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setTextAlignment:(NSTextAlignment)aligment {
	self.internalTextView.textAlignment = aligment;
}

- (NSTextAlignment)textAlignment {
	return self.internalTextView.textAlignment;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setSelectedRange:(NSRange)range {
	self.internalTextView.selectedRange = range;
}

- (NSRange)selectedRange {
	return self.internalTextView.selectedRange;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setIsScrollable:(BOOL)isScrollable {
    self.internalTextView.scrollEnabled = isScrollable;
}

- (BOOL)isScrollable {
    return self.internalTextView.scrollEnabled;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)setEditable:(BOOL)editable {
	self.internalTextView.editable = editable;
}

- (BOOL)isEditable {
	return self.internalTextView.editable;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setReturnKeyType:(UIReturnKeyType)keyType {
	self.internalTextView.returnKeyType = keyType;
}

- (UIReturnKeyType)returnKeyType {
	return self.internalTextView.returnKeyType;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setKeyboardType:(UIKeyboardType)keyType {
	self.internalTextView.keyboardType = keyType;
}

- (UIKeyboardType)keyboardType {
	return self.internalTextView.keyboardType;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setEnablesReturnKeyAutomatically:(BOOL)enablesReturnKeyAutomatically {
    self.internalTextView.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically;
}

- (BOOL)enablesReturnKeyAutomatically {
    return self.internalTextView.enablesReturnKeyAutomatically;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setDataDetectorTypes:(UIDataDetectorTypes)datadetector {
	self.internalTextView.dataDetectorTypes = datadetector;
}

- (UIDataDetectorTypes)dataDetectorTypes {
	return self.internalTextView.dataDetectorTypes;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasText {
	return [self.internalTextView hasText];
}

- (void)scrollRangeToVisible:(NSRange)range
{
	[self.internalTextView scrollRangeToVisible:range];
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UITextViewDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
	if ([self.delegate respondsToSelector:@selector(growingTextViewShouldBeginEditing:)]) {
		return [self.delegate growingTextViewShouldBeginEditing:self];
	} else {
		return YES;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
	if ([self.delegate respondsToSelector:@selector(growingTextViewShouldEndEditing:)]) {
		return [self.delegate growingTextViewShouldEndEditing:self];
	} else {
		return YES;
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ( _isShowingPlaceholder )
        self.text = @"";

	if ([self.delegate respondsToSelector:@selector(growingTextViewDidBeginEditing:)]) {
		[self.delegate growingTextViewDidBeginEditing:self];
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidEndEditing:(UITextView *)textView {
	if ([self.delegate respondsToSelector:@selector(growingTextViewDidEndEditing:)]) {
		[self.delegate growingTextViewDidEndEditing:self];
	}

    if ( textView.text == nil || textView.text.length == 0 )
        self.text = @"";
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range
 replacementText:(NSString *)atext {

	//weird 1 pixel bug when clicking backspace when textView is empty
	if (![textView hasText] && [atext isEqualToString:@""])
        return NO;

	//Added by bretdabaker: sometimes we want to handle this ourselves
    if ([self.delegate respondsToSelector:@selector(growingTextView:shouldChangeTextInRange:replacementText:)])
        return [self.delegate growingTextView:self shouldChangeTextInRange:range replacementText:atext];

	if ([atext isEqualToString:@"\n"]) {
		if ([self.delegate respondsToSelector:@selector(growingTextViewShouldReturn:)]) {
			if (![self.delegate growingTextViewShouldReturn:self]) {
				return YES;
			} else {
				[textView resignFirstResponder];
				return NO;
			}
		}
	}

	return YES;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)textViewDidChangeSelection:(UITextView *)textView {
	if ([self.delegate respondsToSelector:@selector(growingTextViewDidChangeSelection:)]) {
		[self.delegate growingTextViewDidChangeSelection:self];
	}
}

@end
