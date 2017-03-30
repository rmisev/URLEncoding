//
//  NSString+URLEncoding.h
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

@property(readonly, copy) NSURL *ParseURL;
@property(readonly, copy) NSString *normalizeUrlString;

// Encodes "%" not followed by two ASCII hex digits
@property(readonly, copy) NSString *percentEncodeInvalidPercents;

@property(readonly, copy) NSString *percentEncodeUrlPath;

- (BOOL)isEqualIgnoreCase:(NSString *)aString range:(NSRange)rangeOfReceiver;

@end
