//
//  NSString+URLEncoding.m
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import "NSString+URLEncoding.h"


static NSDictionary *schemePortDic = nil;
static NSCharacterSet *endOfAuthChars = nil;
static NSCharacterSet *endOfPathChars = nil;
static NSMutableCharacterSet *allowedInPath = nil;
static NSMutableCharacterSet *allowedInQuery = nil;
static NSCharacterSet *allowedInFragment = nil;

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
        NSRange rangeNotC0;
        rangeNotC0.location = 0x20;
        rangeNotC0.length = 0x7f - 0x20;

        // https://url.spec.whatwg.org/#path-percent-encode-set
        allowedInPath = [NSMutableCharacterSet characterSetWithRange:rangeNotC0];
        [allowedInPath removeCharactersInString:@" \"#<>?`{}"];

        // https://url.spec.whatwg.org/#query-state
        allowedInQuery = [NSMutableCharacterSet characterSetWithRange:rangeNotC0];
        [allowedInQuery removeCharactersInString:@"\x22\x23\x3C\x3E"];

        // https://url.spec.whatwg.org/#c0-control-percent-encode-set
        allowedInFragment = [NSCharacterSet characterSetWithRange:rangeNotC0];
    }
}

- (nullable NSString *)percentEncodeUrlPath {
    return [[self stringByReplacingOccurrencesOfString:@"\\" withString:@"/"]
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowedInPath];
}

- (nullable NSString *)percentEncodeUrlQuery {
    return [self
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowedInQuery];
}

- (nullable NSString *)normalizeUrlFragment {
    // https://url.spec.whatwg.org/#fragment-state
    return [[self stringByReplacingOccurrencesOfString:@"\x00" withString:@""]
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowedInFragment];
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
    // has scheme?
    NSRange r = [self rangeOfString:@":" options:NSLiteralSearch];
    if (r.location == NSNotFound) return nil;
    const NSRange rangeOfScheme = NSMakeRange(0, r.location);
    const NSInteger endOfProtocol = r.location + 1; // skip ":"

    // is the scheme supported?
    NSString *scheme = nil;
    for (NSString *specScheme in schemePortDic) {
        if ([self isEqualIgnoreCase:specScheme range:rangeOfScheme]) {
            scheme = specScheme;
            break;
        }
    }
    if (scheme == nil) return self;

    // find end of slashes
    NSInteger endOfSlashes = endOfProtocol;
    while (endOfSlashes < self.length) {
        unichar ch = [self characterAtIndex:endOfSlashes];
        if (ch != '/' && ch != '\\') break;
        endOfSlashes++;
    }
    if (endOfSlashes == self.length)
        return nil; // error: no host

    // authority
    const NSRange rangeOfAuth = [self findPart:endOfAuthChars fromIndex:endOfSlashes];

    // after authority
    NSRange rangeOfPath = NSMakeRange(0, 0);
    NSRange rangeOfQuery = NSMakeRange(0, 0);
    NSRange rangeOfFragment = NSMakeRange(0, 0);
    NSInteger indexOfCh = NSMaxRange(rangeOfAuth);
    if (indexOfCh < self.length) {
        unichar ch = [self characterAtIndex:indexOfCh];
        if (ch == '/' || ch == '\\') {
            rangeOfPath = [self findPart:endOfPathChars fromIndex:indexOfCh];
            NSInteger ind = NSMaxRange(rangeOfPath);
            if (ind < self.length) {
                indexOfCh = ind;
                ch = [self characterAtIndex:indexOfCh];
            }
        }
        if (ch == '?') {
            rangeOfQuery = [self findPart:[NSCharacterSet characterSetWithCharactersInString:@"#"] fromIndex:indexOfCh];
            NSInteger ind = NSMaxRange(rangeOfQuery);
            if (ind < self.length) {
                indexOfCh = ind;
                ch = [self characterAtIndex:indexOfCh];
            }
        }
        if (ch == '#') {
            rangeOfFragment = NSMakeRange(indexOfCh, self.length - indexOfCh);
        }
    }

    // make normalized URL
    NSMutableString *normUrl = [NSMutableString stringWithCapacity:self.length];
    [normUrl appendString:scheme];
    [normUrl appendString:@"://"];
    [normUrl appendString:[self substringWithRange:rangeOfAuth]];
    if (rangeOfPath.length > 0)
        [normUrl appendString:[[self substringWithRange:rangeOfPath] percentEncodeUrlPath]];
    else
        [normUrl appendString:@"/"];
    if (rangeOfQuery.length > 0)
        [normUrl appendString:[[self substringWithRange:rangeOfQuery] percentEncodeUrlQuery]];
    if (rangeOfFragment.length > 0)
        [normUrl appendString:[[self substringWithRange:rangeOfFragment] normalizeUrlFragment]];

    return normUrl;
}

@end
