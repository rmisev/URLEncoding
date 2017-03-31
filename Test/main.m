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
        NSString *str = (@"Percent-%- \"#<>?`{}").percentEncodeUrlPath;
        NSLog(@"Path: %@", str);
        
        NSURL *url = (@"HTTP://example.com/Percent-%- \"<>`{}").ParseURL;
        NSLog(@"URL: %@", url);

        NSLog(@"NSURL: %@", [NSURL URLWithString:@"http://example.com:80/"]);
    }
    return 0;
}
