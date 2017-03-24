//
//  main.m
//  Test
//
//  Created by Rimas on 2017-03-24.
//
//

#import <Foundation/Foundation.h>
#import "NSString+URLEncoding.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString* str = [@"Percent-%-KITI- \"#<>?`{}"
                         stringByAddingPercentEncodingForUrlPath];

        NSLog(@"Result: %@", str);
    }
    return 0;
}
