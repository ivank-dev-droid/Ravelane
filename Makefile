CORE := Packages/RavelinCore
SWIFTLY_BIN := $(HOME)/.local/share/swiftly/bin
COMPAT_LIBS := $(HOME)/.local/share/swiftly/compat-libs

ifeq ($(shell uname), Linux)
export PATH := $(SWIFTLY_BIN):$(PATH)
export LD_LIBRARY_PATH := $(COMPAT_LIBS):$(LD_LIBRARY_PATH)
endif

.PHONY: build test verify sweep gen clean doctor

build:
	swift build --package-path $(CORE)

test:
	swift test --package-path $(CORE)

verify:
	swift run --package-path Tools/RavelinCLI RavelinCLI verify --all

sweep:
	swift run --package-path Tools/RavelinCLI RavelinCLI sweep --all

gen:
	xcodegen generate

doctor:
	@swift --version
	@echo "compat libs: $(COMPAT_LIBS)"
	@ls $(COMPAT_LIBS) 2>/dev/null || echo "  (none — macOS does not need them)"

clean:
	rm -rf $(CORE)/.build Tools/RavelinCLI/.build
