//
//  BBPersistence.m
//  Pods
//
//  Created by Javier Berlana on 19/11/14.
//
//

#import "BBPersistence.h"

#import "BBConstants.h"

@interface BBPersistence ()

@property (nonatomic,strong) NSString *apiKey;

@end

@implementation BBPersistence

+ (BBPersistence *)persistanceWithApiKey:(NSString *)apiKey
{
    return [[super alloc] initWithApiKey:apiKey];
}

- (instancetype)initWithApiKey:(NSString *)apiKey
{
    if (self = [super init]) {
        self.apiKey = apiKey;
    }
    return self;
}

#pragma mark - Archive

- (NSString *)filePathForData:(NSString *)data
{
    NSString *filename = [NSString stringWithFormat:@"BoredBoss-%@-%@.plist", self.apiKey, data];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}

- (void)archive:(id)object withName:(NSString *)name
{
    NSString *filePath = [self filePathForData:name];
    BoredBossDebug(@"%@ archiving events data to %@: %@", self, filePath, object);
    if (![NSKeyedArchiver archiveRootObject:object toFile:filePath]) {
        NSLog(@"%@ unable to archive events data", self);
    }
}

#pragma mark - Unarchive

- (id)unarchiveDataWithName:(NSString *)name
{
    NSString *filePath = [self filePathForData:name];
    
    id unarchivedData = nil;
    @try {
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        BoredBossDebug(@"%@ unarchived data from %@: %@", self, filePath, unarchivedData);
    }
    @catch (NSException *exception) {
        NSLog(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        unarchivedData = nil;
    }
                          
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        if (!removed) {
            NSLog(@"%@ unable to remove archived file at %@ - %@", self, filePath, error);
        }
    }
    return unarchivedData;
}

@end
