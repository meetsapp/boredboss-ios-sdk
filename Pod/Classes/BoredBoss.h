//
//  BoredBoss.h
//  Pods
//
//  Created by Javier Berlana on 18/11/14.
//
//

#import <Foundation/Foundation.h>

@interface BoredBoss : NSObject

/*!
 @property
 
 @abstract
 The distinct ID of the current user.
 
 @discussion
 A distinct ID is a string that uniquely identifies one of your users.
 Typically, this is the user ID from your database. By default, we'll use a
 hash of the MAC address of the device. To change the current distinct ID,
 use the <code>identify:</code> method.
 */
@property (atomic, readonly, copy) NSString *distinctId;

/*!
 @property
 
 @abstract
 Flush timer's interval.
 
 @discussion
 Setting a flush interval of 0 will turn off the flush timer.
 */
@property (atomic) NSUInteger flushInterval;

/*!
 @method
 
 @abstract
 Initializes and returns a singleton instance of the API.
 
 @discussion
 This method will set up a singleton instance of the <code>BoredBoss</code> class for
 you using the given project token. When you want to make calls to BoredBoss
 elsewhere in your code, you can use <code>sharedInstance</code>.
 
 <pre>
 [BoredBoss sharedInstance] track:@"Something Happened"]];
 </pre>
 
 If you are going to use this singleton approach,
 <code>sharedInstanceWithToken:</code> <b>must be the first call</b> to the
 <code>BoredBoss</code> class, since it performs important initializations to
 the API.
 
 @param client        your project client Id
 @param apiKey        your project token
 */
+ (BoredBoss *)sharedInstanceWithClient:(NSString *)client andApiKey:(NSString *)apiKey;

/*!
 @method
 
 @abstract
 Initializes a singleton instance of the API, uses it to track launchOptions information,
 and then returns it.
 
 @discussion
 This is the preferred method for creating a sharedInstance.. With the launchOptions 
 parameter, BoredBoss can track referral information created by push notifications.
 
 @param client          your project client Id
 @param apiKey          your project ApiKey
 @param launchOptions   your application delegate's launchOptions
 
 */
+ (BoredBoss *)sharedInstanceWithClient:(NSString *)client andApiKey:(NSString *)apiKey launchOptions:(NSDictionary *)launchOptions;


/*!
 @method
 
 @abstract
 Returns the previously instantiated singleton instance of the API.
 
 @discussion
 The API must be initialized with <code>sharedInstanceWithApiKey:launchOptions:</code> before
 calling this class method.
 */
+ (BoredBoss *)sharedInstance;

/*!
 @method
 
 @abstract
 Initializes an instance of the API with the given project token.
 
 @discussion
 Returns the a new API object. This allows you to create more than one instance
 of the API object, which is convenient if you'd like to send data to more than
 one BoredBoss project from a single app. If you only need to send data to one
 project, consider using <code>sharedInstanceWithToken:</code>.
 
 @param client        your project client Id
 @param apiToken        your project token
 @param launchOptions   optional app delegate launchOptions
 @param flushInterval   interval to run background flushing
 */
- (instancetype)initWithClient:(NSString *)client andApiKey:(NSString *)apiApiKey launchOptions:(NSDictionary *)launchOptions andFlushInterval:(NSUInteger)flushInterval;


/*!
 @property
 
 @abstract
 Sets the distinct ID of the current user.
 
 @discussion
 For tracking events, you do not need to call <code>identify:</code> if you
 want to use the default.
 
 If you'd like to use the default distinct ID for BoredBoss People as well
 (recommended), call <code>identify:</code> using the current distinct ID:
 <code>[BoredBoss identify:BoredBoss.distinctId]</code>.
 
 @param distinctId string that uniquely identifies the current user
 */
- (void)identify:(NSString *)distinctId;

/*!
 @method
 
 @abstract
 Tracks an event.
 
 @param event           event name
 */
- (void)track:(NSString *)event;

/*!
 @method
 
 @abstract
 Tracks an event with properties.
 
 @discussion
 Properties will allow you to segment your events in your BoredBoss reports.
 Property keys must be <code>NSString</code> objects and values must be
 <code>NSString</code>, <code>NSNumber</code>, <code>NSNull</code>,
 <code>NSArray</code>, <code>NSDictionary</code>, <code>NSDate</code> or
 <code>NSURL</code> objects. If the event is being timed, the timer will
 stop and be added as a property.
 
 @param event           event name
 @param properties      properties dictionary
 */
- (void)track:(NSString *)event properties:(NSDictionary *)properties;

/*!
 @method
 
 @abstract
 Set properties on the current user in BoredBoss People.
 
 @discussion
 The properties will be set on the current user. The keys must be NSString
 objects and the values should be NSString, NSNumber, NSArray, NSDate, or
 NSNull objects. We use an NSAssert to enforce this type requirement. In
 release mode, the assert is stripped out and we will silently convert
 incorrect types to strings using [NSString stringWithFormat:@"%@", value].
 
 @param property    property name
 @param value       property value
 
 */
- (void)setUserProperty:(NSString *)property value:(id)value;

/*!
 @method
 
 @abstract
 Convenience method for incrementing a single numeric property by the specified
 amount.
 
 @param property        property name
 @param amount          amount to increment by
 */
- (void)increment:(NSString *)property by:(NSNumber *)amount;

/*!
 @method
 
 @abstract
 Registers super properties, overwriting ones that have already been set.
 
 @discussion
 Super properties, once registered, are automatically sent as properties for
 all event tracking calls. They save you having to maintain and add a common
 set of properties to your events. Property keys must be <code>NSString</code>
 objects and values must be <code>NSString</code>, <code>NSNumber</code>,
 <code>NSNull</code>, <code>NSArray</code>, <code>NSDictionary</code>,
 <code>NSDate</code> or <code>NSURL</code> objects.
 
 @param properties      properties dictionary
 */
- (void)registerSuperProperties:(NSDictionary *)properties;

/*!
 @method
 
 @abstract
 Clears all currently set super properties.
 */
- (void)clearSuperProperties;

/*!
 @method
 
 @abstract
 Returns the currently set super properties.
 */
- (NSDictionary *)currentSuperProperties;

/*!
 @method
 
 @abstract
 Starts a timer that will be stopped and added as a property when a
 corresponding event is tracked.
 
 @discussion
 This method is intended to be used in advance of events that have
 a duration. For example, if a developer were to track an "Image Upload" event
 she might want to also know how long the upload took. Calling this method
 before the upload code would implicitly cause the <code>track</code>
 call to record its duration.
 
 <pre>
 // begin timing the image upload
 [BoredBoss timeEvent:@"Image Upload"];
 
 // upload the image
 [self uploadImageWithSuccessHandler:^{
 
 // track the event
 [BoredBoss track:@"Image Upload"];
 }];
 </pre>
 
 @param event   a string, identical to the name of the event that will be tracked
 
 */
- (void)timeEvent:(NSString *)event;

/*!
 @method
 
 @abstract
 Clears all current event timers.
 */
- (void)clearTimedEvents;

/*!
 @method
 
 @abstract
 Clears all stored properties and distinct IDs. Useful if your app's user logs out.
 */
- (void)reset;

/*!
 @method
 
 @abstract
 Uploads queued data to the BoredBoss server.
 
 @discussion
 By default, queued data is flushed to the BoredBoss servers every minute (the
 default for <code>flushInvterval</code>), and on background (since
 <code>flushOnBackground</code> is on by default). You only need to call this
 method manually if you want to force a flush at a particular moment.
 */
- (void)flush;


@end
