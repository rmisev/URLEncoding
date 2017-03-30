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
static NSMutableCharacterSet *allowedInUserinfo = nil;
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

        // https://url.spec.whatwg.org/#userinfo-percent-encode-set
        allowedInUserinfo = [NSMutableCharacterSet characterSetWithRange:rangeNotC0];
        [allowedInUserinfo removeCharactersInString:@" \"#<>?`{}/:;=@[\\]^|"];

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
            .percentEncodeInvalidPercents
            stringByAddingPercentEncodingWithAllowedCharacters:allowedInPath];
}

- (NSString *)percentEncodeUserinfo {
    return [self.percentEncodeInvalidPercents
            stringByAddingPercentEncodingWithAllowedCharacters:allowedInUserinfo];
}

- (NSString *)percentEncodeUrlQuery {
    return [self.percentEncodeInvalidPercents
            stringByAddingPercentEncodingWithAllowedCharacters:allowedInQuery];
}

- (NSString *)normalizeUrlFragment {
    // https://url.spec.whatwg.org/#fragment-state
    return [[self stringByReplacingOccurrencesOfString:@"\x00" withString:@""]
            .percentEncodeInvalidPercents
            stringByAddingPercentEncodingWithAllowedCharacters:allowedInFragment];
}

- (BOOL)isEqualIgnoreCase:(NSString *)aString range:(NSRange)rangeOfReceiver {
    return ([self compare:aString options:NSCaseInsensitiveSearch range:rangeOfReceiver] == NSOrderedSame);
}

- (NSInteger)defaultPortOfScheme:(NSString*)scheme {
    id val = schemePortDic[scheme];
    return val != nil ? [val integerValue] : -1;
}

- (NSInteger)portToInteger:(NSRange)range {
    NSInteger n = 0;
    for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
        unichar ch = [self characterAtIndex:i];
        if (ch < '0' || ch > '9') return -1;
        n = n * 10 + (ch - '0');
        if (n > 0xFFFF) return -1;
    }
    return n;
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
    const NSRange schemeRange = NSMakeRange(0, r.location);
    const NSInteger endOfProtocol = r.location + 1; // skip ":"

    // is the scheme supported?
    NSString *scheme = nil;
    for (NSString *specScheme in schemePortDic) {
        if ([strUrl isEqualIgnoreCase:specScheme range:schemeRange]) {
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
    const NSRange authRange = [strUrl findPart:endOfAuthChars fromIndex:endOfSlashes];

    // credentials & host
    NSRange usernameRange = NSMakeRange(0, 0);
    NSRange passwordRange = NSMakeRange(0, 0);
    NSRange hostRange;
    NSUInteger indEta = [strUrl rangeOfString:@"@" options:NSLiteralSearch|NSBackwardsSearch range:authRange].location;
    if (indEta != NSNotFound) {
        NSRange credentialsRange = NSMakeRange(authRange.location, indEta - authRange.location);
        NSUInteger indColon = [strUrl rangeOfString:@":" options:NSLiteralSearch range:credentialsRange].location;
        if (indColon != NSNotFound) {
            usernameRange = NSMakeRange(credentialsRange.location, indColon - credentialsRange.location);
            passwordRange = NSMakeRange(indColon + 1, indEta - (indColon + 1));
        } else {
            usernameRange = credentialsRange;
        }
        hostRange = NSMakeRange(indEta + 1, NSMaxRange(authRange) - (indEta + 1));
    } else {
        hostRange = authRange;
    }

    // hostname & port
    NSRange hostnameRange;
    NSInteger port;
    NSUInteger indPortSep = [strUrl rangeOfString:@":" options:NSLiteralSearch range:hostRange].location;
    if (indPortSep != NSNotFound) {
        hostnameRange = NSMakeRange(hostRange.location, indPortSep - hostRange.location);
        NSRange portRange = NSMakeRange(indPortSep + 1, NSMaxRange(hostRange) - (indPortSep + 1));
        port = [strUrl portToInteger:portRange];
        if (port < 0) return nil; // error: invalid port
    } else {
        hostnameRange = hostRange;
        port = -1;
    }

    // after authority
    NSRange pathRange = NSMakeRange(0, 0);
    NSRange queryRange = NSMakeRange(0, 0);
    NSRange fragmentRange = NSMakeRange(0, 0);
    NSInteger indexOfCh = NSMaxRange(authRange);
    if (indexOfCh < strUrl.length) {
        unichar ch = [strUrl characterAtIndex:indexOfCh];
        if (ch == '/' || ch == '\\') {
            pathRange = [strUrl findPart:endOfPathChars fromIndex:indexOfCh];
            NSInteger ind = NSMaxRange(pathRange);
            if (ind < strUrl.length) {
                indexOfCh = ind;
                ch = [strUrl characterAtIndex:indexOfCh];
            }
        }
        if (ch == '?') {
            queryRange = [strUrl findPart:[NSCharacterSet characterSetWithCharactersInString:@"#"] fromIndex:indexOfCh];
            NSInteger ind = NSMaxRange(queryRange);
            if (ind < strUrl.length) {
                indexOfCh = ind;
                ch = [strUrl characterAtIndex:indexOfCh];
            }
        }
        if (ch == '#') {
            fragmentRange = NSMakeRange(indexOfCh, strUrl.length - indexOfCh);
        }
    }

    // make normalized URL string
    NSMutableString *normUrl = [NSMutableString stringWithCapacity:strUrl.length];
    [normUrl appendString:scheme];
    [normUrl appendString:@"://"];
    // username, password
    if (usernameRange.length > 0 || passwordRange.length > 0) {
        [normUrl appendString:[strUrl substringWithRange:usernameRange].percentEncodeUserinfo];
        if (passwordRange.length > 0) {
            [normUrl appendString:@":"];
            [normUrl appendString:[strUrl substringWithRange:passwordRange].percentEncodeUserinfo];
        }
        [normUrl appendString:@"@"];
    }
    // hostname
    [normUrl appendString:[strUrl substringWithRange:hostnameRange]];
    // port
    if (port >= 0 && port != [self defaultPortOfScheme:scheme]) {
        [normUrl appendFormat:@":%d", (int)port];
    }
    // path
    if (pathRange.length > 0)
        [normUrl appendString:[strUrl substringWithRange:pathRange].percentEncodeUrlPath];
    else
        [normUrl appendString:@"/"];
    // query
    if (queryRange.length > 0)
        [normUrl appendString:[strUrl substringWithRange:queryRange].percentEncodeUrlQuery];
    // fragment
    if (fragmentRange.length > 0)
        [normUrl appendString:[strUrl substringWithRange:fragmentRange].normalizeUrlFragment];

    return normUrl;
}

- (nullable NSURL *)ParseURL {
    NSURL *url = [NSURL URLWithString:self.normalizeUrlString];
    // resolve ".." and "." in the path (standardizedURL)
    return url != nil ? url.standardizedURL : nil;
}

@end
