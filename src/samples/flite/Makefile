

GFLAGS=`pkg-config --cflags   gmodule-2.0`
LIBS=`pkg-config --libs  gmodule-2.0`

all: ftest

ftest:	ftest.c
	$(CC) -o ftest ftest.c -I /usr/include/flite $(GFLAGS) $(LIBS)

clean:
	rm -f ftest
