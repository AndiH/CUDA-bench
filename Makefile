# # ROOTLIBS := $(shell root-config --libs)
# # ROOTCFLAGS := $(shell root-config --cflags)
# # ROOTLIBS += lMinuit # Not included by default
# CFLAGS = $(shell root-config --cflags)
# LIBS   = $(shell root-config --libs)
# GLIBS  = $(shell root-config --glibs)
# GLIBS  += -lMinuit

PATHTOROOT = /home/ikp1/herten/fairsoft/extpkg/tools/root
PATHTOCUSP = /private/herten/

# COMPILEROPTIONS = -std=c++0x

ROOTLIBS := -m64 -I$(PATHTOROOT)/include -L$(PATHTOROOT)/lib -lCore -lCint -lRIO -lNet -lHist -lGraf -lGraf3d -lGpad -lTree -lRint -lPostscript -lMatrix -lPhysics -lMathCore -lThread -lm -ldl -L$(PATHTOROOT)/lib -lGui -lCore -lCint -lRIO -lNet -lHist -lGraf -lGraf3d -lGpad -lTree -lRint -lPostscript -lMatrix -lPhysics -lMathCore -lThread -lm -ldl -lMinuit

# OBJECTS = unordered_triplets.o AhTwoArraysToMatrix.o AhTranslatorFunction.o Ah2DPeakfinder.o
OBJECTS = bench.o

all:    bench

# unordered_triplets.o: unordered_triplets.cu AhTranslatorFunction.h
# 	nvcc -arch=sm_20 $(ROOTLIBS) -I$(PATHTOCUSP) -c unordered_triplets.cu
# 
# AhTwoArraysToMatrix.o: AhTwoArraysToMatrix.cu AhTwoArraysToMatrix.h AhTranslatorFunction.h
# 	nvcc -arch=sm_20 $(ROOTLIBS) -I$(PATHTOCUSP) -c AhTwoArraysToMatrix.cu

%.o:	%.cu
	nvcc -arch=sm_20 $(ROOTLIBS) -I$(PATHTOCUSP) -c $<

bench:  $(OBJECTS)
	nvcc -arch=sm_20 $(ROOTLIBS) -I$(PATHTOCUSP) -o $@ $(OBJECTS) 
