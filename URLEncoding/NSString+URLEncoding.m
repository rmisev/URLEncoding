//
//  NSString+URLEncoding.m
//
//  Pagalbinės URL funkcijos
//  (c) Rimas Misevičius
//

#import <Foundation/Foundation.h>
#import "NSString+URLEncoding.h"


static NSMutableCharacterSet *allowedInPath = nil;

@implementation NSString (URLEncoding)

+ (void)initialize
{
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

@end
