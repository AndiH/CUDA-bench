ROOTLIBS := $(shell root-config --libs)
ROOTLIBS += -lMinuit # Not included by default
ROOTLIBS += -lGui # Not included by default
ROOTCFLAGS := -I$(shell root-config --incdir)
ROOTCFLAGS += -m64
# CFLAGS = $(shell root-config --cflags)
# LIBS   = $(shell root-config --libs)
# GLIBS  = $(shell root-config --glibs)

# COMPILEROPTIONS = -std=c++0x

OBJECTS = bench.o

all:    bench

%.o:	%.cu
	nvcc -arch=sm_20 $(ROOTCFLAGS) $(ROOTLIBS) -c $<

bench:  $(OBJECTS)
	nvcc -arch=sm_20 $(ROOTCFLAGS) $(ROOTLIBS) -o $@ $(OBJECTS) 
