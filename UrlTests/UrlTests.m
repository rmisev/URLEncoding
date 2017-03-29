//
//  UrlTests.m
//  UrlTests
//
//  Created by Rimas on 2017-03-29.
//
//

#import <XCTest/XCTest.h>
#import "NSString+URLEncoding.h"

@interface UrlTests : XCTestCase

@end


@implementation UrlTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [NSString initialize];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPercentEncodePath {
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XCTAssertEqualObjects((@"-%- \"#<>?`{}").percentEncodeUrlPath, @"-%-%20%22%23%3C%3E%3F%60%7B%7D");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
