@echo off
ca65 test.s -o test.o
ld65 -C chipmunk.x test.o -o test.dat
pause
