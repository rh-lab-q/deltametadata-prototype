#!/usr/bin/gnuplot -persist

reset

set grid xtics nomxtics ytics nomytics noztics nomztics \
         nox2tics nomx2tics noy2tics nomy2tics nocbtics nomcbtics \
         lw 1

set terminal pngcairo size 600,300 enhanced font 'Verdana,9'
set output 'sync.png'

set xrange [ 1 : 21 ]
set xlabel "Number of days since last synchronization"
set xtics 1
set ytics 500

set label "Linear increase of approx.\n108 kB per day" at 15, 1150 center textcolor '#555555' font ', 11'
set title "Increase of synchronization size depending on synchronization frequency"

load 'palettes/spectral.pal'

set ylabel "Synchronization size [kB]"
set key nobox left top font ', 11'

set style fill solid 1.00 noborder
set style data lines

f(x) = 108 * x + 400
g(x) = 108 * x + 40

plot '+' using 1:(f($1)):(g($1)) with filledcurves closed title 'approximation' ls 6,\
     "data.dat" using 1:2 title "synchronization" lw 3 lt 1 with lines