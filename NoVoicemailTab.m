#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <stdbool.h>

static void (*originalSetControllers)(UITabBarController *, SEL, NSArray *);
static void (*originalSetControllersAnimated)(UITabBarController *, SEL, NSArray *, BOOL);
static void (*originalSetTabs)(UITabBarController *, SEL, NSArray *);
static void (*originalSetTabsAnimated)(UITabBarController *, SEL, NSArray *, BOOL);
static void (*originalShowLegacyTabs)(id, SEL, bool, bool, bool, bool, bool);

static bool isVoicemailController(UIViewController *controller) {
    for (Class cls = object_getClass(controller); cls; cls = class_getSuperclass(cls)) {
        const char *name = class_getName(cls);
        if (!strcmp(name, "PHVoicemailNavigationController") ||
            !strcmp(name, "VoicemailTabViewController") ||
            !strcmp(name, "MPVoicemailTableViewController") ||
            !strcmp(name, "_TtC11MobilePhone34DummyVoicemailNavigationController")) {
            return true;
        }
    }
    return false;
}

static NSArray *controllersWithoutVoicemail(NSArray<UIViewController *> *controllers) {
    // Require another tab and remove only a positively identified voicemail controller.
    if (controllers.count < 2) return controllers;
    for (UIViewController *controller in controllers) {
        UIViewController *root = [controller isKindOfClass:UINavigationController.class]
            ? ((UINavigationController *)controller).viewControllers.firstObject : nil;
        if (isVoicemailController(controller) || isVoicemailController(root)) {
            NSMutableArray *remaining = [controllers mutableCopy];
            [remaining removeObjectIdenticalTo:controller];
            return remaining;
        }
    }
    return controllers;
}

static void setControllers(UITabBarController *controller, SEL selector, NSArray *controllers) {
    originalSetControllers(controller, selector, controllersWithoutVoicemail(controllers));
}

static void setControllersAnimated(UITabBarController *controller, SEL selector,
                                   NSArray *controllers, BOOL animated) {
    originalSetControllersAnimated(controller, selector, controllersWithoutVoicemail(controllers),
                                   animated);
}

static NSArray *tabsWithoutVoicemail(UITabBarController *controller, NSArray *tabs) API_AVAILABLE(ios(18.0));
static NSArray *tabsWithoutVoicemail(UITabBarController *controller, NSArray *tabs) {
    if (tabs.count < 2 || ![controller isKindOfClass:objc_lookUpClass("PhoneTabBarController")]) {
        return tabs;
    }

    // UITab providers may create view controllers on first access. Identify
    // the tab from metadata without invoking a provider during installation.
    NSBundle *phone = NSBundle.mainBundle;
    NSString *localizedTitle = [phone localizedStringForKey:@"VOICEMAIL" value:@"Voicemail" table:nil];
    for (UITab *tab in tabs) {
        NSString *identifier = tab.identifier.lowercaseString;
        NSString *title = tab.title;
        if ([identifier isEqualToString:@"voicemail"] ||
            [identifier isEqualToString:@"voicemailtab"] ||
            [identifier hasSuffix:@".voicemail"] ||
            [title isEqualToString:localizedTitle] ||
            [title isEqualToString:@"Voicemail"]) {
            NSMutableArray *remaining = [tabs mutableCopy];
            [remaining removeObjectIdenticalTo:tab];
            return remaining;
        }
    }
    return tabs;
}

static void setTabs(UITabBarController *controller, SEL selector, NSArray *tabs) {
    if (@available(iOS 18.0, *)) tabs = tabsWithoutVoicemail(controller, tabs);
    originalSetTabs(controller, selector, tabs);
}

static void setTabsAnimated(UITabBarController *controller, SEL selector, NSArray *tabs, BOOL animated) {
    if (@available(iOS 18.0, *)) tabs = tabsWithoutVoicemail(controller, tabs);
    originalSetTabsAnimated(controller, selector, tabs, animated);
}

static void showLegacyTabs(id controller, SEL selector, bool favorites, bool recents,
                           bool contacts, bool keypad, bool voicemail __unused) {
    originalShowLegacyTabs(controller, selector, favorites, recents, contacts, keypad, false);
}

static bool matchesLegacyMethod(Method method) {
    if (!method || method_getNumberOfArguments(method) != 7) return false;
    char type[2] = {0};
    method_getReturnType(method, type, sizeof(type));
    if (type[0] != 'v') return false;
    for (unsigned int index = 2; index < 7; index++) {
        method_getArgumentType(method, index, type, sizeof(type));
        if (type[0] != 'B' && type[0] != 'c') return false;
    }
    return true;
}

__attribute__((constructor))
static void installNoVoicemailTab(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobilephone"]) return;

    Class tabBar = UITabBarController.class;
    MSHookMessageEx(tabBar, @selector(setViewControllers:), (IMP)setControllers,
                    (IMP *)&originalSetControllers);
    MSHookMessageEx(tabBar, @selector(setViewControllers:animated:), (IMP)setControllersAnimated,
                    (IMP *)&originalSetControllersAnimated);
    if (@available(iOS 18.0, *)) {
        MSHookMessageEx(tabBar, @selector(setTabs:), (IMP)setTabs, (IMP *)&originalSetTabs);
        MSHookMessageEx(tabBar, @selector(setTabs:animated:), (IMP)setTabsAnimated,
                        (IMP *)&originalSetTabsAnimated);
    }

    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26) {
        Class phoneTabs = objc_lookUpClass("PhoneTabBarController");
        SEL selector = sel_registerName("showFavoritesTab:recentsTab:contactsTab:keypadTab:voicemailTab:");
        if (phoneTabs && matchesLegacyMethod(class_getInstanceMethod(phoneTabs, selector))) {
            MSHookMessageEx(phoneTabs, selector, (IMP)showLegacyTabs, (IMP *)&originalShowLegacyTabs);
        }
    }
}
