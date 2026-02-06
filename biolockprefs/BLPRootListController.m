#import "BLPRootListController.h"
#import <Preferences/PSSpecifier.h>

@implementation BLPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"BioLock";

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
}

- (void)clearAuthCache:(id)sender {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Clear Cache"
                                        message:@"This will require re-authentication for all protected apps and reset the timer. Continue?"
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Clear"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.batues.biolock/ClearCache"),
            NULL,
            NULL,
            YES
        );

        [self showCompletionAlert:@"Authentication cache cleared successfully."];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetSettings:(id)sender {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Reset Settings"
                                        message:@"This will reset all BioLock settings to defaults. This action cannot be undone."
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {

        NSString *prefsPath = @"/var/mobile/Library/Preferences/com.batues.biolock.plist";
        [[NSFileManager defaultManager] removeItemAtPath:prefsPath error:nil];

        CFStringRef appID = CFSTR("com.batues.biolock");
        CFPreferencesAppSynchronize(appID);

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.batues.biolock/ReloadPrefs"),
            NULL,
            NULL,
            YES
        );

        [self reloadSpecifiers];
        [self showCompletionAlert:@"All settings have been reset to defaults."];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openGitHub:(id)sender {
    NSString *urlString = @"https://github.com/BatuBey5G/BioLock";
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)showCompletionAlert:(NSString *)message {
    UIAlertController *alert =
    [UIAlertController alertControllerWithTitle:@"Success"
                                        message:message
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
