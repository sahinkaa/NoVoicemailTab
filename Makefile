THEOS_PACKAGE_SCHEME ?= rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0

ifneq ($(filter $(THEOS_PACKAGE_SCHEME),rootless roothide),$(THEOS_PACKAGE_SCHEME))
$(error Choose THEOS_PACKAGE_SCHEME=rootless or roothide)
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoVoicemailTab
NoVoicemailTab_FILES = NoVoicemailTab.m
NoVoicemailTab_FRAMEWORKS = Foundation UIKit
NoVoicemailTab_LIBRARIES = substrate
NoVoicemailTab_CFLAGS = -fobjc-arc -Wall -Wextra -Werror

include $(THEOS_MAKE_PATH)/tweak.mk
