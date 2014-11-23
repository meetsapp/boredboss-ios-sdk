//
//  BBPersistence.h
//  Pods
//
//  Created by Javier Berlana on 19/11/14.
//
//

#import <Foundation/Foundation.h>

@interface BBPersistence : NSObject

+ (BBPersistence *)persistanceWithApiKey:(NSString *)apiKey;

- (void)archive:(id)object withName:(NSString *)name;
- (id)unarchiveDataWithName:(NSString *)name;

@end
