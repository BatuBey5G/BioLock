


#import <UIKit/UIKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <AudioToolbox/AudioServices.h>

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (void)activateApplication:(id)app fromIcon:(id)icon location:(long long)location activationSettings:(id)settings actions:(id)actions;
@end


static NSString * const kPrefsID = @"com.batues.biolock";
static BOOL gEnabled = YES;
static BOOL gAllowPasscode = YES;
static BOOL gVibrateOnFail = YES;
static NSInteger gAuthCacheDuration = 0;
static NSString *gCustomPrompt = nil;
static NSSet<NSString *> *gProtectedApps = nil;

static NSMutableDictionary<NSString *, NSDate *> *gAuthCache = nil;
static NSMutableSet<NSString *> *gInTransition = nil;
static dispatch_queue_t gAuthQueue = nil;

#pragma mark - Logic

static void LoadPrefs() {
	@autoreleasepool {
		
		NSString *prefsPath = @"/var/mobile/Library/Preferences/com.batues.biolock.plist";
		NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath];

		
		if (!prefs) {
			CFStringRef appID = (__bridge CFStringRef)kPrefsID;
			CFPreferencesAppSynchronize(appID);
			CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
			if (keyList) {
				prefs = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
				CFRelease(keyList);
			}
		}

		gEnabled = prefs[@"Enabled"] ? [prefs[@"Enabled"] boolValue] : YES;
		gAllowPasscode = prefs[@"AllowPasscode"] ? [prefs[@"AllowPasscode"] boolValue] : YES;
		gVibrateOnFail = prefs[@"VibrateOnFail"] ? [prefs[@"VibrateOnFail"] boolValue] : YES;
		gAuthCacheDuration = [prefs[@"AuthCacheDuration"] integerValue];
		gCustomPrompt = [prefs[@"CustomPrompt"] copy];

		
		id protected = prefs[@"ProtectedApps"];
		if ([protected isKindOfClass:[NSArray class]]) {
			gProtectedApps = [NSSet setWithArray:protected];
		} else if ([protected isKindOfClass:[NSDictionary class]]) {
			
			gProtectedApps = [NSSet setWithArray:[protected allKeys]];
		}

		NSLog(@"[BioLock] Loaded %lu protected apps. Enabled: %d", (unsigned long)gProtectedApps.count, gEnabled);
	}
}

static void HandlePrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	LoadPrefs();
}

static void HandleClearCache(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	if (gAuthQueue) {
		dispatch_async(gAuthQueue, ^{
			[gAuthCache removeAllObjects];
		});
	}
}

static BOOL IsAuthCached(NSString *bundleID) {
	if (!bundleID) return NO;
	__block BOOL valid = NO;
	dispatch_sync(gAuthQueue, ^{
		NSDate *authDate = gAuthCache[bundleID];
		if (authDate && [[NSDate date] timeIntervalSinceDate:authDate] < gAuthCacheDuration) {
			valid = YES;
		}
	});
	return valid;
}

#pragma mark - Hooks

%hook SBUIController

- (void)activateApplication:(id)app fromIcon:(id)icon location:(long long)location activationSettings:(id)settings actions:(id)actions {
	SBApplication *sbApp = (SBApplication *)app;
	NSString *bundleID = [sbApp bundleIdentifier];

	
	

	
	if (!gEnabled || !bundleID || ![gProtectedApps containsObject:bundleID]) {
		%orig;
		return;
	}

	
	__block BOOL isBypassing = NO;
	dispatch_sync(gAuthQueue, ^{
		if ([gInTransition containsObject:bundleID]) {
			isBypassing = YES;
		}
	});

	if (isBypassing) {
		%orig;
		return;
	}

	
	if (gAuthCacheDuration > 0 && IsAuthCached(bundleID)) {
		%orig;
		return;
	}

	
	NSString *appName = [sbApp respondsToSelector:@selector(displayName)] ? [sbApp displayName] : bundleID;
	NSString *reason = (gCustomPrompt && gCustomPrompt.length > 0) ?
	[gCustomPrompt stringByReplacingOccurrencesOfString:@"%app%" withString:appName] :
	[NSString stringWithFormat:@"Unlock %@", appName];

	LAContext *context = [[LAContext alloc] init];
	LAPolicy policy = gAllowPasscode ? LAPolicyDeviceOwnerAuthentication : LAPolicyDeviceOwnerAuthenticationWithBiometrics;

	[context evaluatePolicy:policy localizedReason:reason reply:^(BOOL success, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (success) {
				dispatch_sync(gAuthQueue, ^{
					[gInTransition addObject:bundleID];
					if (gAuthCacheDuration > 0) gAuthCache[bundleID] = [NSDate date];
				});

					
					[self activateApplication:app fromIcon:icon location:location activationSettings:settings actions:actions];

					
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), gAuthQueue, ^{
						[gInTransition removeObject:bundleID];
					});
			} else {
				if (gVibrateOnFail) AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
				NSLog(@"[BioLock] Auth failed for %@", bundleID);
			}
		});
	}];
}

%end

#pragma mark - Constructor

%ctor {
	gAuthQueue = dispatch_queue_create("com.batues.biolock.queue", DISPATCH_QUEUE_SERIAL);
	gAuthCache = [[NSMutableDictionary alloc] init];
	gInTransition = [[NSMutableSet alloc] init];

	LoadPrefs();

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, HandlePrefsChanged, CFSTR("com.batues.biolock/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, HandleClearCache, CFSTR("com.batues.biolock/ClearCache"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
