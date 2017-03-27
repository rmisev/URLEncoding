//
//  NSString+URLEncoding.m
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import <Foundation/Foundation.h>
#import "NSString+URLEncoding.h"


static NSDictionary *schemePortDic = nil;
static NSCharacterSet *endOfAuthChars = nil;
static NSCharacterSet *endOfPathChars = nil;
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
    if (!endOfAuthChars) {
        endOfAuthChars = [NSCharacterSet characterSetWithCharactersInString:@"/\\?#"];
        endOfPathChars = [NSCharacterSet characterSetWithCharactersInString:@"?#"];
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

- (NSRange)findPart:(NSCharacterSet*)partEndChars fromIndex:(NSInteger)indFrom {
    NSRange rangeToSearch = NSMakeRange(indFrom, self.length - indFrom);
    NSRange r = [self rangeOfCharacterFromSet:partEndChars options:NSLiteralSearch range:rangeToSearch];
    return (r.location == NSNotFound)
        ? rangeToSearch
        : NSMakeRange(rangeToSearch.location, r.location - rangeToSearch.location);
}

- (nullable NSString *)normalizeUrl {
    // is scheme?
    NSRange r = [self rangeOfString:@":" options:NSLiteralSearch];
    if (r.location == NSNotFound) return nil;
    const NSRange rangeOfScheme = NSMakeRange(0, r.location);
    const NSInteger endOfProtocol = r.location + 1; // skip ":"
    
    // is supported scheme?
    NSString *scheme = nil;
    for (NSString *specScheme in schemePortDic) {
        if ([self isEqualIgnoreCase:specScheme range:rangeOfScheme]) {
            scheme = specScheme;
            break;
        }
    }
    if (scheme == nil) return self;
    
    // count slashes
    NSInteger countSlashes = 0;
    for (NSInteger ind = endOfProtocol; ind < self.length; ind++) {
        unichar ch = [self characterAtIndex:ind];
        if (ch != '/' && ch != '\\') break;
        countSlashes++;
    }

    // authority
    const NSRange rangeOfAuth = [self findPart:endOfAuthChars fromIndex:endOfProtocol + countSlashes];
    
    // after authority
    NSRange rangeOfPath = NSMakeRange(0, 0);
    NSRange rangeOfQuery = NSMakeRange(0, 0);
    NSRange rangeOfFragment = NSMakeRange(0, 0);
    NSInteger indNext = NSMaxRange(rangeOfAuth);
    if (indNext < self.length) {
        unichar ch = [self characterAtIndex:indNext];
        if (ch == '/' || ch == '\\') {
            rangeOfPath = [self findPart:endOfPathChars fromIndex:indNext];
            indNext = NSMaxRange(rangeOfPath);
            if (indNext < self.length)
                ch = [self characterAtIndex:indNext];
        }
        if (ch == '?') {
            rangeOfQuery = [self findPart:[NSCharacterSet characterSetWithCharactersInString:@"#"] fromIndex:indNext];
            indNext = NSMaxRange(rangeOfQuery);
            if (indNext < self.length)
                ch = [self characterAtIndex:indNext];
        }
        if (ch == '#') {
            rangeOfFragment = NSMakeRange(indNext, self.length - indNext);
        }
    }
    
    // make normalized URL
    NSMutableString *normUrl = [NSMutableString stringWithCapacity:self.length];
    [normUrl appendString:scheme];
    [normUrl appendString:@"://"];
    [normUrl appendString:[self substringWithRange:rangeOfAuth]];
    if (rangeOfPath.length > 0)
        [normUrl appendString:[[self substringWithRange:rangeOfPath] stringByAddingPercentEncodingForUrlPath]];
    if (rangeOfQuery.length > 0)
        [normUrl appendString:[self substringWithRange:rangeOfQuery]];
    if (rangeOfFragment.length > 0)
        [normUrl appendString:[self substringWithRange:rangeOfFragment]];
    
    return normUrl;
}

@end
