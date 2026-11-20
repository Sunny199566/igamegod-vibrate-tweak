INSTALL_TARGET_PROCESSES = 

THEOS_PACKAGE_SCHEME = rootless
THEOS_PACKAGE_INSTALL_PREFIX = /var/jb

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RecordTweak
RecordTweak_FILES = Tweak.x
RecordTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
RecordTweak_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk