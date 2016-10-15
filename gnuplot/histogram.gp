#!/usr/bin/gnuplot -persist

reset

set style data histogram
set style histogram clustered
set style fill solid border


set terminal pngcairo size 800,600 enhanced font 'Verdana,11'
set output 'histogram.png'

set grid xtics nomxtics ytics nomytics noztics nomztics \
 		 nox2tics nomx2tics noy2tics nomy2tics nocbtics nomcbtics \
 		 lw 1

load 'palettes/spectral.pal'

set ylabel "Data size [kB]"
set ytics add (20000, 500, 50)
set logscale y
set yrange [ 1 : 50000]

set xlabel "Date"
set xtics rotate by 60 right

#set title "Per day difference between metadata size and size of zsync files" font ', 11'
set key nobox top center maxrows 1 font ', 15'

plot 'test.log' using 4:xtic(2) title columnheader ls 6, \
     'test.log' using 5:xtic(2) title columnheader ls 8