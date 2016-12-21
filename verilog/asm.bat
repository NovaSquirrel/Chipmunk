@echo off
ca65 ../ca65/test.s -o ../ca65/test.o
ld65 -C ../ca65/chipmunk.x ../ca65/test.o -o ../ca65/test.dat
hex ../ca65/test.dat test.hex
