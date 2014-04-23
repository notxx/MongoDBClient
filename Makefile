CC	= clang
CFLAGS	= -fPIC -Wunused -fconstant-string-class=NSConstantString -fblocks -D_NATIVE_OBJC_EXCEPTIONS -fobjc-runtime=gnustep -fobjc-arc
LDFLAGS	= -Wunused -L/usr/local/lib -lobjc -L/usr/GNUstep/Local/Library/Libraries -lgnustep-base -fconstant-string-class=NSConstantString -fblocks -lBlocksRuntime -fobjc-arc -fobjc-nonfragile-abi -D_NATIVE_OBJC_EXCEPTIONS -lmongoc

SOURCES	= $(wildcard *.m)
RELEASE_OBJECTS	= $(patsubst %.m,%.release.o,$(SOURCES))
DEBUG_OBJECTS	= $(patsubst %.m,%.debug.o,$(SOURCES))

RELEASE_TARGET	= libMongoDBClient.so
DEBUG_TARGET	= libMongoDBClient.debug.so

# Suffixes
%.release.o : %.m
	OBJC_INCLUDE_PATH=/usr/GNUstep/Local/Library/Headers/ $(CC) $(CFLAGS) -c -o $@ $^

%.debug.o : %.m
	OBJC_INCLUDE_PATH=/usr/GNUstep/Local/Library/Headers/ $(CC) $(CFLAGS) -c -o $@ $^

$(RELEASE_TARGET) : $(RELEASE_OBJECTS)
	 LD_LIBRARY_PATH="/usr/src/core/base/Source/./obj:/root/GNUstep/Library/Libraries:/usr/GNUstep/Local/Library/Libraries:/usr/GNUstep/System/Library/Libraries" $(CC) $(LDFLAGS) -shared -o $@ $(RELEASE_OBJECTS)

$(DEBUG_TARGET) : $(DEBUG_OBJECTS)
	 LD_LIBRARY_PATH="/usr/src/core/base/Source/./obj:/root/GNUstep/Library/Libraries:/usr/GNUstep/Local/Library/Libraries:/usr/GNUstep/System/Library/Libraries" $(CC) $(LDFLAGS) -shared -o $@ $(DEBUG_OBJECTS)

all: release debug
#	@echo $(SOURCES)
#	@echo $(RELEASE_OBJECTS)
#	@echo $(DEBUG_OBJECTS)

release: CFLAGS += -O2
release: $(SOURCES) $(RELEASE_TARGET)

debug: CFLAGS += -DDEBUG -g
debug: $(SOURCES) $(DEBUG_TARGET)

kernel.a: $(K_OBJS)
	ar -rcs kernel.a $(K_OBJS)
	chmod +x kernel.a

clean:
	rm -rf $(RELEASE_OBJECTS) $(DEBUG_OBJECTS)

rm:
	rm -rf $(RELEASE_TARGET) $(DEBUG_TARGET)
