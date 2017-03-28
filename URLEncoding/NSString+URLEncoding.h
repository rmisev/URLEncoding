//
//  NSString+URLEncoding.h
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

@property(readonly, copy) NSString *normalizeUrlString;
@property(readonly, copy) NSString *percentEncodeUrlPath;

- (BOOL)isEqualIgnoreCase:(NSString *)aString range:(NSRange)rangeOfReceiver;

@end
