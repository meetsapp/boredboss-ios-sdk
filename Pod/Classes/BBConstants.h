//
//  Constants.h
//  Pods
//
//  Created by Javier Berlana on 19/11/14.
//
//

#ifndef Pods_Header_h
#define Pods_Header_h

#define VERSION @"0.1.0"
#define BOREDBOSS_DEBUG 1

#ifdef BOREDBOSS_DEBUG
#define BoredBossDebug(...) NSLog(__VA_ARGS__)
#else
#define BoredBossDebug(...)
#endif

#define k_NAME_APP_VERSION        @"#appVersion"
#define k_NAME_APP_RELEASE        @"#appRelease"
#define k_NAME_IOS_IFA            @"#iosIFA"
#define k_NAME_CARRIER            @"#carrier"
#define k_NAME_LIB                @"#lib"
#define k_NAME_LIB_VERSION        @"#libVersion"
#define k_NAME_MANUFACTURER       @"#manufacturer"
#define k_NAME_OS                 @"#os"
#define k_NAME_OS_VERSION         @"#osVersion"
#define k_NAME_MODEL              @"#model"
#define k_NAME_DEVICE_MODEL       @"#deviceModel"
#define k_NAME_SCREEN_HEIGHT      @"#screenHeight"
#define k_NAME_SCREEN_WIDTH       @"#screenWidth"
#define k_NAME_WIFI               @"#wifi"

#define k_NAME_DURATION           @"#duration"
#define k_NAME_DISTINCT_ID        @"#distinctID"

#define k_NAME_API_KEY            @"apikey"
#define k_NAME_ALIAS_ID           @"aliasID"
#define k_NAME_DATE               @"date"
#define k_NAME_EVENT              @"name"
#define k_NAME_PROPERTIES         @"properties"
#define k_NAME_INFO               @"info"
#define k_NAME_VALUE              @"value"
#define k_NAME_TIMED_EVENTS       @"timedEvents"
#define k_NAME_SUPER_PROPERTIES   @"superProperties"

#define k_NAME_ARCHIVE_EVENTS     @"events"
#define k_NAME_ARCHIVE_USERPROP   @"userProperties"
#define k_NAME_ARCHIVE_PROPERTIES @"properties"

#endif
