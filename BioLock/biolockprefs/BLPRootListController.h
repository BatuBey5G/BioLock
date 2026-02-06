#import <Preferences/PSListController.h>

@interface BLPRootListController : PSListController

- (void)clearAuthCache:(id)sender;
- (void)resetSettings:(id)sender;
- (void)openGitHub:(id)sender;
- (void)showCompletionAlert:(NSString *)message;

@end
