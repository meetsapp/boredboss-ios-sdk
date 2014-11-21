//
//  BoredBoss.m
//  Pods
//
//  Created by Javier Berlana on 18/11/14.
//
//

#import "BoredBoss.h"

#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#import <CommonCrypto/CommonDigest.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIDevice.h>

#import "BBConstants.h"
#import "BBPersistence.h"
#import "BBSerialization.h"

@interface BoredBoss () {
    NSUInteger _flushInterval;
}

@property (atomic, copy) NSString *distinctId;
@property (atomic, copy) NSString *aliasId;
@property (atomic, copy) NSString *apiKey;
@property (atomic, copy) NSString *serverURL;

@property (atomic, strong) NSDictionary *superProperties;
@property (atomic, strong) NSDictionary *automaticProperties;

@property (nonatomic, strong) NSMutableDictionary *timedEvents;
@property (nonatomic, strong) NSMutableArray *eventsQueue;
@property (nonatomic, strong) NSMutableArray *userPropertiesQueue;

@property (nonatomic, assign) UIBackgroundTaskIdentifier taskId;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, assign) SCNetworkReachabilityRef reachability;

@end


@implementation BoredBoss

static void BoredBossReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    if (info != NULL && [(__bridge NSObject*)info isKindOfClass:[BoredBoss class]]) {
        @autoreleasepool {
            BoredBoss *boredboss = (__bridge BoredBoss *)info;
            [boredboss reachabilityChanged:flags];
        }
    } else {
        NSLog(@"BoredBoss reachability callback received unexpected info object");
    }
}

static BoredBoss *sharedInstance = nil;

+ (BoredBoss *)sharedInstanceWithClient:(NSString *)client andApiKey:(NSString *)apiKey;
{
    return [BoredBoss sharedInstanceWithClient:client andApiKey:apiKey launchOptions:nil];
}

+ (BoredBoss *)sharedInstanceWithClient:(NSString *)client andApiKey:(NSString *)apiApiKey launchOptions:(NSDictionary *)launchOptions;
{
    static dispatch_once_t onceApiKey;
    dispatch_once(&onceApiKey, ^{
        sharedInstance = [[super alloc] initWithClient:client andApiKey:apiApiKey launchOptions:launchOptions andFlushInterval:30];
    });
    return sharedInstance;
}

+ (BoredBoss *)sharedInstance
{
    if (sharedInstance == nil) {
        NSLog(@"%@ warning sharedInstance called before sharedInstanceWithApiKey:", self);
    }
    return sharedInstance;
}

- (instancetype)initWithClient:(NSString *)client andApiKey:(NSString *)apiApiKey launchOptions:(NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval
{
    if (apiApiKey == nil) {
        apiApiKey = @"";
    }
    if ([apiApiKey length] == 0) {
        NSLog(@"%@ warning empty ApiKey", self);
    }
    if (self = [self init])
    {
        self.apiKey               = apiApiKey;
        _flushInterval            = flushInterval;
        self.serverURL            = [NSString stringWithFormat:@"http://%@.boredboss.com",client];
        
        self.taskId               = UIBackgroundTaskInvalid;
        NSString *label           = [NSString stringWithFormat:@"com.BoredBoss.%@.%p", apiApiKey, self];
        self.serialQueue          = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        
        self.distinctId           = [self defaultDistinctId];
        self.superProperties      = [NSMutableDictionary dictionary];
        self.automaticProperties  = [self collectAutomaticProperties];
        self.eventsQueue          = [NSMutableArray array];
        self.userPropertiesQueue  = [NSMutableArray array];
        self.timedEvents          = [NSMutableDictionary dictionary];
        
        [self setupListeners];
        [self unarchive];
        
        if (!self.aliasId) {
            [self generateAliasId];
        }
        
        if (launchOptions && launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
            //[self trackPushNotification:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] event:@"$app_open"];
        }
    }
    
    return self;
}

- (void)generateAliasId
{
    dispatch_async(self.serialQueue, ^{
        NSString *postBody          = [NSString stringWithFormat:@"apikey=%@", self.apiKey];
        NSURLRequest *request       = [self apiRequestWithEndpoint:@"/api/user/" andBody:postBody];
        NSError *error              = nil;
        NSURLResponse *urlResponse  = nil;
        
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
        if (error) {
            BoredBossDebug(@"%@ network failure: %@", self, error);
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        if (error) {
            BoredBossDebug(@"%@ deserialization failure: %@", self, error);
        }
        else {
            NSString *status = [json objectForKey:@"status"];
            if ([status isEqualToString:@"OK"]) {
                self.aliasId = [[json objectForKey:@"user"] objectForKey:@"alias"];
                [self archiveProperties];
                BoredBossDebug(@"%@ received new alias %@", self, self.aliasId);
            }
            else {
                BoredBossDebug(@"%@ %@", self, [[json objectForKey:@"error"] objectForKey:@"message"]);
            }
        }
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_reachability != NULL)
    {
        if (!SCNetworkReachabilitySetCallback(_reachability, NULL, NULL)) {
            NSLog(@"%@ error unsetting reachability callback", self);
        }
        if (!SCNetworkReachabilitySetDispatchQueue(_reachability, NULL)) {
            NSLog(@"%@ error unsetting reachability dispatch queue", self);
        }
        CFRelease(_reachability);
        _reachability = NULL;
        BoredBossDebug(@"realeased reachability");
    }
}

- (void)setupListeners
{
    // wifi reachability
    BOOL reachabilityOk = NO;
    if ((_reachability = SCNetworkReachabilityCreateWithName(NULL, "api.boredboss.com")) != NULL) {
        SCNetworkReachabilityContext context = {0, (__bridge void*)self, NULL, NULL, NULL};
        if (SCNetworkReachabilitySetCallback(_reachability, BoredBossReachabilityCallback, &context)) {
            if (SCNetworkReachabilitySetDispatchQueue(_reachability, self.serialQueue)) {
                reachabilityOk = YES;
                BoredBossDebug(@"%@ successfully set up reachability callback", self);
            } else {
                // cleanup callback if setting dispatch queue failed
                SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
            }
        }
    }
    if (!reachabilityOk) {
        NSLog(@"%@ failed to set up reachability callback: %s", self, SCErrorString(SCError()));
    }
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // Application lifecycle events
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminate:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
}

- (NSString *)deviceModel
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char answer[size];
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    NSString *results = @(answer);
    return results;
}

- (NSString *)IFA
{
    NSString *ifa = nil;
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass)
    {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        ifa = [uuid UUIDString];
    }
    return ifa;
}

+ (BOOL)inBackground
{
    return [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
}

#pragma mark - Tracking


+ (void)assertPropertyTypes:(NSDictionary *)properties
{
    for (id __unused k in properties) {
        NSAssert([k isKindOfClass: [NSString class]], @"%@ property keys must be NSString. got: %@ %@", self, [k class], k);
        NSAssert([properties[k] isKindOfClass:[NSString class]] ||
                 [properties[k] isKindOfClass:[NSNumber class]] ||
                 [properties[k] isKindOfClass:[NSNull class]] ||
                 [properties[k] isKindOfClass:[NSArray class]] ||
                 [properties[k] isKindOfClass:[NSDictionary class]] ||
                 [properties[k] isKindOfClass:[NSDate class]] ||
                 [properties[k] isKindOfClass:[NSURL class]],
                 @"%@ property values must be NSString, NSNumber, NSNull, NSArray, NSDictionary, NSDate or NSURL. got: %@ %@", self, [properties[k] class], properties[k]);
    }
}

- (NSDictionary *)collectAutomaticProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    NSString *deviceModel = [self deviceModel];
    CGSize size = [UIScreen mainScreen].bounds.size;
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    
    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"] forKey:k_NAME_APP_VERSION];
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:k_NAME_APP_RELEASE];
    [p setValue:[self IFA] forKey:k_NAME_IOS_IFA];
    [p setValue:carrier.carrierName forKey:k_NAME_CARRIER];
    
    [p addEntriesFromDictionary:@{k_NAME_LIB           : @"ObjectiveC",
                                  k_NAME_LIB_VERSION   : VERSION,
                                  k_NAME_MANUFACTURER  : @"Apple",
                                  k_NAME_OS            : [device systemName],
                                  k_NAME_OS_VERSION    : [device systemVersion],
                                  k_NAME_MODEL         : deviceModel,
                                  k_NAME_SCREEN_HEIGHT : @((NSInteger)size.height),
                                  k_NAME_SCREEN_WIDTH  : @((NSInteger)size.width)
                                  }];
    return [p copy];
}

- (NSString *)defaultDistinctId
{
    NSString *distinctId = [self IFA];
    
    if (!distinctId && NSClassFromString(@"UIDevice")) {
        distinctId = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
    if (!distinctId) {
        NSLog(@"%@ error getting device identifier: falling back to uuid", self);
        distinctId = [[NSUUID UUID] UUIDString];
    }
    
    [self setUserProperty:k_NAME_DISTINCT_ID value:distinctId];
    return distinctId;
}

- (void)identify:(NSString *)distinctId
{
    if (distinctId == nil || distinctId.length == 0) {
        NSLog(@"%@ error blank distinct id: %@", self, distinctId);
        return;
    }
    self.distinctId = distinctId;
    [self setUserProperty:k_NAME_DISTINCT_ID value:self.distinctId];
}

- (void)track:(NSString *)event
{
    [self track:event properties:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    if (event == nil || [event length] == 0) {
        NSLog(@"%@ boredboss track called with empty event parameter.", self);
        return;
    }
    properties = [properties copy];
    [BoredBoss assertPropertyTypes:properties];
    
    double epochInterval = [[NSDate date] timeIntervalSince1970];
    NSNumber *epochSeconds = @(round(epochInterval));
    dispatch_async(self.serialQueue, ^{
        NSNumber *eventStartTime = self.timedEvents[event];
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        if (eventStartTime) {
            [self.timedEvents removeObjectForKey:event];
            p[k_NAME_DURATION] = [NSString stringWithFormat:@"%.3f", epochInterval - [eventStartTime doubleValue]];
        }
        if (self.distinctId) {
            p[k_NAME_DISTINCT_ID] = self.distinctId;
        }
        [p addEntriesFromDictionary:self.superProperties];
        if (properties) {
            [p addEntriesFromDictionary:properties];
        }
        NSDictionary *e = @{k_NAME_EVENT: event, k_NAME_DATE:epochSeconds, k_NAME_PROPERTIES: [NSDictionary dictionaryWithDictionary:p]};
        BoredBossDebug(@"%@ queueing event: %@", self, e);
        [self.eventsQueue addObject:e];
        if ([self.eventsQueue count] > 500) {
            [self.eventsQueue removeObjectAtIndex:0];
        }
        if ([BoredBoss inBackground]) {
            [self archiveEvents];
        }
    });
}

- (void)setUserProperty:(NSString *)property value:(id)value;
{
    [self setUserProperty:property value:value withAction:nil];
}

- (void)increment:(NSString *)property by:(NSNumber *)amount
{
    [self setUserProperty:property value:amount withAction:@"increase"];
}

- (void)setUserProperty:(NSString *)property value:(id)value withAction:(NSString *)action
{
    if (!property || !value || [property length] == 0) {
        NSLog(@"%@ boredboss track called with empty property parameter.", self);
        return;
    }
    
    if (!([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]])) {
        NSLog(@"%@ boredboss track called with invalid value parameter.", self);
        return;
    }
    
    dispatch_async(self.serialQueue, ^{
        NSDictionary *e;
        if (action) {
            e = @{k_NAME_EVENT: property, k_NAME_INFO: @{k_NAME_VALUE: value, @"action": action}};
        }
        else {
            e = @{k_NAME_EVENT: property, k_NAME_INFO: @{k_NAME_VALUE: value}};
        }
        
        BoredBossDebug(@"%@ queueing user properties: %@", self, e);
        [self.userPropertiesQueue addObject:e];
        if ([self.userPropertiesQueue count] > 500) {
            [self.userPropertiesQueue removeObjectAtIndex:0];
        }
        
        if ([BoredBoss inBackground]) {
            [self archiveUserProperties];
        }
    });
}

- (void)registerSuperProperties:(NSDictionary *)properties
{
    properties = [properties copy];
    [BoredBoss assertPropertyTypes:properties];
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self.superProperties];
        [tmp addEntriesFromDictionary:properties];
        self.superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        if ([BoredBoss inBackground]) {
            [self archiveProperties];
        }
    });
}

- (void)clearSuperProperties
{
    dispatch_async(self.serialQueue, ^{
        self.superProperties = @{};
        if ([BoredBoss inBackground]) {
            [self archiveProperties];
        }
    });
}

- (NSDictionary *)currentSuperProperties
{
    return [self.superProperties copy];
}

- (void)timeEvent:(NSString *)event
{
    if (event == nil || [event length] == 0) {
        NSLog(@"BoredBoss cannot time an empty event");
        return;
    }
    dispatch_async(self.serialQueue, ^{
        self.timedEvents[event] = @([[NSDate date] timeIntervalSince1970]);
    });
}

- (void)clearTimedEvents
{
    dispatch_async(self.serialQueue, ^{
        self.timedEvents = [NSMutableDictionary dictionary];
    });
}

- (void)reset
{
    dispatch_async(self.serialQueue, ^{
        self.distinctId = [self defaultDistinctId];
        self.superProperties = [NSMutableDictionary dictionary];
        self.eventsQueue = [NSMutableArray array];
        self.userPropertiesQueue = [NSMutableArray array];
        self.timedEvents = [NSMutableDictionary dictionary];
        [self archive];
    });
}

#pragma mark - Network control

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags
{
    BOOL wifi = (flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsIsWWAN);
    NSMutableDictionary *properties = [self.automaticProperties mutableCopy];
    properties[k_NAME_WIFI] = wifi ? @YES : @NO;
    self.automaticProperties = [properties copy];
    BoredBossDebug(@"%@ reachability changed, wifi=%d", self, wifi);
}

- (NSURLRequest *)apiRequestWithEndpoint:(NSString *)endpoint andBody:(NSString *)body
{
    NSURL *URL = [NSURL URLWithString:[self.serverURL stringByAppendingString:endpoint]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    BoredBossDebug(@"%@ http request: %@?%@", self, URL, body);
    return request;
}

- (NSUInteger)flushInterval
{
    @synchronized(self) {
        return _flushInterval;
    }
}

- (void)setFlushInterval:(NSUInteger)interval
{
    @synchronized(self) {
        _flushInterval = interval;
    }
    [self startFlushTimer];
}

- (void)startFlushTimer
{
    [self stopFlushTimer];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.flushInterval > 0) {
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.flushInterval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            BoredBossDebug(@"%@ started flush timer: %@", self, self.timer);
        }
    });
}

- (void)stopFlushTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
            BoredBossDebug(@"%@ stopped flush timer: %@", self, self.timer);
        }
        self.timer = nil;
    });
}

- (void)flush
{
    dispatch_async(self.serialQueue, ^{
        BoredBossDebug(@"%@ flush starting", self);
        [self flushEvents];
        [self flushProperties];
        BoredBossDebug(@"%@ flush complete", self);
    });
}

- (void)flushEvents
{
    [self flushQueue:_eventsQueue endpoint:@"/api/user/event/" params:@"apikey=%@&alias=%@&events=%@"];
}

- (void)flushProperties
{
    [self flushQueue:_userPropertiesQueue endpoint:@"/api/user/properties/" params:@"apikey=%@&alias=%@&properties=%@"];
}

- (void)flushQueue:(NSMutableArray *)queue endpoint:(NSString *)endpoint params:(NSString *)params
{
    while ([queue count] > 0) {
        NSUInteger batchSize = ([queue count] > 50) ? 50 : [queue count];
        NSArray *batch = [queue subarrayWithRange:NSMakeRange(0, batchSize)];
        
        NSString *requestData = [BBSerialization encodeAPIData:batch];
        NSString *postBody = [NSString stringWithFormat:params, _apiKey, _aliasId, requestData];
        
        BoredBossDebug(@"%@ flushing %lu of %lu to %@: %@", self, (unsigned long)[batch count], (unsigned long)[queue count], endpoint, queue);
        NSURLRequest *request = [self apiRequestWithEndpoint:endpoint andBody:postBody];
        NSError *error = nil;
        
        NSURLResponse *urlResponse = nil;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
        
        if (error) {
            BoredBossDebug(@"%@ network failure: %@", self, error);
            break;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        
        if ([[json objectForKey:@"status"] isEqualToString:@"OK"]) {
            BoredBossDebug(@"%@ %@ api saved %ld items", self, endpoint, (unsigned long)batchSize);
        } else {
            BoredBossDebug(@"%@ %@ api rejected some items", self, endpoint);
        }
        
        [queue removeObjectsInArray:batch];
    }
}

#pragma mark - UIApplication notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    BoredBossDebug(@"%@ application did become active", self);
    [self startFlushTimer];
    [self track:@"#OpenApp" properties:self.automaticProperties];
    [self timeEvent:@"#CloseApp"];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    BoredBossDebug(@"%@ application will resign active", self);
    [self track:@"#CloseApp"];
    [self stopFlushTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    BoredBossDebug(@"%@ did enter background", self);
    
    self.taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        BoredBossDebug(@"%@ flush %lu cut short", self, (unsigned long)self.taskId);
        [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
        self.taskId = UIBackgroundTaskInvalid;
    }];
    BoredBossDebug(@"%@ starting background cleanup task %lu", self, (unsigned long)self.taskId);
    
    dispatch_async(_serialQueue, ^{
        [self archive];
        BoredBossDebug(@"%@ ending background cleanup task %lu", self, (unsigned long)self.taskId);
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    });
}

- (void)applicationWillEnterForeground:(NSNotificationCenter *)notification
{
    BoredBossDebug(@"%@ will enter foreground", self);
    
    dispatch_async(self.serialQueue, ^{
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    });
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    BoredBossDebug(@"%@ application will terminate", self);
    dispatch_async(_serialQueue, ^{
        [self archive];
    });
}

#pragma mark - Persistence

- (void)archive
{
    [self archiveEvents];
    [self archiveUserProperties];
    [self archiveProperties];
}

- (void)archiveEvents
{
    BBPersistence *persistance = [BBPersistence persistanceWithApiKey:self.apiKey];
    [persistance archive:self.eventsQueue withName:k_NAME_ARCHIVE_EVENTS];
}

- (void)archiveUserProperties
{
    BBPersistence *persistance = [BBPersistence persistanceWithApiKey:self.apiKey];
    [persistance archive:self.userPropertiesQueue withName:k_NAME_ARCHIVE_USERPROP];
}

- (void)archiveProperties
{
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    [p setValue:self.distinctId forKey:k_NAME_DISTINCT_ID];
    [p setValue:self.superProperties forKey:k_NAME_SUPER_PROPERTIES];
    [p setValue:self.timedEvents forKey:k_NAME_TIMED_EVENTS];
    
    [[NSUserDefaults standardUserDefaults] setObject:self.aliasId forKey:k_NAME_ALIAS_ID];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    BBPersistence *persistance = [BBPersistence persistanceWithApiKey:self.apiKey];
    [persistance archive:p withName:k_NAME_ARCHIVE_PROPERTIES];
}

- (void)unarchive
{
    [self unarchiveEvents];
    [self unarchiveUserProperties];
    [self unarchiveProperties];
}

- (void)unarchiveEvents
{
    BBPersistence *persistance = [BBPersistence persistanceWithApiKey:self.apiKey];
    self.eventsQueue = (NSMutableArray *)[persistance unarchiveDataWithName:k_NAME_ARCHIVE_EVENTS];
    if (!self.eventsQueue) {
        self.eventsQueue = [NSMutableArray array];
    }
}

- (void)unarchiveUserProperties
{
    BBPersistence *persistance = [BBPersistence persistanceWithApiKey:self.apiKey];
    self.userPropertiesQueue = (NSMutableArray *)[persistance unarchiveDataWithName:k_NAME_ARCHIVE_USERPROP];
    if (!self.userPropertiesQueue) {
        self.userPropertiesQueue = [NSMutableArray array];
    }
}

- (void)unarchiveProperties
{
    self.aliasId = [[NSUserDefaults standardUserDefaults] objectForKey:k_NAME_ALIAS_ID];
    
    BBPersistence *persistance = [BBPersistence persistanceWithApiKey:self.apiKey];
    NSDictionary *properties = (NSDictionary *)[persistance unarchiveDataWithName:k_NAME_ARCHIVE_PROPERTIES];
    if (properties) {
        self.distinctId      = properties[k_NAME_DISTINCT_ID] ? properties[k_NAME_DISTINCT_ID] : [self defaultDistinctId];
        self.superProperties = properties[k_NAME_SUPER_PROPERTIES] ? properties[k_NAME_SUPER_PROPERTIES] : [NSMutableDictionary dictionary];
        self.timedEvents     = properties[k_NAME_TIMED_EVENTS] ? properties[k_NAME_TIMED_EVENTS] : [NSMutableDictionary dictionary];
    }
}


@end
