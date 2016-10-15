#!/usr/bin/gnuplot -persist

reset

set key invert reverse Left outside
set key autotitle columnheader
set style data histogram
set style histogram rowstacked
set style fill solid border -1
set boxwidth 0.75

set terminal pngcairo size 600,300 enhanced font 'Verdana,11'
set output 'comparison.png'

set grid xtics nomxtics ytics nomytics noztics nomztics \
         nox2tics nomx2tics noy2tics nomy2tics nocbtics nomcbtics \
         lw 1

load 'palettes/spectral.pal'

set ylabel "Data size [kB]"
set ytics add(23000)

set label "\\}" font ',25' at 1.4, 21500
set label '+{/Symbol \176}15%' at 1.65, 21500

set title "Change of data on server"

#plot for [COL=2:6] 'comparison.dat' using COL:xticlabels(1) title columnheader
plot 'comparison.dat' using 2:xtic(1) title columnheader ls 3, \
     '' using 3 title columnheader ls 4, \
     '' using 4 title columnheader ls 5, \
     '' using 5 title columnheader ls 6, \
     '' using 6 title columnheader ls 7