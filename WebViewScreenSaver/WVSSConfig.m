//
//  WVSSConfig.m
//  WebViewScreenSaver
//
//  Created by Alastair Tse on 26/04/2015.
//
//  Copyright 2015 Alastair Tse.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "WVSSConfig.h"
#import "WVSSAddress.h"

// ScreenSaverDefault Keys
static NSString *const kScreenSaverFetchURLsKey = @"kScreenSaverFetchURLs";  // BOOL
static NSString *const kScreenSaverURLsURLKey = @"kScreenSaverURLsURL";      // NSString (URL)
static NSString *const kScreenSaverURLListKey = @"kScreenSaverURLList";  // NSArray of NSDictionary

// New config keys
static NSString *const kScreenSaverTimeFormatKey = @"kScreenSaverTimeFormat";
static NSString *const kScreenSaverBirthDateKey = @"kScreenSaverBirthDate";
static NSString *const kScreenSaverScaleKey = @"kScreenSaverScale";
static NSString *const kScreenSaverBrightnessKey = @"kScreenSaverBrightness";
static NSString *const kScreenSaverShowBackgroundKey = @"kScreenSaverShowBackground";
static NSString *const kScreenSaverMultiMonitorKey = @"kScreenSaverMultiMonitor";

// Default values
static NSString *const kDefaultTimeFormat = @"00-23";
static CGFloat const kDefaultScale = 0.7;
static CGFloat const kDefaultBrightness = 0.3;
static BOOL const kDefaultShowBackground = YES;
static BOOL const kDefaultMultiMonitor = YES;

static NSDate *defaultBirthDate(void) {
  NSDateComponents *components = [[NSDateComponents alloc] init];
  components.year = 2000;
  components.month = 1;
  components.day = 1;
  components.hour = 0;
  components.minute = 0;
  components.second = 0;
  return [NSCalendar.currentCalendar dateFromComponents:components];
}

@interface WVSSConfig ()
@property(nonatomic, strong) NSUserDefaults *userDefaults;
@property(nonatomic, strong) NSMutableArray *addresses;
@end

@implementation WVSSConfig

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
  self = [super init];
  if (self) {
    self.userDefaults = userDefaults;

    self.addresses = [self loadAddressesFromUserDefaults:userDefaults];
    self.addressListURL = [userDefaults stringForKey:kScreenSaverURLsURLKey];
    self.shouldFetchAddressList = [userDefaults boolForKey:kScreenSaverFetchURLsKey];

    self.timeFormat = [userDefaults stringForKey:kScreenSaverTimeFormatKey] ?: kDefaultTimeFormat;
    self.birthDate = [userDefaults objectForKey:kScreenSaverBirthDateKey] ?: defaultBirthDate();
    self.scale = [userDefaults objectForKey:kScreenSaverScaleKey]
                     ? [userDefaults floatForKey:kScreenSaverScaleKey]
                     : kDefaultScale;
    self.brightness = [userDefaults objectForKey:kScreenSaverBrightnessKey]
                         ? [userDefaults floatForKey:kScreenSaverBrightnessKey]
                         : kDefaultBrightness;
    self.showBackground = [userDefaults objectForKey:kScreenSaverShowBackgroundKey]
                             ? [userDefaults boolForKey:kScreenSaverShowBackgroundKey]
                             : kDefaultShowBackground;
    self.multiMonitor = [userDefaults objectForKey:kScreenSaverMultiMonitorKey]
                           ? [userDefaults boolForKey:kScreenSaverMultiMonitorKey]
                           : kDefaultMultiMonitor;

    if (!self.addresses) {
      self.addresses = [NSMutableArray array];
    }
  }
  return self;
}

- (NSMutableArray *)loadAddressesFromUserDefaults:(NSUserDefaults *)userDefaults {
  NSArray *addressesFromUserDefaults =
      [[userDefaults arrayForKey:kScreenSaverURLListKey] mutableCopy];
  NSMutableArray *addresses = [NSMutableArray array];
  for (NSDictionary *addressDictionary in addressesFromUserDefaults) {
    NSString *url = addressDictionary[kWVSSAddressURLKey];
    NSInteger time = [addressDictionary[kWVSSAddressTimeKey] integerValue];
    if (url) {
      WVSSAddress *address = [WVSSAddress addressWithURL:url duration:time];
      [addresses addObject:address];
    }
  }
  return addresses;
}

- (void)saveAddressesToUserDefaults:(NSUserDefaults *)userDefaults {
  NSMutableArray *addressesForUserDefaults = [NSMutableArray array];
  for (WVSSAddress *address in self.addresses) {
    [addressesForUserDefaults addObject:[address dictionaryRepresentation]];
  }
  // NSLog(@"Saved Addresses: %@", addressesForUserDefaults);

  [userDefaults setObject:addressesForUserDefaults forKey:kScreenSaverURLListKey];
}

- (void)synchronize {
  [self saveAddressesToUserDefaults:self.userDefaults];
  [self.userDefaults setBool:self.shouldFetchAddressList forKey:kScreenSaverFetchURLsKey];

  if (self.addressListURL.length) {
    [self.userDefaults setObject:self.addressListURL forKey:kScreenSaverURLsURLKey];
  } else {
    [self.userDefaults removeObjectForKey:kScreenSaverURLsURLKey];
  }

  [self.userDefaults setObject:self.timeFormat forKey:kScreenSaverTimeFormatKey];
  [self.userDefaults setObject:self.birthDate forKey:kScreenSaverBirthDateKey];
  [self.userDefaults setFloat:self.scale forKey:kScreenSaverScaleKey];
  [self.userDefaults setFloat:self.brightness forKey:kScreenSaverBrightnessKey];
  [self.userDefaults setBool:self.showBackground forKey:kScreenSaverShowBackgroundKey];
  [self.userDefaults setBool:self.multiMonitor forKey:kScreenSaverMultiMonitorKey];

  [self.userDefaults synchronize];
}

- (void)addAddressWithURL:(NSString *)url duration:(NSInteger)duration {
  WVSSAddress *address = [WVSSAddress addressWithURL:url duration:duration];
  [self.addresses addObject:address];
}

@end
