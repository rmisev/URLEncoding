//
//  NSString+URLEncoding.h
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

@property(readonly, copy) NSString *stringByAddingPercentEncodingForUrlPath;
@property(readonly, copy) NSString *normalizeUrl;

- (BOOL)isEqualIgnoreCase:(NSString *)aString range:(NSRange)rangeOfReceiver;

@end
