Boredboss
===============

[![Build Status](https://travis-ci.org/meetsapp/boredboss-ios-sdk.svg?branch=master)](https://travis-ci.org/meetsapp/boredboss-ios-sdk)
[![Pod Version](http://img.shields.io/cocoapods/v/Boredboss-ios-sdk.svg?style=flat)](http://cocoadocs.org/docsets/Boredboss-ios-sdk.svg/)
[![Pod Platform](http://img.shields.io/cocoapods/p/Boredboss-ios-sdk.svg?style=flat)](http://cocoadocs.org/docsets/Boredboss-ios-sdk.svg/)
[![Pod License](http://img.shields.io/cocoapods/l/Boredboss-ios-sdk.svg?style=flat)](http://opensource.org/licenses/mit)

**Boredboss**  is a mobile analytics SAAS developed to measure app metrics.

## Installation

BoredBoss is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

    pod "Boredboss-ios-sdk"

## Documentation

The project is documented using AppleDocs syntax. But this is a summary:

#### Initialise the library

 This method will set up a singleton instance of the `BoredBoss` class for you using the given project token. When you want to make calls to BoredBoss  elsewhere in your code, you can use `sharedInstance`.

``` objc
+ (BoredBoss *)sharedInstanceWithClient:(NSString *)client
 							  andApiKey:(NSString *)apiKey;
 
+ (BoredBoss *)sharedInstanceWithClient:(NSString *)client 
							  andApiKey:(NSString *)apiKey 
						  launchOptions:(NSDictionary *)launchOptions;
```

#### Track events

Tracks an event with optional properties. Properties will allow you to segment your events in your BoredBoss reports.

``` objc
- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;
```

#### Register super properties
Super properties, once registered, are automatically sent as properties for all event tracking calls.
 
```
- (void)registerSuperProperties:(NSDictionary *)properties;
```

#### Timed events
Starts a timer that will be stopped and added as a property when a corresponding event is tracked.

```
- (void)timeEvent:(NSString *)event;
```

#### Identify your users

 Sets the distinct ID of the current user. For tracking events, you do not need to call `identify:` if you want to use the default.
 
```
- (void)identify:(NSString *)distinctId;
```

#### Add properties to your users

 Set and increment your properties on the current user in BoredBoss.

```
- (void)setUserProperty:(NSString *)property value:(id)value;
- (void)increment:(NSString *)property by:(NSNumber *)amount;
```


## Author

Javier Berlana, jberlana@gmail.com

## License

BoredBoss is available under the MIT license. See the LICENSE file for more info.

