//
//  BoredBossTest.m
//  BoredBoss
//
//  Created by Javier Berlana on 20/11/14.
//  Copyright (c) 2014 Javier Berlana. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BoredBoss.h"

#define TEST_CLIENT  @"testclient"
#define TEST_API_KEY @"1234567890abcdefghi"

@interface BoredBoss (Test)
// get access to private members

@property (atomic, copy) NSString *distinctId;
@property (atomic, copy) NSString *aliasId;
@property (atomic, copy) NSString *apiKey;
@property (atomic, copy) NSString *serverURL;

@property (atomic, strong) NSDictionary *superProperties;
@property (atomic, strong) NSDictionary *automaticProperties;

@property (nonatomic, strong) NSMutableDictionary *timedEvents;
@property (nonatomic, strong) NSMutableArray *eventsQueue;
@property (nonatomic, strong) NSMutableArray *userPropertiesQueue;

@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSTimer *timer;

- (void)archive;
- (NSString *)defaultDistinctId;

@end

@interface BoredBossTest : XCTestCase

@property (nonatomic, strong) BoredBoss *boredboss;

@end

@implementation BoredBossTest

- (void)waitForSerialQueue
{
    NSLog(@"starting wait for serial queue...");
    dispatch_sync(self.boredboss.serialQueue, ^{ return; });
    NSLog(@"finished wait for serial queue");
}

- (NSDictionary *)allPropertyTypes
{
    NSNumber *number = @3;
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    NSDate *date = [dateFormatter dateFromString:@"2012-09-28 19:14:36 PDT"];
    NSDictionary *dictionary = @{@"k": @"v"};
    NSArray *array = @[@"1"];
    NSNull *null = [NSNull null];
    NSDictionary *nested = @{@"p1": @{@"p2": @[@{@"p3": @[@"bottom"]}]}};
    NSURL *url = [NSURL URLWithString:@"https://boredboss.com/"];
    return @{@"string": @"yello",
             @"number": number,
             @"date": date,
             @"dictionary": dictionary,
             @"array": array,
             @"null": null,
             @"nested": nested,
             @"url": url,
             @"float": @1.3};
}

- (void)setUp {
    NSLog(@"starting test setup...");
    [super setUp];
    self.boredboss = [[BoredBoss alloc] initWithClient:TEST_CLIENT andApiKey:TEST_API_KEY launchOptions:nil andFlushInterval:0];
    [self.boredboss reset];
    [self waitForSerialQueue];
    NSLog(@"finished test setup");
}

- (void)tearDown {
    [super tearDown];
    self.boredboss = nil;
}

- (void)testInitialization
{
    NSString *server = [NSString stringWithFormat:@"http://%@.boredboss.com",TEST_CLIENT];
    XCTAssertTrue([self.boredboss.serverURL isEqualToString:server], @"Server url do not match the client.");
    XCTAssertTrue([self.boredboss.apiKey isEqualToString:TEST_API_KEY], @"API Key do not match.");
    XCTAssertNotNil(self.boredboss.distinctId, @"Missing distinctId");
    XCTAssertNotNil(self.boredboss.timedEvents, @"Timed events not initilized.");
    XCTAssertNotNil(self.boredboss.eventsQueue, @"Events queue not initilized.");
    XCTAssertNotNil(self.boredboss.userPropertiesQueue, @"Super properties queue not initilized.");
}

-(void)testAutomaticProperties
{
    XCTAssertNotNil(self.boredboss.automaticProperties[@"#model"], @"missing #ios_device_model property");
    XCTAssertNotNil(self.boredboss.automaticProperties[@"#lib_version"], @"missing #ios_lib_version property");
    XCTAssertNotNil(self.boredboss.automaticProperties[@"#os_version"], @"missing #ios_version property");
    XCTAssertNotNil(self.boredboss.automaticProperties[@"#app_version"], @"missing #ios_app_version property");
    XCTAssertNotNil(self.boredboss.automaticProperties[@"#app_release"], @"missing #ios_app_release property");
}

- (void)testIdentify
{
    NSString *currentID = self.boredboss.distinctId;
    XCTAssertNotNil(currentID, @"missing default currentId");
    [self.boredboss identify:@"NEW_IDENTITY"];
    XCTAssertFalse([self.boredboss.distinctId isEqualToString:currentID], @"New distinctId not changed.");
    XCTAssertTrue([self.boredboss.distinctId isEqualToString:@"NEW_IDENTITY"], @"New distinct id not seted.");
}

- (void)testTrack
{
    [self.boredboss track:@"Testing track"];
    [self waitForSerialQueue];
    XCTAssertTrue(self.boredboss.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.boredboss.eventsQueue.lastObject;
    XCTAssertEqual(e[@"name"], @"Testing track", @"incorrect event name");
    XCTAssertNotNil(e[@"date"], @"date not set");
    NSDictionary *p = e[@"properties"];
    XCTAssertNotNil(p[@"#distinctId"], @"$app_version not set");;
}

- (void)testTrackProperties
{
    NSDictionary *p = @{@"string": @"yello",
                        @"number": @3,
                        @"date": [NSDate date],
                        @"#app_version": @"override"};
    
    [self.boredboss track:@"Something Happened" properties:p];
    [self waitForSerialQueue];
    
    XCTAssertTrue(self.boredboss.eventsQueue.count == 1, @"event not queued");
    NSDictionary *e = self.boredboss.eventsQueue.lastObject;
    XCTAssertEqual(e[@"name"], @"Something Happened", @"incorrect event name");
    p = e[@"properties"];
    XCTAssertEqualObjects(p[@"#app_version"], @"override", @"reserved property override failed");
}

- (void)testSuperProperties
{
    NSDictionary *p = @{@"p1": @"a",
                        @"p2": @3,
                        @"p2": [NSDate date]};
    
    [self.boredboss registerSuperProperties:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.boredboss currentSuperProperties], p, @"register super properties failed");
    
    p = @{@"p1": @"b"};
    [self.boredboss registerSuperProperties:p];
    [self waitForSerialQueue];
    XCTAssertEqualObjects([self.boredboss currentSuperProperties][@"p1"], @"b",@"register super properties failed to overwrite existing value");

    [self.boredboss clearSuperProperties];
    [self waitForSerialQueue];
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 0, @"clear super properties failed");
}

- (void)testAssertPropertyTypes
{
    NSDictionary *p = @{@"data": [NSData data]};
    XCTAssertThrows([self.boredboss track:@"e1" properties:p], @"property type should not be allowed");
    XCTAssertThrows([self.boredboss registerSuperProperties:p], @"property type should not be allowed");
    p = [self allPropertyTypes];
    XCTAssertNoThrow([self.boredboss track:@"e1" properties:p], @"property type should be allowed");
    XCTAssertNoThrow([self.boredboss registerSuperProperties:p], @"property type should be allowed");
}

- (void)testReset
{
    NSDictionary *p = @{@"p1": @"a"};
    [self.boredboss identify:@"d1"];
    [self.boredboss registerSuperProperties:p];
    [self.boredboss track:@"e1"];
    [self.boredboss archive];
    [self.boredboss reset];
    [self waitForSerialQueue];
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 0, @"super properties failed to reset");
    XCTAssertTrue(self.boredboss.eventsQueue.count == 0, @"events queue failed to reset");

    self.boredboss = [[BoredBoss alloc] initWithClient:TEST_CLIENT andApiKey:TEST_API_KEY launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.boredboss.distinctId, [self.boredboss defaultDistinctId], @"distinct id failed to reset after archive");
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 0, @"super properties failed to reset after archive");
    XCTAssertTrue(self.boredboss.eventsQueue.count == 0, @"events queue failed to reset after archive");
}

- (void)testArchive
{
    [self.boredboss reset];
    [self.boredboss archive];
    self.boredboss = [[BoredBoss alloc] initWithClient:TEST_CLIENT andApiKey:TEST_API_KEY launchOptions:nil andFlushInterval:0];
    
    NSString *eventsPath = [NSString stringWithFormat:@"BoredBoss-%@-events.plist", TEST_API_KEY];
    NSString *userPath = [NSString stringWithFormat:@"BoredBoss-%@-userProperties.plist", TEST_API_KEY];
    NSString *propertiesPath = [NSString stringWithFormat:@"BoredBoss-%@-properties.plist", TEST_API_KEY];
    
    XCTAssertEqualObjects(self.boredboss.distinctId, [self.boredboss defaultDistinctId], @"default distinct id archive failed");
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 0, @"default super properties archive failed");
    XCTAssertTrue(self.boredboss.eventsQueue.count == 0, @"default events queue archive failed");
    NSDictionary *p = @{@"p1": @"a"};
    [self.boredboss identify:@"d1"];
    [self.boredboss registerSuperProperties:p];
    [self.boredboss track:@"e1"];
    [self.boredboss setUserProperty:@"p1" value:@"a"];
    self.boredboss.timedEvents[@"e2"] = @5.0;
    [self waitForSerialQueue];
    [self.boredboss archive];
    
    self.boredboss = [[BoredBoss alloc] initWithClient:TEST_CLIENT andApiKey:TEST_API_KEY launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.boredboss.distinctId, @"d1", @"custom distinct archive failed");
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 1, @"custom super properties archive failed");
    XCTAssertEqualObjects(self.boredboss.eventsQueue.lastObject[@"name"], @"e1", @"event was not successfully archived/unarchived");
    XCTAssertTrue(self.boredboss.userPropertiesQueue.count > 1, @"pending people queue archive failed");
    XCTAssertEqualObjects(self.boredboss.timedEvents[@"e2"], @5.0, @"timedEvents archive failed");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    XCTAssertFalse([fileManager fileExistsAtPath:eventsPath], @"events archive file not removed");
    XCTAssertFalse([fileManager fileExistsAtPath:userPath], @"people archive file not removed");
    XCTAssertFalse([fileManager fileExistsAtPath:propertiesPath], @"properties archive file not removed");
    
    self.boredboss = [[BoredBoss alloc] initWithClient:TEST_CLIENT andApiKey:TEST_API_KEY launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.boredboss.distinctId, [self.boredboss defaultDistinctId], @"default distinct id from no file failed");
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 0, @"default super properties from no file failed");
    XCTAssertNotNil(self.boredboss.eventsQueue, @"default events queue from no file is nil");
    XCTAssertTrue(self.boredboss.eventsQueue.count == 0, @"default events queue from no file not empty");
    XCTAssertNotNil(self.boredboss.userPropertiesQueue, @"default people queue from no file is nil");
    XCTAssertTrue(self.boredboss.userPropertiesQueue.count == 0, @"default people queue from no file not empty");
    XCTAssertTrue(self.boredboss.timedEvents.count == 0, @"timedEvents is not empty");
    
    self.boredboss = [[BoredBoss alloc] initWithClient:TEST_CLIENT andApiKey:TEST_API_KEY launchOptions:nil andFlushInterval:0];
    XCTAssertEqualObjects(self.boredboss.distinctId, [self.boredboss defaultDistinctId], @"default distinct id from garbage failed");
    XCTAssertTrue([[self.boredboss currentSuperProperties] count] == 0, @"default super properties from garbage failed");
    XCTAssertNotNil(self.boredboss.eventsQueue, @"default events queue from garbage is nil");
    XCTAssertTrue(self.boredboss.eventsQueue.count == 0, @"default events queue from garbage not empty");
    XCTAssertNotNil(self.boredboss.userPropertiesQueue, @"default people queue from garbage is nil");
    XCTAssertTrue(self.boredboss.userPropertiesQueue.count == 0, @"default people queue from garbage not empty");
    XCTAssertTrue(self.boredboss.timedEvents.count == 0, @"timedEvents is not empty");
}


@end
