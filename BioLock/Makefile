ARCHS = arm64 arm64e
TARGET = iphone:clang:15.6:15.0

THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

-include device.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BioLock

BioLock_FILES = Tweak.x
BioLock_FRAMEWORKS = UIKit LocalAuthentication AudioToolbox
BioLock_PRIVATE_FRAMEWORKS = SpringBoardServices FrontBoardServices
BioLock_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += biolockprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
