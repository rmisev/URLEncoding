//
//  NSString+URLEncoding.m
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import <Foundation/Foundation.h>
#import "NSString+URLEncoding.h"


static NSDictionary *schemePortDic = nil;
static NSMutableCharacterSet *allowedInPath = nil;

@implementation NSString (URLEncoding)

+ (void)initialize
{
    if (!schemePortDic) {
        // https://url.spec.whatwg.org/#special-scheme
        schemePortDic = @{
                          @"ftp": @21,
                          @"gopher": @70,
                          @"http": @80,
                          @"https": @443,
                          @"ws": @80,
                          @"wss": @443
                          };
    }
    if (!allowedInPath) {
        // https://url.spec.whatwg.org/#path-percent-encode-set
        NSRange initRange;
        initRange.location = 0x20;
        initRange.length = 0x7e - 0x20 + 1;
        allowedInPath = [NSMutableCharacterSet characterSetWithRange:initRange];
        [allowedInPath removeCharactersInString:@" \"#<>?`{}"];
    }
}

- (nullable NSString *)stringByAddingPercentEncodingForUrlPath {
    return [self
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowedInPath];
}

- (BOOL)isEqualIgnoreCase:(NSString *)aString range:(NSRange)rangeOfReceiver {
    return ([self compare:aString options:NSCaseInsensitiveSearch range:rangeOfReceiver] == NSOrderedSame);
}

@end
