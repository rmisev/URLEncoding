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
static NSRegularExpression *regexTabNewline = nil;
static NSRegularExpression *regexInvalidPercent = nil;

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
        // https://infra.spec.whatwg.org/#ascii-tab-or-newline
        regexTabNewline = [NSRegularExpression regularExpressionWithPattern:@"[\\t\\n\\r]" options:0 error:nil];
        regexInvalidPercent = [NSRegularExpression regularExpressionWithPattern:@"%(?![0-9A-Fa-f]{2})" options:0 error:nil];
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

- (NSString *)stringByRemovingTabNewline {
    return [regexTabNewline
            stringByReplacingMatchesInString:self
            options:0
            range:NSMakeRange(0, self.length)
            withTemplate:@""];
}

- (NSString *)percentEncodeInvalidPercents {
    return [regexInvalidPercent
            stringByReplacingMatchesInString:self
            options:0
            range:NSMakeRange(0, self.length)
            withTemplate:@"%25"];
}

- (NSString *)percentEncodeUrlPath {
    return [[self stringByReplacingOccurrencesOfString:@"\\" withString:@"/"]
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowedInPath];
}

- (NSString *)percentEncodeUrlQuery {
    return [self
            stringByAddingPercentEncodingWithAllowedCharacters:
            allowedInQuery];
}

- (NSString *)normalizeUrlFragment {
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

- (nullable NSString *)normalizeUrlString {
    // trim C0 controls and spaces
    NSCharacterSet *charsC0SP = [NSCharacterSet characterSetWithRange:NSMakeRange(0, 0x21)];
    NSString *strUrl = [self stringByTrimmingCharactersInSet:charsC0SP];
    // remove all ASCII tab or newline
    strUrl = strUrl.stringByRemovingTabNewline;

    // has scheme?
    NSRange r = [strUrl rangeOfString:@":" options:NSLiteralSearch];
    if (r.location == NSNotFound) return nil;
    const NSRange rangeOfScheme = NSMakeRange(0, r.location);
    const NSInteger endOfProtocol = r.location + 1; // skip ":"

    // is the scheme supported?
    NSString *scheme = nil;
    for (NSString *specScheme in schemePortDic) {
        if ([strUrl isEqualIgnoreCase:specScheme range:rangeOfScheme]) {
            scheme = specScheme;
            break;
        }
    }
    if (scheme == nil) return strUrl;

    // find end of slashes
    NSInteger endOfSlashes = endOfProtocol;
    while (endOfSlashes < strUrl.length) {
        unichar ch = [strUrl characterAtIndex:endOfSlashes];
        if (ch != '/' && ch != '\\') break;
        endOfSlashes++;
    }
    if (endOfSlashes == strUrl.length)
        return nil; // error: no host

    // authority
    const NSRange rangeOfAuth = [strUrl findPart:endOfAuthChars fromIndex:endOfSlashes];

    // after authority
    NSRange rangeOfPath = NSMakeRange(0, 0);
    NSRange rangeOfQuery = NSMakeRange(0, 0);
    NSRange rangeOfFragment = NSMakeRange(0, 0);
    NSInteger indexOfCh = NSMaxRange(rangeOfAuth);
    if (indexOfCh < strUrl.length) {
        unichar ch = [strUrl characterAtIndex:indexOfCh];
        if (ch == '/' || ch == '\\') {
            rangeOfPath = [strUrl findPart:endOfPathChars fromIndex:indexOfCh];
            NSInteger ind = NSMaxRange(rangeOfPath);
            if (ind < strUrl.length) {
                indexOfCh = ind;
                ch = [strUrl characterAtIndex:indexOfCh];
            }
        }
        if (ch == '?') {
            rangeOfQuery = [strUrl findPart:[NSCharacterSet characterSetWithCharactersInString:@"#"] fromIndex:indexOfCh];
            NSInteger ind = NSMaxRange(rangeOfQuery);
            if (ind < strUrl.length) {
                indexOfCh = ind;
                ch = [strUrl characterAtIndex:indexOfCh];
            }
        }
        if (ch == '#') {
            rangeOfFragment = NSMakeRange(indexOfCh, strUrl.length - indexOfCh);
        }
    }

    // make normalized URL string
    NSMutableString *normUrl = [NSMutableString stringWithCapacity:strUrl.length];
    [normUrl appendString:scheme];
    [normUrl appendString:@"://"];
    [normUrl appendString:[strUrl substringWithRange:rangeOfAuth]];
    if (rangeOfPath.length > 0)
        [normUrl appendString:[strUrl substringWithRange:rangeOfPath].percentEncodeUrlPath];
    else
        [normUrl appendString:@"/"];
    if (rangeOfQuery.length > 0)
        [normUrl appendString:[strUrl substringWithRange:rangeOfQuery].percentEncodeUrlQuery];
    if (rangeOfFragment.length > 0)
        [normUrl appendString:[strUrl substringWithRange:rangeOfFragment].normalizeUrlFragment];

    return normUrl;
}

- (nullable NSURL *)ParseURL {
    NSURL *url = [NSURL URLWithString:self.normalizeUrlString];
    // resolve ".." and "." in the path (standardizedURL)
    return url != nil ? url.standardizedURL : nil;
}

@end
