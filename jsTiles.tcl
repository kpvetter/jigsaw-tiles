#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec wish $0 ${1+"$@"} & \
exit

##+##########################################################################
#
# jigsaw_tiles.tcl -- Game in which a player must restore an image that's
# been tiled and shuffled.
# by Keith Vetter 2023-07-30
#
# TODO
# quit preview early???
# show too small/wide picture's thumbnail???
#   e.g. potd_2019_04_27_w.jpg
#  check for animated GIF: Aug 11, 2009 Wikipedia  potd_2009_08_11_w.gif
#   potd_2012_12_21_w.gif potd_2023_08_01_w.gif
#
#
# BUGS:
# Timer: pause while "You ran out of lives!" dialog is up
# Commons 2009/10/08 is a VERY slow loading. svg/png with lots of transparency
#   - potd_2009_10_08_c.png
#   - need to adjust min ratio to view: set S(min,ratio) .48
#   - saved locally as slow.png
#   - month: https://commons.wikimedia.org/wiki/Template:Potd/2009-10
#   - day: https://commons.wikimedia.org/wiki/File:Ornamental_Alphabet_-_16th_Century.svg
#   - image: https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Ornamental_Alphabet_-_16th_Century.svg/1280px-Ornamental_Alphabet_-_16th_Century.svg.png
#
# Other image sources:
#  download random Wikimedia Commons images:
#      https://commons.wikimedia.org/wiki/Special:Random/File
#  random Wikipedia article main image
#  National Gallery of Art: nga.giv
#     https://www.nga.gov/collection-search-result.html?sortOrder=CHRONOLOGICAL&artobj_imagesonly=Images_online&artobj_downloadable=Image_download_available&artobj_lifespan=1800_2023&pageSize=90&pageNumber=300&lastFacet=pageSize
#     https://www.nga.gov/collection-search-result.html?sortOrder=CHRONOLOGICAL&artobj_imagesonly=Images_online&artobj_downloadable=Image_download_available&artobj_classification=painting&artobj_classification=photograph&pageSize=30&pageNumber=1&lastFacet=artobj_classification
#     https://www.nga.gov/collection-search-result.html?sortOrder=CHRONOLOGICAL&artobj_imagesonly=Images_online&artobj_downloadable=Image_download_available&artobj_classification=painting&artobj_classification=photograph&pageSize=30&pageNumber=100&lastFacet=artobj_classification
#     https://www.nga.gov/collection-search-result.html?
#         sortOrder=CHRONOLOGICAL&
#         artobj_imagesonly=Images_online&
#         artobj_downloadable=Image_download_available&
#         artobj_classification=painting&
#         artobj_classification=photograph&
#         pageSize=30&
#         pageNumber=1&
#         lastFacet=artobj_classification
#
package require Tk
package require Img
package require fileutil
package require textutil
package require tooltip
package require http
package require tls
http::register https 443 [list ::tls::socket -tls1 1]
package require tdom

source [file join [file dirname $argv0] src/wiki_potd.tcl]
source [file join [file dirname $argv0] src/buttonlistbox.tcl]
source [file join [file dirname $argv0] src/shadowborder.tcl]

catch {namespace delete Baseshape}

set S(title) "JigSaw Tiles"
set S(posting,date) "April 2025"
set S(creation,date) "August 2023"
set S(version) "1.1"

set S(beta) False
if {$::tcl_platform(user) eq "kvetter"} { set S(beta) True }

set S(inifile,file) "jsTiles.ini"
set S(inifile,tally) "jsTiles.log"
set S(inifile,favorites) "jsTiles.fav"

set S(img) TBD
set S(explode,delay) 100
set S(local,current) ""
set S(potd,current) ""
set S(click,who) "None"
set S(themes.start) {Ell Ess Hexagon Octagon Trapezoid}

set S(tempdir) [fileutil::maketempdir -prefix jigsaw_tiles_kpv_]
set S(local,cwd) ""

set S(min,width) 300
set S(min,height) 300
set S(min,ratio) .5
set S(difficulty,labels) {Easy Default Hard Harder Hardest}
set S(difficulty,pretty) "TBD"
set S(preview,delay) 3000
set S(kill,after) ""

set S(MOTIF) ""
set S(maxWidth) [expr {int([winfo screenwidth .] * .75)}]
set S(maxHeight) [expr {int([winfo screenheight .] * .8)}] ;# Get recalculated better below
set S(filesystem,writable) [file writable .]
set S(inside,zip) [expr {[info exists S(inside,zip)] ? $S(inside,zip) : 0}]

set meta [dict create]

set ST(alwaysResize,onoff) 1
set ST(color,shadows) 0
set ST(difficulty,raw) 0
set ST(inifile,onoff) 1
set ST(preview,onoff) 1
set ST(tallyfile,onoff) off   ;# Set true in ini file to keep a log of every potd image downloaded
set ST(last) ""

set STATS(pretty,time) "00:00"
set STATS(time,start) 0
set STATS(time,aid) ""
set STATS(count) 0
set STATS(bad) 0
set STATS(playback) {}
set STATS(total,Wikipedia) 0
set STATS(total,Commons) 0
set STATS(total,Local) 0
set STATS(total,Solved) 0

set FAVORITES {
    potd_2004_12_01_c.jpg "Pope John Paul II during General Audiency, 29 September 2004, St. Peter Sq., Vatican"
    potd_2004_12_24_c.jpg "Port wine"
    potd_2005_02_27_c.jpg "Castel Sant' Angelo, Rome"
    potd_2005_07_15_c.jpg "A spiral staircase inside one of the Vatican Museums"
    potd_2005_09_20_c.jpg "Astronaut Stephen K. Robinson anchored to a foot restraint on the International Space Station’s Canadarm2"
    potd_2006_04_05_c.png "Voivodships of the Polish-Lithuanian Commonwealth."
    potd_2006_04_24_c.jpg "The wreck of the American Star (SS America) seen from land side."
    potd_2006_05_22_c.png "Exploded view of a personal computer."
    potd_2006_11_24_c.jpg "Memorial to the Murdered Jews of Europe in Berlin, Germany"
    potd_2007_01_28_c.jpg "The McCormick Tribune Campus Center at the Illinois Institute of Technology, Chicago, Illinois"
    potd_2007_04_03_w.jpg "A photo of strabismus surgery, surgery on the extraocular muscles to correct misalignment of the eyes, being performed."
    potd_2007_04_17_w.jpg "The Tower Bridge, a bascule bridge that crosses the River Thames in London, England, at twilight."
    potd_2007_04_21_c.jpg "Light refraction through glass"
    potd_2007_04_21_w.jpg "Cartographic relief depiction showing the varying age of bedrock underlying North America."
    potd_2007_06_20_c.png "A diagram of the human eye."
    potd_2007_07_01_w.png "An animated image showing the territorial evolution of Canada, that is, the dates when each province and territory were created."
    potd_2007_07_12_c.jpg "The memorial to the Synagogue in Göttingen (Germany), burnt down 1938 during the Kristallnacht, at the Platz der Synagoge (Synagogue Square) as seen from the inside looking straight up."
    potd_2007_07_18_c.jpg "Concretepaver blocks"
    potd_2007_08_09_c.jpg "The flying gurnard, Dactylopterus volitans, in the Mediterranean sea."
    potd_2007_12_06_c.jpg "A bouncing ball captured with a stroboscopic flash at 25 images per second."
    potd_2008_02_13_c.jpg "Terrace rice fields in Yunnan Province, China."
    potd_2008_03_26_w.jpg "The School of Athens or \"Scuola di Atene\" in Italian is one of the most famous paintings by the Italian Renaissance artist Raphael."
    potd_2008_05_06_c.jpg "Map of the county of Flanders by 1609"
    potd_2008_05_29_w.png "A diagram of the human respiratory system, which consists of the airways, the lungs, and the respiratory muscles that mediate the movement of air into and out of the body."
    potd_2008_06_17_w.jpg "The 71st plate from German biologist Ernst Haeckel'sKunstformen der Natur, showing radiolarians of the order Stephoidea."
    potd_2008_06_28_c.jpg "A fire in Massueville, Quebec, Canada."
    potd_2008_07_08_c.png "Rubik's cube."
    potd_2008_08_26_w.jpg "Pigments for sale at a market stall in Goa, India."
    potd_2008_12_23_w.jpg "An 1885 lithograph of a bird's-eye view of the city of Phoenix, Arizona, the fifth-most-populous city in the United States."
    potd_2009_01_23_c.jpg "Kinderdijk windmills, Netherlands."
    potd_2009_02_01_c.png "Iowa class battleship main battery turret."
    potd_2009_02_04_c.jpg "A photochrome print of the front of Neuschwanstein Castle, Bavaria, Germany taken as few as ten years after the completion of the castle's construction"
    potd_2009_02_08_c.jpg "Hygieia fountain in the city hall courtyard, Hamburg, Germany"
    potd_2009_03_07_c.png "Royal coat of arms of the United Kingdom"
    potd_2009_04_27_w.jpg "An 1836 lithograph of Mexican women making tortillas, which are an unleavenedflatbread and have been a staple of Mesoamerican food for centuries, dating to approximately 10,000 BCE. The name \"tortilla\" comes from the Spanish word \"torta\", which means \"round cake\"."
    potd_2009_06_18_w.jpg "In the history of cartography, this chart of Pedro Reinel (c. 1504) is one of the oldest known nautical charts with a scale of latitudes and constructed on the basis of astronomical observations."
    potd_2009_11_14_w.jpg "An African American man climbs the stairs to a theater\"s 'colored\" entrance in Belzoni, Mississippi, in 1939."
    potd_2010_01_21_c.jpg "USS Bunker Hill hit by two Kamikazes in 30 seconds on 11 May 1945 off Kyushu."
    potd_2010_02_21_c.jpg "Sphaerophoria scripta on a Hawkweed flower (Hieracium sp.)"
    potd_2010_07_12_w.jpg "An M777 Light Towed Howitzer in service with the U.S. Army10th Mountain Division in support of Operation Enduring Freedom in Logar Province, Charkh District, Afghanistan."
    potd_2010_08_05_c.jpg "Fishermen from Lorenzkirch on the Elbe in front of Strehla, Saxony, Germany."
    potd_2010_09_05_c.jpg "National Chiang Kai-shek Memorial Hall in Taipei (Republic of China)"
    potd_2010_09_10_c.png "Illustration showing the anatomy of a mosquito (Culex pipiens)"
    potd_2011_02_18_w.jpg "An elaborate sand sculpture display at the Sand Sculpting Australia \"Dinostory\" festival."
    potd_2011_03_31_c.png "Bevel gear (toothed wheels)"
    potd_2011_12_30_w.jpg "Pure (99.97+%) iron chips, electrolytically refined, as well as a high purity 1\xA0cm3 iron cube for comparison."
    potd_2012_01_09_c.jpg "Varanasi, India as seen from Ganga river."
    potd_2012_03_08_w.jpg "A human eye displaying partial heterochromia iridum, where part of one iris is a different color from its remainder."
    potd_2012_04_29_c.jpg "Horse and rider in an obstacle race."
    potd_2012_05_18_c.jpg "Northeast Pavilion."
    potd_2012_06_12_c.jpg "The audience seen from the rear of the stage at the former Metropolitan Opera House in New York City at a concert by classical pianist Josef Hofmann on November 28, 1937."
    potd_2012_08_18_w.jpg "Six beryllium mirror segments of the James Webb Space Telescope (JWST) undergoing a series of cryogenic tests at NASA's Marshall Space Flight Center in Huntsville, Alabama."
    potd_2012_09_08_c.png "Łęczyca Voivodeship coat of arms."
    potd_2012_10_23_w.jpg "A view of the internal components of a 1998 Seagatehard disk drive (HDD)."
    potd_2012_12_06_c.jpg "Yak near Yamdrok lake, Tibet."
    potd_2012_12_08_c.jpg "Railway station in Kreiensen in the district of Northeim, Lower Saxony, Germany in the year 1963."
    potd_2013_01_16_w.jpg "Nasser Al-Attiyah, a Qatari rally driver, in a Ford Fiesta S2000 at the 2010 Rally Finland."
    potd_2013_03_15_w.jpg "Robin Hunicke (b. 1973) is an American video game designer and producer who worked for several companies before establishing her own, Funomena, in 2011."
    potd_2013_07_01_w.jpg "Poster for Queen Christina, a Pre-Code Hollywood biographical film produced in 1933 and directed by Rouben Mamoulian."
    potd_2013_07_04_w.jpg "Official portrait of the 1899 Michigan Wolverines football team, an American football team which represented the University of Michigan in the 1899 season."
    potd_2013_08_28_w.jpg "The ladder snake (Rhinechis scalaris) is found mostly in peninsular Spain, Portugal, and southern France."
    potd_2013_10_28_c.jpg "Main facade of the Academy of Athens, Greece"
    potd_2013_11_12_c.jpg "Mergozzo at the Lago di Mergozzo, rowing boats, (motorboats forbidden)."
    potd_2013_12_29_w.jpg "Sign painting is the art of painting announcements or advertisements on buildings, billboards or signboards."
    potd_2014_01_14_w.jpg "The Humble Oil Building in Houston, Texas, was completed by the Humble Oil and Refining Company in 1921."
    potd_2014_04_01_c.jpg "Eastern span of the San Francisco–Oakland Bay Bridge."
    potd_2014_07_24_c.jpg "Birdy at the SWR3 New Pop Festival in Baden-Baden 2013"
    potd_2014_09_22_c.jpg "The Petite Ceinture railway line (\"Little Belt railway\") passing through the parc Montsouris, 14th arrondissement of Paris, France."
    potd_2014_12_15_w.jpg "An aerial view of Manhattan in 1873, with Battery Park in the foreground and the Brooklyn Bridge under construction at the right."
    potd_2014_12_30_w.jpg "The Half Dome is a granite dome in California's Yosemite National Park, whose summit at elevation 8,844\xA0ft (2,696\xA0m) is more than 4,700\xA0ft (1,400\xA0m)* above the floor of Yosemite Valley."
    potd_2015_02_07_w.jpg "The Old Town of Prague, Czech Republic, is a medieval settlement."
    potd_2015_05_20_c.jpg "Flanges in the tool shed of the Quarzwerke in Sythen, Haltern am See, Germany"
    potd_2015_05_22_c.jpg "Saint Basil's Cathedral in Moscow at night."
    potd_2015_06_29_c.jpg "Plastic pipes in the tool shed of the Quarzwerke in Sythen, Haltern am See, Germany"
    potd_2015_07_11_c.jpg "Lettering guides for technical drawings."
    potd_2015_08_18_c.jpg "Elephant Rock in the cliffs of the island Heimaey, Westman Islands, Suðurland, Iceland."
    potd_2015_08_30_w.jpg "Nighthawks is an oil painting on canvas completed by the American artist Edward Hopper in 1942."
    potd_2015_12_01_c.jpg "Fireworks over Ponte Vecchio in Florence, Italy."
    potd_2016_02_05_c.jpg "Niels Simonsen, Retreat from Dannevirke, 1864, 1864, Det Nationalhistoriske Museum på Frederiksborg Slot Episode of the retreat from Dannevirke, 5 - 6 February 1864 - Battle of Sankelmark and Oeversee."
    potd_2016_04_22_w.jpg "A banknote for two Massachusetts shillings, or 1/10 of a Massachusetts pound, dated 1 May 1741."
    potd_2016_05_10_c.jpg "Library of Altenburg Abbey, Lower Austria"
    potd_2016_05_12_w.jpg "The Art of Painting is a 17th-century oil painting on canvas by Dutch painter Johannes Vermeer."
    potd_2016_05_19_c.jpg "Pipe organ of the church of the Society of Jesus (La Iglesia de la Compañía de Jesús), a Jesuit church in Quito, Ecuador."
    potd_2016_06_22_w.jpg "A lithograph by Thaddeus Mortimer Fowler showing the town of New Kensington, Pennsylvania, in 1896."
    potd_2016_07_12_w.png "Halftone is the reprographic technique that simulates continuous tone imagery through the use of dots, varying either in size or in spacing, thus generating a gradient-like effect."
    potd_2016_07_17_w.jpg "Ty Cobb (1886–1961), shown here sliding into third base on August 16, 1924, was an American Major League Baseball (MLB) outfielder."
    potd_2016_08_15_w.jpg "Shane Tuck, a United States Navy mass communication specialist, conducting underwater photography training off the coast of Guantanamo Bay, Cuba, in 2012."
    potd_2016_11_04_c.jpg "Old diesel locomotive TEM2M-063 in Vinnitsa railway station, Ukraine."
    potd_2016_11_16_w.jpg "Bangles on display in Bangalore, India."
    potd_2016_12_13_c.jpg "The Palace of Justice in Munich was constructed in 1890-1897 by the architect Friedrich von Thiersch in neo-baroque style at the west side of Stachus."
    potd_2016_12_23_w.jpg "Nuremberg is a census-designated place in Schuylkill and Luzerne counties, Pennsylvania, United States."
    potd_2017_01_14_c.jpg "Shinjuku is a special ward in Tokyo, Japan."
    potd_2017_02_22_w.jpg "A LufthansaAirbus A320-211 taking off at Stuttgart Airport, Germany."
    potd_2017_03_31_c.jpg "Main hall of BerlinCentral Station with incoming S-Bahn train."
    potd_2017_04_03_c.jpg "Crypt of the Cádiz Cathedral, Cádiz, Andalusia, Spain."
    potd_2017_05_20_w.jpg "A Company of Danish Artists in Rome, painted by Constantin Hansen in 1837."
    potd_2017_06_22_w.jpg "The Evening Air, a c. 1893 oil painting on canvas by Henri-Edmond Cross (1856–1910)."
    potd_2017_11_15_w.jpg "A collection of sixteen wood samples, from left to right, top to bottom:"
    potd_2018_03_03_c.jpg "Entrance to building on Sonnenstraße 15, Munich."
    potd_2018_03_05_w.jpg "A ten Canadian dollar note, dated 1935."
    potd_2018_03_14_c.jpg "Fractal forms on the coverside of a microwaved DVD"
    potd_2018_04_20_c.jpg "A tape head cleaner cassette made of clear hard plastic."
    potd_2018_04_25_w.jpg "This Leica\xA0I camera was produced in 1927."
    potd_2018_05_04_c.jpg "May 4 is a traditional Firefighters' Day in many European countries."
    potd_2018_05_15_c.jpg "Rumyantsevo metro station in Moscow, Russia."
    potd_2018_06_07_c.JPG "Museum Brandhorst, Munich."
    potd_2018_06_18_w.jpg "A 15-cent banknote depicting Union Army generals William Tecumseh Sherman and Ulysses S. Grant, dated 1866 and intended as part of the fractional currency introduced to the United States following the American Civil War."
    potd_2018_07_08_c.jpg "Ceiling of the Historical Court Bower, Lübeck, Schleswig-Holstein, Germany"
    potd_2018_07_19_w.jpg "The Indian Head eagle was a ten-dollar gold piece, or eagle, struck by the United States Mint from 1907 until 1933."
    potd_2018_08_05_c.jpg "North wing of the cloister at Zwettl Abbey, Lower Austria"
    potd_2018_08_11_c.jpg "Entrance hall of the regional court of Berlin located in Littenstrasse 12-17 in Berlin-Mitte."
    potd_2018_12_27_w.jpg "Hayley Williams (born December 27, 1988) is an American singer, songwriter, musician, and businesswoman."
    potd_2019_08_25_w.jpg "Wemyss Bay railway station serves the village of Wemyss Bay in Inverclyde, Scotland."
    potd_2019_11_07_w.jpg "The Pool of Bethesda was a pool of water in the Muslim Quarter of Jerusalem, on the path of the Beth Zeta Valley."
    potd_2019_12_08_w.jpg "Dustin Brown (born 8\xA0December\xA01984) is a Jamaican-German professional tennis player."
    potd_2020_01_04_w.jpg "A Louis d'or is a French gold coin, first introduced by Louis\xA0XIII in 1640, featuring a depiction of the head of a King Louis on one side of the coin, from which its name derives."
    potd_2020_02_09_c.jpg "Interior view of the Holy Cross Church in Dülmen, North Rhine-Westphalia, Germany"
    potd_2020_03_11_c.jpg "Weeping Golden Willow."
    potd_2020_04_20_w.jpg "Duke Humfrey's Library is the oldest reading room in the Bodleian Library at the University of Oxford."
    potd_2020_04_25_w.jpg "HARDEST? Tract housing evolved in the 1940s when the demand for cheap housing rocketed after World War\xA0II."
    potd_2020_06_26_w.jpg "San Lorenzo, also known as the Royal Church of Saint Lawrence, is a Baroque-style church in Turin, Italy."
    potd_2020_08_21_w.png "This is an animation showing geocentric satellite orbits, to scale with the Earth, at 3,600 times actual speed."
    potd_2020_11_04_c.jpg "Panorama road between Waltensburg / Vuorz and Breil/Brigels."
    potd_2020_11_07_c.jpg "HARDEST? Heap of cans outside the South Korea Pavilion of Expo 2015."
    potd_2021_01_13_c.jpg "Dunes and shadows in Sossusvlei, Namibia."
    potd_2021_01_19_c.jpg "Interior of Santa Isabel Theater in the Brazilian city of Recife, capital of Pernambuco state."
    potd_2021_02_03_c.jpg "Dichroic prismWikipedia: Dichroic prism"
    potd_2021_03_20_c.jpg "Kurdish family watching Nowruz celebration, Besaran village, Eastern Kurdistan."
    potd_2021_03_30_w.jpg "Vincent van Gogh (30\xA0March\xA01853\xA0– 29\xA0July\xA01890) was a Dutch Post-Impressionist painter and one of the most famous and influential figures in the history of Western art."
    potd_2021_07_30_w.jpg "Nebotičnik is a high-rise building located in the centre of Ljubljana, Slovenia."
    potd_2021_10_23_c.jpg "The Stata Center, an academic complex at the Massachusetts Institute of Technology designed by Frank Gehry"
    potd_2022_04_02_w.jpg "Sand is a granular material composed of finely divided rock and mineral particles."
    potd_2022_05_19_w.jpg "The Supermarine Spitfire is a British single-seat fighter aircraft that was used by the Royal Air Force and other Allied countries before, during, and after World War II."
    potd_2022_06_14_w.png "The checker shadow illusion is an optical illusion published in 1995 by Edward Adelson, an American professor of vision science at the Massachusetts Institute of Technology."
    potd_2022_07_13_c.jpg "The Oval Hall of the Saint Michael's Castle in Saint Petersburg, Russia"
    potd_2022_07_24_c.jpg "Guard at the Prague castle, Prague."
    potd_2022_07_27_c.jpg "The Mircea (ship, 1938) moored at the embankment \"Quai d'Alger\" during the event \"Escale à Sète 2022\"."
    potd_2022_09_19_w.jpg "Women took on many different roles during World War\xA0II, including as combatants or workers on the home front."
    potd_2023_02_27_c.jpg "Oranges – whole, halved and peeled segment"
    potd_2023_03_13_w.jpg "The Olympus OM-D E-M1 Mark III is the third iteration of the flagship camera in the series of OM-D mirrorless interchangeable-lens cameras produced by Olympus on the Micro Four-Thirds system."
    potd_2023_03_19_c.jpg "Royal pavilion in Phraya Nakhon Cave in Khao Sam Roi Yot National Park, Prachuap Khiri Khan province, Thailand"
    potd_2023_04_07_c.jpg "Romanesque crucifixion group at Seckau Basilica, Styria, Austria"
    potd_2023_05_26_w.png "Thyroid hormones are hormones produced and released by the thyroid gland, namely triiodothyronine (T3) and thyroxine (T4)."
    potd_2023_05_29_w.jpg "Mount Everest is Earth's highest mountain above sea level, located in the Himalayas along the China–Nepal border."
    potd_2023_08_08_c.jpg "Interior of the main hall of the Museum of the History of Polish Jews in Warsaw, Poland."
    potd_2023_12_18_c.jpg "Indian peafowl (Pavo cristatus) in Ribeirão Preto, São Paulo, Brazil"
    potd_2024_01_11_c.jpg "An ultrawide angle panoramic view along the inside of L'Umbracle, designed by renowned Spanish architect Santiago Calatrava, in the City of Arts and Sciences in Valencia, Spain."
    potd_2024_06_06_c.jpg "Chkalovskaya metro station in Yekaterinburg, Russia."
}

set text_font [concat [font actual TkDefaultFont] -size 15]
set bold_font [concat [font actual TkDefaultFont] -weight bold]
set big_font [concat [font actual TkDefaultFont] -size 18]
set big_bold_font [concat [font actual TkDefaultFont] -size 18 -weight bold]
set bigger_font [concat [font actual TkDefaultFont] -size 24]
set bigger_bold_font [concat [font actual TkDefaultFont] -size 64 -weight bold]
set bigger_bold_font2 [concat [font actual TkDefaultFont] -size 48 -weight bold]
set biggest_bold_mono_font {"Courier New" 192 bold}
set small_font [concat [font actual TkDefaultFont] -size 10]
set mono_font {"Courier New" 20}

proc LoadShapes {} {
    # Load external shape source files
    if {[namespace exists Baseshape]} return
    set shape_glob [file join [file dirname $::argv0] shapes *.shape]
    foreach fname [lsort -dictionary [glob -nocomplain $shape_glob]] {
        Logger "loading shape $fname"
        source $fname
    }
}

proc DoDisplay {} {
    global S

    wm title . $S(title)
    wm iconphoto . -default ::img::icon

    ::ttk::frame .bg
    pack .bg -side top -fill both -expand 1

    canvas .c -highlightthickness 0 -bg gray75 -width 800 -height 700

    ::ttk::frame .bbar -relief ridge -borderwidth 2
    ::ttk::frame .left -relief ridge -borderwidth 2
    ::ttk::frame .bottom -relief flat -borderwidth 0

    ::ttk::button .logo -image ::img::icon2 -command AboutDialog
    ::tooltip::tooltip .logo "$S(title) by Keith Vetter"

    # Themes frame
    ::ttk::frame .themes -relief ridge -borderwidth 2 -padding .1i
    ::ttk::label .themes.title -text Tessalations -font $::big_font -anchor c
    ::tooltip::tooltip .themes.title "How to create jigsaw tiles"
    ::ttk::button .themes.again -text "Scramble" -command Restart
    ::tooltip::tooltip .themes.again "Restart current image"
    bind .themes.again <2> [list SelectTessalation all]
    bind .themes.again <3> [list SelectTessalation all]

    grid .themes.title -sticky ew -pady .1i
    grid .themes.again -pady {0 .1i}
    set themes [AvailableThemes]
    if {$S(themes.start) eq {}} { set S(themes.start) $themes }
    foreach theme $themes {
        set id [string tolower .themes.$theme]

        set S(themes,$theme) [expr {$theme in $S(themes.start)}]
        ::ttk::checkbutton $id -text $theme -variable S(themes,$theme)
        grid $id -sticky w
        bind $id <2> [list SelectTessalation $theme]
        bind $id <3> [list SelectTessalation $theme]
    }

    # Open, next frame
    ::ttk::frame .buttons -relief ridge -borderwidth 2 -padding .1i
    ::ttk::label .buttons.title -text "New Picture" -font $::big_font -anchor c
    ::ttk::button .buttons.open -text "Open" -command GetLocalPicture \
        -image ::img_icon::file -compound top
    ::tooltip::tooltip .buttons.open "Select new image"
    ::ttk::button .buttons.next -text "Next" -command {GetLocalPicture True} \
        -image ::img_icon::next -compound top
    ::tooltip::tooltip .buttons.next "Select next image\nfrom last directory accessed"

    grid .buttons.title -sticky ew -pady .1i
    grid .buttons.open
    grid .buttons.next

    # POTD frame
    ::ttk::frame .potd -relief ridge -borderwidth 3 -padding .1i
    ::ttk::label .potd.title -text "POTD" -font $::big_font -anchor c
    ::tooltip::tooltip .potd.title "Download random\nPicture of the Day"
    ::ttk::button .potd.w -text "Wikipedia" -command [list GetPotDImage Wikipedia] \
        -image ::img_icon::wiki -compound top ;# -padding {0 0 0 .05i}
    ::tooltip::tooltip .potd.w "Download random PotD\nfrom Wikipedia"
    ::ttk::button .potd.c -text "Commons" -command [list GetPotDImage Commons] \
        -image ::img_icon::commons -compound top ;# -padding {0 0 0 .05i}
    ::tooltip::tooltip .potd.c "Download random PotD\nfrom WikiCommons"
    ::ttk::button .potd.save -text "Save POTD" -command SavePotD -state disabled
    bind .potd.save <2> SavePotDFast
    bind .potd.save <3> SavePotDFast
    ::tooltip::tooltip .potd.save "Save last downloaded POTD"

    grid .potd.title -sticky ew -pady .1i
    grid .potd.w
    grid .potd.c
    grid .potd.save -pady {.3i .1i}

    # Bottom of the screen labels
    ::ttk::label .bottom.iname -textvariable S(pretty,source) -anchor c -borderwidth 5 -relief ridge
    ::tooltip::tooltip .bottom.iname "Current image file"
    ::ttk::label .bottom.desc -textvariable S(pretty,desc) -anchor c -borderwidth 5 -relief ridge \
        -justify center
    ::tooltip::tooltip .bottom.desc "Image description (if any)"

    grid .logo .bbar -in .bg -sticky news
    grid .left .c -in .bg -sticky news
    grid ^ .bottom -in .bg -sticky ew

    grid .themes -in .left -row 1 -column 0 -sticky news
    grid .buttons -in .left -row 2 -column 0 -sticky news
    grid .potd -in .left -row 3 -column 0 -sticky news

    grid rowconfigure .left 100 -weight 1
    grid rowconfigure .bg 1 -weight 1
    grid columnconfigure .bg 1 -weight 1

    grid columnconfigure .bottom 0 -weight 1
    grid .bottom.iname -sticky news
    grid .bottom.desc -sticky news

    DescriptionDialog 0

    bind .c <Button-1> [list ClickDown %x %y]
    bind .c <B1-Motion> [list ClickMove %x %y]
    bind .c <ButtonRelease-1> [list ClickUp %x %y]

    ButtonBar .bbar
    ExtraButtons .bbar
}
proc ButtonBar {bar} {
    global BB

    set TT(Puzzle) "Expert mode with some hidden tiles"
    set TT(Timer) "Toggles showing a puzzle timer"
    set TT(Magic) "Toggles the Magic dialog with\nsome hidden functionality"
    set TT(Date) "Toggles the Date Download dialog"
    set TT(Desc) "Toggles the Description dialog with\nverbose descriptions of the images"
    set TT(Logs) "Toggles the Logs Dialog"
    set TT(Favorites) "Toggles the Favorites Dialog"
    set TT(About) "Toggles the About Dialog"

    # ttk::style configure Toolbutton -font $small_font
    set tabs {Puzzle Timer Magic Date Desc Logs Favorites About}

    foreach who $tabs {
        set w $bar._$who
        set BB($who,w) $w
        set img ::img_icon::[string tolower $who]
        set BB($who) 0
        ::ttk::checkbutton $w -image $img -variable BB($who) -style Toolbutton \
            -command [list DialogOnOff $who toggle] -text $who -compound top
        ::tooltip::tooltip $w $TT($who)
        pack $w -side left
        if {$who eq "Puzzle"} { $w config -command Puzzle -text "Expert off"}
        if {$who eq "Desc"} { $w config -text "Descriptions"}
    }
    bind .bbar._Favorites <2> ::Favorites::Random
    bind .bbar._Favorites <3> ::Favorites::Random
    bind .bbar._About <2> ::Magic::RandomSwap
    bind .bbar._About <3> ::Magic::RandomSwap
    bind .bbar._About <Control-2> ::Magic::OneTile
    bind .bbar._About <Control-3> ::Magic::OneTile
}
proc ExtraButtons {bar} {
    ::ttk::frame $bar.extra -borderwidth 1 -relief raised

    ::ttk::button $bar.extra.random -text Random -command ::Magic::RandomSwap
    ::ttk::button $bar.extra.single -text Single -command ::Magic::OneTile
    ::ttk::button $bar.extra.solve -text Solve -command ::Magic::Solve

    ::tooltip::tooltip $bar.extra.random "Swap two random tiles"
    ::tooltip::tooltip $bar.extra.single "Correctly place one tile"
    ::tooltip::tooltip $bar.extra.solve "Finish solving the puzzle"

    pack {*}[winfo children $bar.extra] -expand 1
    pack $bar.extra -side left -fill y
}
proc ComputeBestSize {} {
    # Makes a guess at usable screen height
    # Non-Darwin platforms get a reasonable initial value
    if {$::tcl_platform(os) eq "Darwin"} {
        set total [winfo screenheight .]
        set menubar 25
        set window_title 30
        set bbar [winfo height .bbar]
        set bottom [winfo height .bottom]
        set shadowBorder 50
        set slop 20

        if {$bbar == 1 || $bottom == 1} {
            return
        }
        set free [expr {$total - $bbar - $bottom - $menubar - $window_title - $shadowBorder - $slop}]
        set ::S(maxHeight) $free
    }
}
proc DialogOnOff {who how} {
    global BB
    set top .[string tolower $who]

    if {$how eq "toggle"} {
        set how [expr {[winfo exists $top] && [winfo ismapped $top] ? "off" : "on"}]
    }
    if {$how eq "on"} {
        set BB($who) 1
        if {[winfo exists $top]} {
            wm deiconify $top
        } else {
            if {[info commands ::${who}::Dialog] ne ""} {
                set cmd ::${who}::Dialog
            } else {
                set cmd ${who}Dialog
            }
            eval $cmd
        }
    } else {
        set BB($who) 0
        if {[winfo exists $top]} {
            wm withdraw $top
            if {$who eq "Magic"} ::Magic::CleanUp
            if {$who eq "Favorites"} { destroy $top }
        }
    }
}
proc SelectTessalation {who} {
    # Turn off tessalation for every type other than $who
    global S
    foreach theme [AvailableThemes] {
        set S(themes,$theme) [expr {$who eq $theme || $who eq "all"}]
    }
}
proc CreateLogsDialog {} {
    global S

    set top .logs
    set body [DialogTemplate Logs $top "Execution Logs"]
    wm title $top "$S(title) Log"
    wm resizable [winfo toplevel $body] 1 1
    wm transient $top .

    set S(logger) $body$top

    text $S(logger) -font $::text_font -wrap word
    $S(logger) tag configure emsg -foreground red
    pack $S(logger) -side top -fill both -expand 1
    wm withdraw $top

    set when [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    $S(logger) insert end "Log for $S(title) on $when\n"
}
proc DateDialog {} {
    global S

    set top .date
    set body [DialogTemplate Date $top "Date Download"]
    wm title $top "$S(title) Date Download"

    set year [clock format [clock seconds] -format %Y]
    set years [range 2007 $year+1]
    set months [range 1 13]
    set days [range 1 32]

    set S(date,window) $top
    if {! [info exists S(date,year)]} {
        set S(date,year) [lpick $years]
        set S(date,month) [lpick $months]
        set S(date,day) [lpick $days]
    }

    set dframe $body
    DateDialogBody $dframe
}
proc DateDialogBody {dframe} {
    set year [clock format [clock seconds] -format %Y]
    set years [range 2007 $year+1]
    set months [range 1 13]
    set days [range 1 32]

    ::ttk::label $dframe.help -text "Download PotD for a specific date" -font $::bigger_font
    ::ttk::frame $dframe.upper
    ::ttk::frame $dframe.buttons
    grid $dframe.help -pady .25i
    grid $dframe.upper
    grid $dframe.buttons
    grid columnconfigure $dframe {0} -weight 1

    ::ttk::label $dframe.upper.lyear -text "Year" -anchor c
    tk_optionMenu $dframe.upper.year ::S(date,year) {*}$years
    $dframe.upper.year config -width 4 -anchor c

    ::ttk::label $dframe.upper.lmonth -text "Month" -anchor c
    tk_optionMenu $dframe.upper.month ::S(date,month) {*}$months
    $dframe.upper.month config -width 4 -anchor c

    ::ttk::label $dframe.upper.lday -text "Day" -anchor c
    tk_optionMenu $dframe.upper.day ::S(date,day) {*}$days
    $dframe.upper.day config -width 4 -anchor c

    ::ttk::button $dframe.buttons.wiki -text "Wikipedia" -command {DateFetch Wikipedia} \
        -image ::img_icon::wiki -compound top
    ::tooltip::tooltip $dframe.buttons.wiki "Download PotD for this date\nfrom Wikipedia"
    ::ttk::button $dframe.buttons.commons -text "Commons" -command {DateFetch Commons} \
        -image ::img_icon::commons -compound top
    ::tooltip::tooltip $dframe.buttons.commons "Download PotD for this date\nfrom WikiCommons"

    grid $dframe.upper.lyear $dframe.upper.lmonth $dframe.upper.lday -padx .1i
    grid $dframe.upper.year $dframe.upper.month $dframe.upper.day -padx .1i

    grid $dframe.buttons.wiki $dframe.buttons.commons -pady .5i -padx .2i
}
proc DateFetch {service} {
    # Get PotD for date specified in the date dialog
    global S

    destroy $S(date,window)
    set override [list $S(date,year) $S(date,month) $S(date,day)]
    GetPotDImage $service $override

}
image create photo ::img::icon -data {
    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}
image create photo ::img::icon2
::img::icon2 copy ::img::icon -subsample 2 2
image create photo ::img::quest -data {
    iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAACXBIWXMAAA7EAAAOxAGVKw4bAAADcklE
    QVR4nO2bQUgVQRjHf5WIiISIiIhIRKiHkigP0sFTRIeI6BAhnaJDdCgJTxVeIsJT3SQ6ROcOEhERQRFi
    QSnVIUwKAqNCw6LMzLReh3nLe+vbnX3uNzuzvvd+MOxh9n3z/75Z9s188+0G7FAL7AG6gQ6gFWgC6oA/
    wFdgFpgGJoFx4CWwYklfYuwFbgELQGaN7QtwDdhpXbUBdgFjFDq1ALwFJoDnwMeAe4LaCLDFpgMSTgPL
    +GdyENgObAy4f1u2fwZ9EL4DhxLWLuYSftH3gcYif7sZGEYfhL/ASbOSzXEOv9i7QHUMOydQjuqCcMSA
    XqMcxC/6M2pG49KP/kmYB9oF9o1Sj3I4X+AVA3bvoQ/CYwNjGOEiheLOGrDbif9lGtQOGBhHRBWFs59B
    vQxNcCfAdn57ZGic2HQTLGzUkP2+EPv5L8QWQ2PF4niAKE9YpwH7LSH289sxyQBBC5O10KSxe15oG+AT
    ao+gY4dkAGkAdL/vw8xTMB3RX+xCKxBpAH5E2D4jtB81hjdObKQBeBPRf1hoH+BfRP9PiXFpAJ6gn6FG
    4i2H86mN6J+RGJcG4BdwVdM/jUp4SGiO6H8ntC+mGnhA8F+UdEVYQ/RqsE04hhFqUVtZT+wSMIT8CetB
    7/wLoX3jNKBSWPWG7K3eYiex50g1E+i3xA3upCVPF/rZv+xOmh2uE+68NOGSepqBRcIDYGKBlWqGCHf+
    pkNdVmhApcCDnH+NOk0qaYJSbBngGylKhCZF2OwvA/sd6rJG2OyfcinKFvWox3y18yZS7OuCQQqdH0G+
    n1gX1AFz+J2foAze+B4D+J2fISXbXBtUAx/IOb8E9DpVZJnVhx/9buXYZ5Sc87cda7FOO/4dnijHvx7J
    z/ikrujBBk9Rzo+5FuKCOnJJ1NQXPyVBL7ldnvTwJDYul5ld2etD5IcnsXEZgI7s1VQxRSxcBmBr9jru
    UINTXqHeAWX33+8xh8r+lCU1qNmfci2kytG4K8Bu1PF6hQoVKjhjk8OxW1GHoPOoytKy4Sjq7y+/0GGY
    Ei928LhA+KnvJCUehB70n8JkUEURJYuu4sNri0QXRhrF5m6wmMLpGiwfgdsMQLFJj9+JqliFzQA8K+Ke
    WVJQ+poUbYSXvnhtwJk6S+wj/EPqG5TJUXgnqtJrCniP+j7QWdnbf29LiHS7qT0aAAAAAElFTkSuQmCC}
image create photo ::img::quest_white -data {
    iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAQAAAAAYLlVAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1
    MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAD/h4/MvwAAAAd0SU1FB+cKEBYHJljbAlwAAAMiSURBVGje
    7ZlPSBRRHMe/xrLIsphsi0iIRMTqoUTMg3jwEBEdIkoiwrOH6JBaniy8RAdPdQgkPITnDtGhLIIoxIJS
    6hIqBYFSpqWppaarfbtM68zb3X4z83u7XvrNZd7s78/nvTdvfu/9toQILDE0oxE1qEIF4tjAAuYwhXGM
    4i02A3tjsOso73KF+eQrb7M+mMcgyg0cyYRa4XuO8TU/5cC4x32FALjItNPLXh7krszzA+zlrIGwxFO2
    Aa47rh8zmePXMvYbCFs8bxOgx3H7gNG8Ou3cMhDO2gI46bieYdk/9TqNUfjBlA2Acs44Dm+IukMGwnMZ
    YJe4Ti+j0rmbFnW7jO9AC05IJhJABO2Z+z0iwAQeZeErP0SNrgEd9vG+tGWthr26Kahz3TejVuzPs6wR
    PqKbggqP7hUR4DPmjCeHdADe39t8jMGU0U7qAJYN7Q4RYNloCxEkgAmj3SoC/DbaP3UAL4weJREVLGJG
    e1YHsIqbnvYUNgSLSqP9QdAXV3aUT1zr+pKgXeok7W2p1iejGPuZJrnOPtc+IPfVZIR/YyMbgmCC9Sz3
    oddjAEgjFnhPKF1jRkJO6LNhEKlDg6d9CwuijdX+D3j6L21grE9BJdc8AK1+rGwC9HnCD/qzshc+wSVX
    +HeM+7Oz9xJ2oSxzv4jTUg6w/RK6+5/mcf+WtgCuuYb/QhBLO+HL+T0TXt68FwCg13UwlbJFAQDinHfC
    j/l99+0CdDvhZ6XUWxiAKKdJkutsCWOvB/h7FOkMZ68HGCZJ3g9rrw2fcvJeMqwH7af4DACgA99Ce1CO
    wEuSIxoPuvBxpkn/BSn7U9CACBbxUONCB1AH4Kl4VCkgQA2AYZUHJcB+AKM7CVCF7PNzQCkJUS3flnlE
    sHvnRqAUCXzRhQciCttNHMaqFkA3BRbE7tnwP0DRAaqQEotWkoTOY+c46RQh+uUyhP10fNVzEh4PjxDO
    rMn4e4YcKC7AAE1ZY6yYG5LsknUpUsVcBbm2IL+KCfAq68mcWJLNJ6FmrtpTjiHJ7mIvw2Oev7DvBD2U
    6wHAWg5ykh855K8cl+/6A9sVEQBvBxkaAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDIzLTEwLTE2VDIyOjA2
    OjU1KzAwOjAwEkByMQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyMy0xMC0xNlQyMjowNjo1NSswMDowMGMd
    yo0AAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjMtMTAtMTZUMjI6MDc6MzgrMDA6MDB8cugrAAAAAElF
    TkSuQmCC}
# https://www.iconfinder.com/search?q=brain&price=free&style=outline
image create photo ::img_icon::puzzle -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAQAAAD9CzEMAAADg0lEQVR42u3Y22vXdRzH8YfL6cRDW1la
    oaZLnIkRiYGYs3AG85QHnFSUrOnEkWJSaGhq2rBwqUtDxG52qWBmW1KCSVm6Qtmch7A5LTNkMJfm3HKn
    bxBe7Mvv99t+btKVj9cf8ORz9YG3e+6OJ+TY6ZBzav/bBWX2WWO6PrqojyVOCly2T75F5pphjjcss0Op
    evX2mKabTkmwUI1qG4wWXZLZdrvlZxnuWIqv1FkpCWH9DdDWUEVa7NKL+PVX4bQRIhVoFtirh7bSXVZh
    kDglKnVCChJMkNFmi92Saaxqi4U95IhfPSIuH7liAHhOILxKUKwQYX0dc1ofHRqrxWTAJC3aGq5RoTUa
    TREp2QW7dKjYfmIEyPSjMgtFN16z6do1SqsxEYH4bfaL+4jtfWXECAw0UyoAHnNQvWNGAuBhdV4ltgrv
    xQi8qEGdFosAlCg1Q4mT2ipwUkz9tJgQCrRacXvnbcUSN3QH1JiLsQK9ATBCYLQY0gUeDAUCx2+vXg4m
    atUXcNBh6XY7K+yEdWKY7zrCLwD4QK0dLtkLYLAfBCo8JWyj78SwUnnMQII8e6ySBIAUgacRlqlBd1Gt
    dxQ8a5Uvlboo8KmZ+gmJCAxT5IBswCCB4aJa55hXVAicUWipXGuUuOq6de6PGejpd4cUqJcNurkpU1TL
    BeoVGqatHnJU+ltVxC4K/OGyJr2wTQngN6+JapszHhdNogKtTskVueVaZUpWaiegzFIi9XHNfLHNVK9A
    NPlaBSoNBpRZQqRcNZK0Z4pGK0QzxHiJAE5bTKQym3QkS5NskWYrV+VtwBVZIozTIlXHFmgyT0poz2iW
    b5kGc9Bdk4kiFPlafN4SxPjpvrANIwUeJay/Bi+J10K3HDfZmNt7WZMsz6uRi3lqRHjHJfeJ3zjnVFsg
    CbBag2ZFErFdMWEJzlvtzvTyrlo1NpsqGb301l2aPH9aTtgkjQa6c73l+NxVgToXVGsU+EurVMLyVOmm
    sxKkSTfLVOM9YKsjIgx1w/dWmSBJ1/RzzetEetIWJzT7x5u6Yr0qie31tzir84aoM1+7hguM0jkJvnVY
    Nx0ot1bnfKhWqg6tdkpnZGmSIQ5pAmnCks2y3UbtKXBAnMptAvT0gnw/aXZTpYsdBIrFaZomn1nrGzc1
    OWqDiXrIvnsBMux3yCdm6AfQxUBs/19gkgPak+fjezeLTvgXpZxG6tpfxgUAAAAASUVORK5CYII=
}
image create photo ::img_icon::wiki -data {
    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}
image create photo ::img_icon::commons -data {
    iVBORw0KGgoAAAANSUhEUgAAACQAAAAwCAYAAAB5R9gVAAAABmJLR0QA/wD/AP+gvaeTAAAHNUlEQVRY
    hcWZfXBU1RXAf+ftZkNGCB9OaYJ8CGprRBgQW6c6ILWirTKKTMnYKlRI9r2QGLSMLdR2nLRMdYiOliiw
    722IAjp2CMq0pVUKOrYyo47QjlBNR2w7VTCAQ0CFhmx23+kfb5fsvn35XGzPP8m75+P+3rv3nnvuXShU
    ok4UVAqOk5ZQQd6mXYTwMlfvO8L+nQfOB5BRkLfoXGAMKo9S31T6/wdSuSP9XxldxT8pHAeGPvamXQR8
    CJSlW7oQnYZdc6gQoKF/Ie/rlGW1FAOPFwJTGBAsz2tRmU/UubmAmEMEijpT0xM6X0QfLiQNDA1I9Gd9
    aK8iGl84NJyhTGrTvgZ4oxffg0AYUE6Onk5rZWqw4Qf3hRZvuQDYAvwH0dcCLFwc6wpUHmVMx9zBwsBg
    v5AVmweUE0q9yNlhQjj5Cd7qyoqoN2LXvOLNI9EvFsgvpr0DWOBrPUwodT0ba/85lJCFbh1PBLSOJxV6
    G9O2qG8qDtD3HbIgIADT3gYs6kV7DHBIhmO0VH38vwGqbyqlq3gP8LU+rLqBraRCv2BT9b+/WCCAquYx
    hFJ7gJn9WCYQfQjbauxtwgcDLY9Pp5tumqNtA4aqbyomEXkQldVApB/rvYQji9iw9Gj/QKZ9CcJfULpx
    jdmDggKojk/GcOuAKmBUH5bvUtw1iydXdPUOtGzTCMLJfcBXQJMgn6Mym7j57qCgwEuiJZ13Aw8Alwba
    qGwiblZnN+Uu+6LuJg8GQMKgIxB9nagzFfCGZaAb59YlZ0hENjOuvQKox5vYuSJahWnnrNAeoJqNM1H5
    gc8jDLiIvkrUmUEisp3q5mkDAgKIJFbQXrYaleOoGAhdAVaNLNp2bs71ALnGL8mfU+0UhWahHMBwd6Ay
    H8OdN2AgmIfKGgx9EtGHQBcCrs/mYsZ0WLlAUeda4Dt54VRMjpe2Y2gClYsBEB0Y0D1PDwOu8+IwFlED
    u+YPgB3Qz08zWT3zhe4MCLmXuLmTkZ9ejsox4HDaeU66M2JwmQ0/tqHFhqdsqH46s7IiiTlACaDAO8BI
    6ptKMdwG4HNfX1/m7LC54NUuIHprAPXPAWiOHgCWAVAdr0D0plI+mdAIdQL34jvbJWBtDO6tUekA7kZl
    D83RY1kmnxF14oiuzOlPdD6wS6iOV2C47/lwOjg5emxvBVYMnhW4K0iXeR2FJTXwbKC2ZuN1uMZeX+u/
    cKwpBoZ7ZYDLy7RWpqjZONavsGFBPzAAIrC+Bb4UADOWExe+CXT4NJNZvOUCAyjPD6dednaNv2HaqzNz
    BkChph+YjJR2w/fOPS3bNA7TtlGJ0VqZQvT9PI+SzjIDuCZPoTIDK7YKKAUeIZJ4Hyu2BFSk7109Nwx8
    nUXbIkSd+wgn2wATlTKs2CpURuQ5iM40zi3nXJmNiklPXpqAymKWtZQDwwLsA0WghFGnvoFoffrlQOXC
    dOxJ+W8gkwwM97cBsRpxrEvwktgHQCWONS9dZA2mNP0HcfNPQAUq9wOfAm3p2G/nWRvuLgNoDwg0Pv13
    FSdHT8WxWrN0LwwCyLN1rG7i5jrCycsx3O2+PnrENY4Kpv1N4FWf6iCONT2oBxtGAgeAif3A/NrKntTZ
    YtoTAX/leAbHHGGQiLwBnPEpp1HVnD/GgLV4S/LQRZfeSSZzB8ue9TdVP8iibb1diOUnYngFRA2eWXoW
    2J2nNtwVADQ0GFTHZ2HFVmHauynpPPHY7T883A0zgEZ65lQS2CdgjoZvH5h89Q2MPnkK096NFVuFFbsC
    IA1Zl9efyk7IrKKoswzRTT6Ts7jGZYRSZajswRsqgPdwrKnZhhU3319+5a4jx1tp7cnstesnkAx/mGX2
    V4q75pKILEBls68vF8OdSGz5EW9zHX76efKHYBiiT2Fb+1F5jJ4N8Y/+l2ubVLG21fpWZU7jhrqPgL+n
    n9oRreP08GJUHvH7A88RW34EMrv9Eys7EdbkmYnejulsR7QB0WeADkRzh9e0rwLuQqUxffbvEZXdwDuI
    tuHKDoq6fw+M8/WSIJRqyDz0FGjl7S1AfjqHhcBr2DUrgFsIpf6c3SOwLh1nPCWdD/h8W0iFbqCzpBLB
    IDjLO9nH7twK0btqeR0oCnB8kXCyjg11R7Psvw88l2XTSSpUkXMY9GJuBr4aEPMQyfAsWqrO1Ue5Rb5j
    vQXcF+AIsJBk+AOs2MPUrvfuFjtLfkMoNQZhPyJrCaUu4rNSL9FGnRmY9gt4d0lBMKdxje9mw0BvB0XT
    3g3c2AsYgIvKvvR8+ghYiVcV7sU7tdwCTO7DPwmpH+HU/sqv6P1IE3VqEV1Hpqo8f3IUlduIm/l7WZ9A
    HtS1iG4FppwnmJdwjaW+knYQQJD5PWMpSgNBxdzA5CCwxrdJDxEoI97R+B7gNuB6/Fd5+XICeAmVVuLR
    3w30em9o1zG164eTCs1BZQowFuRWxD2KypuIfoxrtHFq1FtDuYX9LxB8Y0fXZ8eOAAAAAElFTkSuQmCC}
image create photo ::img_icon::timer -data {
    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
    rkJggg==}
image create photo ::img_icon::about -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAD7klE
    QVRogcVaS0iVQRQeoYweEBS9g7Is22toq7itrCiKIB/RShKp1EX02GlFklCpy8KUHmC21RLXLiqjB70I
    sk3bULAMsvf5vDNxPf/57+/8M/+9H3xwmcd3zvmZx5mZq5QfrCbWEruIw8QPxAniD80JXTas29ToPnnF
    cmIT8Snxb0yOEhu1Vs6wnthJ/ObgOOcUsYO4LknH5xObiV89Os6Jj9JKXODb+RLiywjjk8QBYguxmpgi
    lmqmdBnqBolfIrReELf6cv6QCv/qmKB9xEriPAtNtN1D7Cf+DNFGkAddnW8g/hLEfxOvEze4GiAUEW9q
    TW4HtuvjCjcIguBrYpmTyzLKiW9DbFoHgWEjffke4kI//opYTLwt2IUvB+YqUqzSE5KLXLZwpI04xthm
    0f+sYB/zcFtUx0IlrzbnLYwD3YJGt6XGJUHjuUov56E4J3TqsTQM+AiggHhH0Dkd1gG74BRr/ErFG/M+
    AgAwJ94xHQylNVLjTtYQy1p5DKOArwCA7Sq4xF7ljZBM8dzmRkyDQAXxKGOFg14v8w0jZVYC2MQaYIfd
    6GDQNzap4I59IrMBT4n7cuzgXHBfzfbxianAhPjDKitjGllKXBHCJTE1DfYxH+HzKlTUsApsYjaJWSZG
    mJaPSWyA9Z8nlVWo6GKFAw5GkgwAeMg0cQiaOadmFrY4GEg6gAtMEwGpj6yw2sFA0gEcYZq4KFDjrHCn
    g4GkA9jFND+jcJoVljoYWEvcrIL7iq8AypjmdxT6DMCgSuUwAJ9DyCCpAFJKGEJjrNBlEhskFUAt05yZ
    xD6XUYOkAhCXUb6RDXowlFQA4kbmM5UwSCIAKZU4jAokRDyZ2+1oLIkA9jK9/8kcMMoq7zkaSyKAfqb3
    KLOykVXiQFPkYMx3ANKB5nhmAxzP+IE+jsF24gOVvv7gAXzSde0xdHuYVuBICXSwRjhI255js+VChiOW
    mtKh/orUULpWeUNclMcApGsV3FqHPk+dEQzeylMAuNi6K/Q/la0T1lpp/F7MQwDS1eIzFXG1CGS73C2I
    6Fun0sFmY12EBmy0CvaxiZVEOW+AlxHpeh3DyWZO2AJjXho28GW/rVi9IATiESLulWM27FDBCWt23GNx
    RRFE2BMT9gmXzc4Am1SvCn9iiu28AV5Gwl4VsWMj7cCDnU0CiImI3CbbIx/mofWwCcMWJa9OfH3GTovH
    EGS4OICbZ1b8xmEE+TxS4qi3Zqw2xb6cN8AXblbRb7wuNA/dhb6dzwTuUq+p4K7tQmjhzj+nfwBBMnWS
    +FgFzxNzIfogJcY1+bJcOi5hpUqn0EgIh4jvVfq2Y1pzXJcN6TZVuo8z/gEnGuGhzElZHQAAAABJRU5E
    rkJggg==}
image create photo ::img_icon::magic -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAB+klE
    QVRoge2Zz0oDMRDGYwVvPoOCvoQg0oN3fQqtgoLtK6iP4MX138lHEOvBk1TBg2ftK9iDerB4qDOQwBKS
    bGYzyVbMBx+F7Gzym+zMbtsVIisrK4tBM+Bt8IP0lhyLqk3wCNwHzwXM0wIX4InmQh6LptvSYis157DB
    J0nivrRQu8b5JvjCMsaWxCJ4XfqltEhPjq0Kv3Kywbccx4J7og3+EfbLrdwPgHfFdEIT2PeAR78Hwtti
    B6EJzINPwXfSo9Lkz3LsBrzBAB8lAV2UJg6FZykhXb4JcMCzNLEutQg29gIBhlL36DNLbLCwJ/bAa5bj
    1IdUUvgq4eU+EXZ4HdAUfy4agq/aedOV0OMbg/fdeZcvRIaniwP+GjybGhxFrXmTr4R555fBXfk5tfCX
    FnjUUMa8xoBPUTbl2D8HHy2BlA3LngBHzdtuldioQ885hqJGY8eER/WIc3WnCR6FO/rmORfelZZ84Tlq
    vu53m+AeaBI+OIGm4YMSQPjQmq+CPwZ/gY8cMaonyE/i3cjwqLGM/XbEYGMfCELDKj1FhhfaOex69ITV
    XfUbFstmbDhvIsdd5UTSTgR41GfFHB9cCVCb2PffA9xh1xU45EpAJUH5Z4GqqD2gFPMFhM9diEWxXgFh
    OWFPsJaNTVhO2NgD6Y5I8BIuKyvrH+gXA8Ze5lneCigAAAAASUVORK5CYII=}
image create photo ::img_icon::desc -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAACgklE
    QVRoge2ZT0gVURTGDy7KAstVJYmKiC56BRKJuPAfJii6EYLeRixq0SoF4YXgAzfZOuHhxkWpiIRS4ara
    2UYQDHITgRBJtXYRRPTnO9wzPJF5b+beuddneT/4LR4z95zzzZu5c+8ZIi8vr2OhBnAHZCwxBnrBSdeF
    V4Hn4Df444BdcNNV8RfBJ0n0ATwAg6DHAvxvzoNfEn/UhYGXEnwZlLtIAHWBH+AnuGQzcA2p2+YLqLAZ
    OERZUhfqsc2ggxJ03mbQAroiudZtBk1L0FyMc1PgIXgBXhvwVnLtye9X4Cm4BU65NMBT4Cy5m6GYz6DD
    lYElOecruEvqXVFmkuyA+JlrI3X78sX5Dlp0g0QZ6KN88ReMyoynjOTZ0h0YZWBRjg8blxZP/I9uS66U
    zsAoAxtyvDFJdTE1J7mGdAZFGdiS43VJKoupnORK6wzSNcDT3T0yX9yNk3p5lszANcqva0yZKKUB1jlQ
    b0htkVoOzYAreQNhijLAt8RVQypLbeA0qfW96cP8ptQGWO3ghiEHX47+GQiTN6ChQzHA28I9Mntop4+C
    gbNgCjwyIGrHZWRgSAbNxTTgUkYGgk7BewrfJh55A6x3MjATcuyfMNBKakPNgxdAM+XbHHEM8CpzjfTb
    LOO2DLA6STVgC80gxQw0kWpWbWqStWmAxVd9BDwh1XTiqxRMmcUM2FJiA2Fal6CXbQYtoKADMmAz6IwE
    nbQZNERnwDdSDa5qm4G5R8NLZm6Nd9sMvE/c0n9G6kKtukgwJsF5M8/NWP7SYuPjRz+4Dz5K/B1y2P3j
    oovNUkng22YFnHdVfKAT4Dqpz0TcZjdZD+2Hp9HbpN4jXl5e/7v+AhpfkmV6qpT6AAAAAElFTkSuQmCC}
image create photo ::img_icon::logs -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAADYklE
    QVRoge2YS2gUQRCGK4migh58QHzEB+JFgl48BQ+K+BZFjbnpUYl4EXPYgwEHRRADioiimPWBHkS8Koh4
    EOJb2YMBQYMIKgt6CBqfAaNVdA3WND0z3TszO3uYHz7Y7FRX/bWZ6e5pgEKFGkZ/BUliclPRQN6S5u4h
    VeQXU+XvGraBDgias6EjF6eaJiMXkTFwb2CMx06pu2vWXGRQM/UN6Ue2I/OQiQx97uRr37Uxg3y9rmpF
    hoSJP8hpZKrF2GnIGR7jj3+LzMrEqUHjkAFR/CuyvoY8G5ARkec+0pySx0iVRNGfkOxhXA5qlvLz7Uvs
    LkYzQP3ifsHdKeTshuB/szVJss3ICWQdMslw/aAo9ghpSlKMRbfNE5HXM8TQbLcJOQlqgghVGYK3x11Q
    t8wyNvtKXN+WgnlfOyD4QLdwzRJ7kLfZ9ahEryE4xUk+is80g/RygTToheCsNGKo7/MZIh72FchR5JmW
    MG9o0asgx5E1oP5DsZqOdCHnkXc5mKb90w1kDzLHxnCc+kRyWgeOxTCQIL4vDcO6PFHAa4B4Z2VtyDXe
    WVkbco13VtaGXOOdlbUh13gntUFwlc7CkIwvc01nzUZWg5p7T4Faxj+JxPVqwOcL8hzUekDXaV1qh5CV
    eLEhQRj1aiCMdlOC8choyIBhUCuj//fhDBo4IuKrXNPkZZS9GvUU1NaW7sEeZC38vxf3iiRnM2jgnIjv
    5u/a2EMPeyJ/jy1yGbVRFLhtEe+BWwN3RHwtr6ixWiQK0HZ3Qky8B/YN0MmFPK1YULvNaL0URTpjYj2w
    b6BLxFYSOYyRfKV8AdGvlB7YNUA5KiK2lIJPo+gl4pooROyPiPfAroEDWs4rkMHxSgsn1qc0elddGTLG
    g/gGVkHwfdeHjhxTa4IS6ebl0Qo9fFsM4zyIbmAr8iMkJ3EpjSYowWUtMZ1vzkc+iO/onfUCMtOiATpC
    lPsq4j2o89H+NJswmS+LhDStDmnX6Xa4iuwEtdjJhW8XqGfotzbmDbJQ1NSbq6mJOPO+6KD2phbnAm3S
    9APhxE008YA481J0kvfQwfgDUFuEMIU1YX0S6ImBLjPCUlCHVLTVoNtrmKHPt0CtI0ssczVzbZftSEC0
    oKQyEyQQ/eK0yTuUJEHeagQPhQo1rP4BMNo2RgqsgVsAAAAASUVORK5CYII=}
image create photo ::img_icon::file -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAACQklE
    QVRoge2ZwU4TURSGDyFxhzsMgW3jC7hiQSJukLQLFqi8Q1lTd5hICg/AK+gCAi9g7ILSnSamXfAADURJ
    sNGyUDQp59L/OrfNtDNh/rmDYU7ypzNzz/3+c3tnbmemInn83/FI9UnVI+lSVVOVfBXfIhY/rC1fxbew
    z4hZVUX1G+xUZmJU8Q1VneRRAf8jifcvplVNwE9UM06bnXpGzID1k8S7iXHFi3AHQOdFFU83ZPLiFE81
    ZPPsOh+12tzZAVjQuOIXkHPKMBzypYIazn6YthmGIb40UF3CCzff/I7qAcMwxPdugLLyvbcDmJT+KXeE
    bV++NNCa0/eVR18a6LPT94tqwpMvBbSEPmeQ2X7uwTcxaEr1RHWMPhuQ2W6gbSoF30Sgdenft7edXKOO
    6iHUGWpro085gW/siAKdOzm/pH/jty+Dp8wyjjWRY/O/JfCNHVGgogSPgNUYvCpyTZ9xj4xer4EV1RXy
    NsfkvUHOX4leWr1fxC9Uf5C7GtK+KkHxL4m+VNA75IZdnGW0vU/Blwayy+cz7M9DgmM95LB9aaAL5D5V
    7Tl9P0jw4/Y9BV8KyL4Ksee5+fwBucd6Mvq5+ja+NNCik2tWpF3pvxCYxvaV075I9KWBCqqvqgPV45B2
    c+wQOQWirz9QVr75ALL2zQeQtW8+gKx98wFk7dsFaJYBixlzEtxLJY4aYBUGLGa8hiflT76SBM+wZhBp
    zsTw36xFFnhLBl+L+NBbVvE2zEyYKbXXRBrqwoP2zeeRdlwDjN2HXvNsZT0AAAAASUVORK5CYII=}
image create photo ::img_icon::next -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAChElE
    QVRoge1ZyTIEQRBNDi4YJ0JwtFwtZxwsJ/5nHCwHIvgEyycIfIEJAidOBOYHHKwRjIsTmSZLj4mu7Kru
    7OkR0S/iHaaW9zKrq6tyZgBy/G/0IC+RX0r8QJaQC40K/lox+HquNyr4a/6sgT5kEfnJ2qk8CVvw58hT
    JY8i6x8p6f2iG3nF4nfI3po+8+g10Mta70p6P5CCB9BNQF0vKnh1Q009l+BVDbX1zDkfddo0bQJGSAp+
    ksfcaxjW+aoKndd8DuOGhmGIr5rQGYQHTiu/iWzTMAzxbQ6hrHzzBLL29RWaQ+4iy1Atj4l0f+wgZ1P0
    TSw0jDyB8Je8lsfIIUVfFaEp5CuPe0AuIUeR7cwxbnvkMS9QvTuS+johSohW3gS/h+wUxhaQ+xAkMZjA
    1xlRQmbbUPAtDnqtECRRSuDrDEloDoJtY1t5uvwu4G8p0gXBdpqJ4esFSWiX+5aE+bZicIXbt2P4ekES
    KnPfiDDf9hV0DIIS3dfXC5LQO/eZ7RNV7BEveGwnyF8bM0nAVuyFJVCAJkjAbKFRYb5tC41z220MXy9I
    QjvctyzMt73Eq9y+FcPXC5LQLPfRkViwjKHfisKO0SeeOx3D1wtRQsfcT5dTq4MejTnkOdIPVw1LgAqz
    FwiS6BLGUt8Bj31GDiTwdYaLEBVmJgnaGnRJ0UvaAdUTapzbzLah4CcUfJ3gKkSFWalmvI20baSV9/VV
    F6LahsoDOh4rzBuonja2F1bDN32hrHzzBLL2zRPI2vffJ1BhoT4NMUf0s+ebhpi5nIoaYo5YhOhayRkL
    LEZ/fVISaT6J+r9Z57WE1yG6RNDmmlbwBvQk6JGadyINVthDbeVzpI1vFBGteQpptGQAAAAASUVORK5C
    YII=}
# https://www.iconfinder.com/search?q=date&price=free&style=solid
image create photo ::img_icon::date -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAACtElE
    QVRoge2Yz2vUQBTHe1FP4kUQq4IHoVBtsyGKmklI3+wivYoI/SP0KOo/ogfxD7AIHtQqHoRaCvUoKL1o
    zwW1thWh+PvNZhJnk5lmMptNppIHj4Vh5r3vZ/bNZGbGxlrbY+YQutwJYMnWeIXWCegf5rbGqz1hCyDa
    6fDSCazJhxhwOwms8mRMXMO799VxjXjbHQKPpnyYUIrHxfS5bMIqxJeMt8G05gD4zI8i4SjizecAdMom
    cSeg76sEKBvPCWBLBqCXkMBjL4oOVwZgGM8YwPV740bgFcczBpiKouPJmHjhDwdgGs8YAOv1qXOBHut7
    AAvDApjGM18DlngL0LT//wC5Dg1bC9C0tQBNWwsgs8wNTnljwiPCC/l2qP8aUTnALje4gRvTmfP0iHo/
    h1eNAaQ3OEKfsIMYO1UKh7H0xjQdAmVt2H9RV2wtALxspMdh8cbkBnCdA9yxDACWsiWQlguhX5M2hLnL
    Aa5ZBSAzFHk5BoDXQtsih/qC7Tt4/l/F39uTk1f3WwXged4+HPe2P9sh3BAAPioW8MtTs7MHrAFwCNzj
    s7824fsH07iErsRg3Z7X6x2KFzV84H1vWQGAZXGTL95vnYvdc4X9SXcm7k9XGwdww5krOKO/cMxvN6Bz
    ebH553Nebriw4adODlZqIwFw/ehsf9YzdZ+Jq95uCWyKfXXfZvGf+z40gBNFJ3Fm13n/+6p+7HjBy2uB
    QcQi4Rkf92AQSvNtltDnwwMQeKNO8q9k2NkI2zbyswifxH9F920W875j35sKAPj+LgcY+MDxkplnX2jm
    bOZF8Tx/4dusUrwJQNVWKB53LC8Mj2oHqFG7NH8p8bIANelW5i8lXhagBs2pyfb5wprPms4iqtNLie8D
    8P3aBi8tnplqv94T4hMT9+v6hdMf7AtrLL61huwv+emal5xgijcAAAAASUVORK5CYII=}
# image create photo ::img_icon::calendar -data {
#     iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAACxElE
#     QVRoge2ZPWtUQRSGD2i5BOJHSGdl4SeIpWCsBQvXIminxlgIKlgFMZV/wHJRG1FLsU1+gAS/CKjYKSEq
#     aKGCiKi48T3ZM9nJ7MydvXvm7h2JB55w956Zzfveufec2V2i/uM8+ADeg3M15KOxDUyCaYsJye0Df8Ar
#     gY/3WnOrzE84mljjVlf8KfAVrDgsS/6MvD4k8PFpa36V+WWPLtZ60kw+Io5fgCY4aDEmY6Zlojm/Iudo
#     CPkxR9MJ8FI0r94hT8FH6txCoajTgC+2g0/gMb/4Be4WDOao8xYKxT3Rvjq4FRnse8j2DDHvi5Zop2fg
#     QmQwBy8pl7h3YKqGvBtrBv7VWDPg1tnc2e0a+EG9dTZnHroG+M8DWl9rc6bhM2CqUCMDgSoDcwVLlwtz
#     RQa4Ky9R/Q9qiCXRWGjADMgxbH3/DdQRAxsYBzdkXEuOx0vmZ8GIMFtyvtrAFPVWg7Ml8odBGzwS2nKu
#     3/lqAyn28zOWuJmS75/MwHUhZCCU5+ZjrrxZiUaJ+WoDTepd4maJ/FERflFoy7l+56sNcPAHDLPEvg8b
#     sbz70JadrzaQQ2xcAyn6gKZPqA1o+4C2T6gNDON7n6I+kczAoH1A2yfUBrR9QNsn1AY4tH1A2yfUBnKI
#     jWugn/18iv1+ZQZidTrVfr8yAxyxOp1iv8+xCeyyxh4Am7UGYnU61X5/B3hNvat1TWsgVqdT7ffvgN/g
#     KnW/C+Lbzzwvzwc1QBSv0yn2+09EpC8uUefC3JfXWZbR0P+/TN1bc0TOeQ0sgMVqNRaGz4C58rZ4Dq+B
#     W+An2F+pzHC4BkLiObwGdoJv1DGxaL3hsPhuGZgsEL/OwBfqfmVtTPBKLNRggLkiOo5R5+dfn3iOefCZ
#     D26L0+OBgTkGl2DWzBeatoC3coJdtTJnXrS+AaPG0ai44dvJbTi5wRpvGvF/AY8KPSEcOtYhAAAAAElF
#     TkSuQmCC}
# image create photo ::img_icon::larrow -data {
#     iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA8ElE
#     QVRoge2XOw7CMBAFXdGQa1JwglSIlFTcmI+3sBRFiW28K+17aEd6NTMkSpyUgiAI/plr3tlbYpRL3itv
#     8hYZoch/EmHAWp4uYCtPFbAnTxNwJE8RUJOHD2jJQwf0yMMGyBv2ndryslvebLCTlXzvP289kyvpJW8S
#     4CmvDvCWVwUgyA8HoMgPBSDJDwXcAaTVt9AMIK4KQIpQPUYRItQvMu8Ik6OEZ4TZqdYrwvRYvvzww8+8
#     h8HMjtOF3isB+UFT6ImADhBaEfABQi2CIkA4iqAJEPYiqAKEbQRdgLCOoAwQSgRtgCAR1AFBEAR1vvoZ
#     Tv5tVBu8AAAAAElFTkSuQmCC}
# image create photo ::img_icon::rarrow -data {
#     iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA5UlE
#     QVRoge3WsQrCQBCE4dU3FgRbsbKytPA1raz0BgmEkFzO29Xdkf1h+/kSCBHJsiz79/beA7Tdy529R2gC
#     4CnEiAFAixgDKBFTAB1iDkCFWALQIGoACsQa4GuIXbmDwT0aALijNaDlyVmf6ZvwAJgivABmCE+ACcIb
#     oEZEAKgQUQDdiEiAa7kNK+BWbvvp+CiA7vERAKrx3gD1eE+AyXgvgNl4dJL391d7rb/TXZ/KX9TyJk2f
#     vHVrgNDjUQ0QfjxaAlCMR3MAmvFoCqAaj8YAuvFoAFCORwDQjkcXIR6fZVlW7wW701Cd5xuzfwAAAABJ
#     RU5ErkJggg==}
image create photo ::img_icon::sparkle -data {
    iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAQAAABKfvVzAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1
    MAAA6mAAADqYAAAXcJy6UTwAAAACYktHRAD/h4/MvwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAAd0SU1F
    B+cLFgcKFs5D85YAAAGESURBVDjLldK9a5NRGAXw35s3VdMGYlspAT+IWOtSbUFpkU6ODg66OYpa3HVX
    xH/A1b+jinRwsp1KBQfFToKfUFQqJH2NaV4H83Vfk0jPXe597j2Xc87z0B+RuP9FbgAhb2x/hBHj/yNE
    Qb1o+h+RGcJYIOKIuZ4vckptT11C4phK53TGomJrXzArr5ElNHxy2RUHwIIlR8EJywq+9Xc0bdUTF8zY
    0HRX2Q0v3RsYDW5KfLHpl9RHr9WtKRuCSWvSnvXb7WF9yJtSDSp1eaUw3UhsxKRTZi1YUskMxU+vrNv0
    zgc1jVhOwYQpx512zkmjGZGxpqrvEg1pO9w2Si5ZDzzU3FdpRd1S3YsdGxkPOVveD0vpqqqqzxpSO75K
    PQtNhyh76rlrLnor9cich964Nej5QcvutMb6sW3ziJz3wNl+z3NmzHcm9LoVh1v7CYtdWd3Mi5Iee7FD
    XkjBrm2j6pohYU8taGhsq+dul7/0LiENBKYSPzKVjKQQkT2JfSDKtLSDPzcsZiWGKxD9AAAAJXRFWHRk
    YXRlOmNyZWF0ZQAyMDIzLTExLTIyVDA3OjA2OjM1KzAwOjAweCebUwAAACV0RVh0ZGF0ZTptb2RpZnkA
    MjAyMy0xMS0yMlQwNzowNTo0OSswMDowMC8o+4EAAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjMtMTEt
    MjJUMDc6MTA6MjIrMDA6MDCb8pOnAAAAAElFTkSuQmCC}
[image create photo ::img_icon::sparkle_wide -width 40 -height 24] copy ::img_icon::sparkle
image create photo ::img_icon::play -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAk0lE
    QVQ4jWNgQAA1IA4C4lACOAiqFgU0A/E/IP5PJAapbUK2GSSQDMTM6CZjASA1KVA9qgxQJ/0nUjOyIf+h
    esH++k+CZhj4D9WL0wBHIPaixACQOMifM4GYi1wDYKF+BYh1B8QAmBc4yfECxYFICMANoDghwZJyKpGG
    gNSkMSAlZRBoYiA9MzWgm6zKQHx2htsMAAS8TX9j6dH4AAAAAElFTkSuQmCC}
image create photo ::img_icon::favorites -data {
    iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAACXBIWXMAAAsTAAALEwEAmpwYAAACYklE
    QVRoge2ZP0hXURTHjyURJhRBlFBZ0tBQEC4t1uBkQQ7SZi0toiEGDdlUNBiCIg5CDS3iVFMElaA0tJTY
    EkSKg0GIEWlBfzRK63t878bz8fu9d9/xvndP4Bc+4CDnfs7P38/fO+cSbWYzuacWdIFRMAW+ga/gLXgM
    LoP9groHQSd4GqnLTIdndYVni3MADINV8CcF/p374LBFXW72LlixqMs8AnVZ5bn7ZcsDovwAbQl128GS
    oC67dNqIV4BewQFxBsGWWN2bjupuTWqg38EhhjuheEX4s6u6feXkz5Pd+z0LveTmLxqFHVvi8rvBF8cH
    5cki2BVt4JYCqazcMPLV/9mrb/gMdnADzQpkpJzlBoYUiEjhf6s0oUBEygtu4L0CESnvuAHJV7sW+NFl
    7dPsW0TKJ25gSoGIlDfcwKgCESk8j9A1BSJSrnIDJxSISDlGYV4qkMnKJAWP6ms5p0AoK2coEu7kmQIp
    W8aoRPaCOQVyaXwANaUa4Jwm2TBfFOx2qpy8CT9e/1IgG+c3BWOvVS6S/d6mCNjlgq28SYcCccOVrPIm
    1xXId0vlTW57lO/ZqLzJgAf5IVfyHP6iu1eg/AitX006Ce8kHxQg/xBUupY32Qae5Cg/DrbnJW9SBZ7n
    IM8bhuq85U12glcO5V9TsJ8tNHsouGbaqPwM2Few+7/wddFsimASvJM6VLR0PEfAPGWX/wiOevAtmeNg
    gezleRte78U0IScpuH5Nk/8OGjw5pqaRkleVP0GTNzvLlBuIMg0kvtNK6wcivpi75NVIEL7UNg2IBxLf
    6SYHA0lS/gKFxYVgCgts6QAAAABJRU5ErkJggg==}
image create photo ::img::start -data {
    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}
image create bitmap ::bitmap::arrow(0) -data {
    #define arrowUp_width 11
    #define arrowUp_height 4
    static char arrowUp_bits = {
        0x08, 0x00, 0x1c, 0x00, 0x3e, 0x00, 0x7f, 0x00
    }
}
image create bitmap ::bitmap::arrow(1) -data {
    #define arrowDown_width 11
    #define arrowDown_height 4
    static char arrowDown_bits = {
        0x7f, 0x00, 0x3e, 0x00, 0x1c, 0x00, 0x08, 0x00
    }
}
image create bitmap ::bitmap::arrowBlank -data {
    #define arrowBlank_width 11
    #define arrowBlank_height 4
    static char arrowBlank_bits = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    }
}

proc AboutDialog {} {
    global S

    set top .about
    set body [DialogTemplate About $top "by Keith Vetter"]
    wm title $top "About $S(title)"
    wm resizable [winfo toplevel $body] 1 1
    wm transient $top .

    text $body.t -wrap word -font $::text_font -borderwidth 3 -relief ridge -padx .1i
    grid $body.t -row 1 -sticky nsew

    ::ttk::frame $body.buttons
    ::ttk::button $body.buttons.ok -text "OK" -command [list destroy $top]

    grid $body.buttons -row 2 -sticky news
    pack $body.buttons.ok -side left -expand 1 -pady .2i

    $body.t tag config title -font [concat $::text_font -weight bold -size 28]
    $body.t tag config heading1 -font [concat $::text_font -weight bold -size 24]
    $body.t tag config heading2 -font [concat $::text_font -weight bold]
    $body.t tag config keyword -font [concat $::text_font -slant italic]
    $body.t tag config url -foreground blue -underline 1
    $body.t tag bind url <1> {LaunchBrowser https://imagemagick.org/script/download.php}

    $body.t insert end "$S(title) v$S(version)\nby Keith Vetter, $S(creation,date)" title "\n\n"
    $body.t insert end "Jigsaw tiles is a variant of the classic jigsaw puzzle.\n\n"

    $body.t insert end "Jigsaw tiles takes an image, divides it into a set of similar tiles "
    $body.t insert end "(it \"tessalates\" the image) then shuffles the tiles. Your challenge is "
    $body.t insert end "to unscramble the image by swapping tiles.\n\n"

    $body.t insert end "ImageMagick" heading1 "\n"

    $body.t insert end "$S(title) is designed to use a third party utility called "
    $body.t insert end "ImageMagick to resize and slice up images (Tcl/Tk has only "
    $body.t insert end "limited image capabilities). "
    $body.t insert end "$S(title) will work just fine without ImageMagick but will "
    $body.t insert end "be both faster and more capable if ImageMagick is installed.\n\n"
    if {$::tcl_platform(os) eq "Darwin"} {
        $body.t insert end "ImageMagick can be installed with "
        $body.t insert end "brew install imagemagick" keyword ". For more information see "
        $body.t insert end "https://imagemagick.org/script/download.php" url ".\n\n"
    } else {
        $body.t insert end "ImageMagick can be downloaded from "
        $body.t insert end "https://imagemagick.org/script/download.php" url ".\n\n"
    }


    $body.t insert end "Picture to Scramble" heading1 "\n"

    $body.t insert end "$S(title) is set up to automatically download interesting "
    $body.t insert end "pictures from the Wikipedia or Wiki Commons archive of "
    $body.t insert end "Picture of the Day images. Alternatively, you "
    $body.t insert end "select any file off your local disk.\n\n"

    $body.t insert end "Picture of the Day\n" heading2
    $body.t insert end "\u2022 Click " _ "Wikipedia" keyword " to download a random Wikipedia PotD\n"
    $body.t insert end "\u2022 Click " _ "Commons" keyword " to download a random Wiki Commons PotD\n"

    $body.t insert end "Local file\n" heading2
    $body.t insert end "\u2022 Click " _ "Open" keyword " to select a local image file\n"
    $body.t insert end "\u2022 Click " _ "Next" keyword " to select the next image file "
    $body.t insert end "in last directory\n\n"

    $body.t insert end "Tiling" heading1 "\n"
    $body.t insert end "With out-of-the-box Tcl/Tk, four different types of "
    $body.t insert end "tile shapes are available. "
    $body.t insert end "If ImageMagick is installed, then fancier tile "
    $body.t insert end "shapes are available.\n"
    set all_themes [lsort -unique [concat $S(themes) $S(themes.cannot)]]
    foreach theme $all_themes {
        if {$theme ni {"Rectangle" "Square" "Ell" "Ess" "Cross"}} {
            set theme "$theme (ImageMagick required)"
        }
        $body.t insert end "\u2022 $theme\n"
    }

    $body.t insert end "\n"
    $body.t insert end "Expert Puzzle Mode" heading1 "\n"
    $body.t insert end "The Expert button turns this into a harder puzzle. It choses "
    $body.t insert end "three random tiles and pixelates them obscuring their content. "
    $body.t insert end "These pixelated tiles behave as normal tiles, and when they're "
    $body.t insert end "placed in their proper location, they will reveal themselves.\n\n"

    $body.t insert end "Magic" heading1 "\n"
    $body.t insert end "The Magic dialog provides access to some hidden functionality. "
    $body.t insert end "This includes showing the grid used to carve up the image, "
    $body.t insert end "or solving a random tile, random row or the entire puzzle. "
    $body.t insert end "You difficulty slider controls how many tiles the image is "
    $body.t insert end "divided into. "
    $body.t insert end "If the image was downloaded from Wikipedia or Commons, then "
    $body.t insert end "you can copy to the clipboard different URL's of that image."
    $body.t insert end "Other Magic features let you tweak some of the GUI parameters, "
    $body.t insert end "such as, replacing black & white tile shading with "
    $body.t insert end "more colorful ones.\n"

    set symbol_g \u2611
    set symbol_b \u2612
    set symbol_2 \u2731
    set symbol_S \u22ee
    set symbol_done "\u2764\ufe0f"

    $body.t insert end "\n"
    $body.t insert end "Tallymarks" heading1 "\n"
    $body.t insert end "As you place tiles, a progress bar will be displayed "
    $body.t insert end "on the top left of the image showing your progress. Key:\n"
    $body.t insert end "\u2022 $symbol_g\tcorrectly placed tile\n" tabby
    $body.t insert end "\u2022 $symbol_2\tboth tiles placed correctly\n" tabby
    $body.t insert end "\u2022 $symbol_b\tincorrectly placed tile\n" tabby
    $body.t insert end "\u2022 $symbol_S\thint given\n" tabby
    $body.t insert end "\u2022 $symbol_done\tremaining pieces are forced\n" tabby

    set tabs [font measure [$body.t cget -font] "\u2022 $symbol_done "]
    $body.t tag config tabby -tabs $tabs

    $body.t insert end "\n"
    $body.t insert end "Shortcuts" heading1 "\n"
    $body.t insert end "\u2022 Right-click on a tessalation type to make that "
    $body.t insert end "the only tessalation used in scrambling\n"
    $body.t insert end "\u2022 Right-click on the Scramble button to enable all tessalations\n"
    $body.t insert end "\u2022 Right-click on \"Favorites\" to pick one at random"

    $body.t config -state disabled
}

proc Logger {msg {tag ""}} {
    # Add msg to the log dialog
    global S
    if {$msg ne ""} {
        set msg [string map {\n " "} $msg]
        $S(logger) insert end "\u2022 [string trim $msg]\n" $tag
    } else {
        $S(logger) insert end [string repeat "\u2501" 30]
        $S(logger) insert end "\n"
        set when [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %A"]
        $S(logger) insert end "\u2022 ${when}\n"
    }
    $S(logger) see end

    # Keep log from growing too big
    set maxSize 100000
    set keepSize 10000

    set index [$S(logger) index end]
    if {$index > $maxSize} {
        set text "\[deleted\]\n[string repeat \u2501 30]\n"
        $S(logger) replace 2.0 [expr {$index - $keepSize}] $text
    }
    update
}

proc AtExit {args} {
    # Tasks to be done before exiting
    global S
    SaveInifile
    catch {file delete -force -- $S(tempdir)}
}
namespace eval ::Victory {
    variable VICT
    set VICT(bursts) 20
    set VICT(delay) 100
    set VICT(steps) 20
    set VICT(grow) 10
    set VICT(colors) [list red yellow white blue green magenta]
    set VICT(ray,delay) 5
}

proc ::Victory::Victory {} {
    # Display victory sequence
    global S STATS

    ::Victory::Stop
    destroy .status
    set ::Victory::VICT(stop) 0

    incr STATS(total,Solved)
    .c create image 0 0 -image $S(img) -anchor nw
    .c raise stars
    .c raise tallymarks

    ::Victory::Message
    ::Victory::ManyStarBursts
    ::Victory::Rays
}

proc ::Victory::Message {} {
    # Display a big banner showing success
    global S STATS

    set text " Perfect! "
    if {$STATS(bad) > 0 || "S" in $STATS(playback)} {
        set text " Solved! "
    }
    set font [FitFont $text $S(iwidth)]

    .c create text [expr {$S(iwidth) / 2}] [expr {$S(iheight) / 2}] -text $text -fill black \
        -anchor c -font $font -tag {victory vmsg}
    .c create text [expr {$S(iwidth) / 2}] [expr {$S(iheight) / 2}] -text $text -fill red \
        -anchor c -font $font -tag {victory vmsg v2}
    .c move v2 6 9

    after 3000 {.c delete victory}
    after 5000 { array unset S victory,aid,* }

}
proc ::Victory::Stop {} {
    # Force victory sequence to stop
    variable VICT

    global S
    set VICT(stop) 1
    .c delete victory
    foreach {_ aid} [array get VICT aid,*] {
        after cancel $aid
    }
}
proc ::Victory::ManyStarBursts {} {
    # Spawn a bunch of star bursts
    global S
    variable VICT

    .c create line -1000 -1000 -1000 -1000 -tag {starburst starburst_first}
    set w [expr {max($S(iwidth), [winfo width .c])}]
    set h [expr {max($S(iheight), [winfo height .c])}]

    foreach id [range 1 $VICT(bursts)+1] {
        set x [expr {int(rand() * $w)}]
        set y [expr {int(rand() * $h)}]
        set VICT(aid,$id) [after 10 [list ::Victory::StarBurst $id 0 $x $y]]
    }
}
proc ::Victory::StarBurst {id step x y} {
    # Fun animation part of the victory sequence
    global S
    variable VICT

    set tag "victory_$id"
    if {$::Victory::VICT(stop)} {
        .c delete $tag
        return
    }

    if {$step == $VICT(steps)} {
        .c delete $tag
        unset VICT(aid,$id)
        if {[array names VICT aid,*] eq {}} {
            # Done with all starbursts, kill off rays also
            .c delete rays
        }
        return
    }

    set color [lpick $VICT(colors)]
    .c create oval $x $y $x $y -tag [list victory starburst $tag] -fill $color -outline $color

    foreach item [.c find withtag $tag] {
        .c coords $item [GrowBox {*}[.c coords $item] $VICT(grow)]
    }
    .c delete starburst_first

    .c raise vmsg
    incr step
    set aid [after $VICT(delay) [list ::Victory::StarBurst $id $step $x $y]]
    set VICT(aid,$id) $aid
}

proc ::Victory::Rays {{thickness 40} {lag 15}} {
    set x1 [image width $::S(img)]
    set y1 [image height $::S(img)]
    if {True || $x1 >= $y1} {
        ::Victory::RaysXY sw $thickness $lag
        ::Victory::RaysXY se $thickness $lag
    } else {
        ::Victory::RaysXY sw $thickness $lag
        ::Victory::RaysXY nw $thickness $lag
    }
}

proc ::Victory::RaysXY {corner thickness lag} {
    global S

    set x0 0
    set y0 0
    set x1 [expr {max($S(iwidth), [winfo width .c])}]
    set y1 [expr {max($S(iheight), [winfo height .c])}]

    set coords {}
    if {$corner eq "sw"} {
        foreach y [lreverse [range 0 $y1+$thickness $thickness]] {
            set yy [expr {$y + $thickness}]
            set xy [list $x0 $y1 $x1 $yy $x1 $y]
            lappend coords $xy
        }
        foreach x [range $x1-$thickness 0-$thickness -$thickness] {
            set xx [expr {$x + $thickness}]
            set xy [list $x0 $y1 $x $y0 $xx $y0]
            lappend coords $xy
        }
    } elseif {$corner eq "se"} {
        foreach y [lreverse [range 0 $y1+$thickness $thickness]] {
            set yy [expr {$y + $thickness}]
            set xy [list $x1 $y1 $x0 $yy $x0 $y]
            lappend coords $xy
        }
        foreach x [range -$thickness $x1+$thickness $thickness] {
            set xx [expr {$x + $thickness}]
            set xy [list $x1 $y1 $x $y0 $xx $y0]
            lappend coords $xy
        }
    } elseif {$corner eq "nw"} {
        foreach y [range 0-$thickness $y1+$thickness $thickness] {
            set yy [expr {$y + $thickness}]
            set xy [list $x0 $y0 $x1 $yy $x1 $y]
            lappend coords $xy
        }
        foreach x [range $x1-$thickness 0-$thickness -$thickness] {
            set xx [expr {$x + $thickness}]
            set xy [list $x0 $y0 $x $y1 $xx $y1]
            lappend coords $xy
        }
    } elseif {$corner eq "ne"} {
        foreach y [range 0-$thickness $y1+$thickness $thickness] {
            set yy [expr {$y + $thickness}]
            set xy [list $x1 $y0 $x0 $yy $x0 $y]
            lappend coords $xy
        }
        foreach x [range -$thickness $x1+$thickness $thickness] {
            set xx [expr {$x + $thickness}]
            set xy [list $x1 $y0 $x $y1 $xx $y1]
            lappend coords $xy
        }
    }
    set coords [concat $coords [lreverse $coords]]
    ::Victory::RayAnimate 0 $corner $coords $lag
}
proc ::Victory::RayAnimate {step tag0 coords lag} {
    variable VICT

    if {$step > 0 && [.c find withtag rays] eq ""} return
    if {$coords eq "" && [.c find withtag $tag0] eq ""} return

    set tag1 ${tag0}_[expr {$step - $lag}]
    .c delete $tag1
    set tag ${tag0}_$step
    incr step
    if {$coords ne ""} {
        set coords [lassign $coords xy]
        set color [lpick $VICT(colors)]
        .c create poly $xy -tag [list $tag0 $tag rays victory] -fill $color
    }
    .c raise starburst
    .c raise vmsg
    after $VICT(ray,delay) [list ::Victory::RayAnimate $step $tag0 $coords $lag]
}
proc FitFont {text space} {
    # Binary search to find font size to best fit text into space
    set size 512
    set delta 256

    while {True} {
        set font [concat [font actual TkDefaultFont] -size $size -weight bold]
        set width [font measure $font $text]

        if {$delta == 1 && $width < $space} break

        if {$width < $space} {
            incr size $delta
        } else {
            incr size -$delta
        }
        set delta [expr {$delta / 2}]
        if {$delta == 0} { set delta 1}
    }
    return [font actual $font]
}

proc GrowBox {x0 y0 x1 y1 dxy} {
    # Expands a rectangle by $dxy
    return [list [expr {$x0 - $dxy}] [expr {$y0 - $dxy}] [expr {$x1 + $dxy}] [expr {$y1 + $dxy}]]
}
proc Explode {who step x0 y0 x1 y1} {
    # Animation "exploding" a tile placed correctly
    set tag "explode_$who"
    if {$step == 3} {
        .c delete $tag
        return
    }
    incr step
    if {$step & 1} {
        set img ::img::puzzle_e_$who
        .c create image $x0 $y0 -tag $tag -image $img -anchor nw
    } else {
        .c delete $tag
    }
    after $::S(explode,delay) [list Explode $who $step $x0 $y0 $x1 $y1]
}
proc range {args} {
    # Extension of python's range command, except:
    # * accepts numbers of form a, a+b or a-b
    # * high argument can be a list and will equal the length of the list

    if {[llength $args] == 1} {
        lassign [concat 0 $args 1] low high step
    } elseif {[llength $args] == 2} {
        lassign [concat $args 1] low high step
    } elseif {[llength $args] == 3} {
        lassign $args low high step
    } else {
        error "Wrong number of arguments to range: '$args'"
    }

    # accepts numbers of form a, a+b, a-b, a+-b, a--b
    if {[regexp {^-?\d+[+-]-?\d+$} $low]} { set low [expr $low] }
    if {[regexp {^-?\d+[+-]-?\d+$} $high]} { set high [expr $high] }
    if {[regexp {^-?\d+[+-]-?\d+$} $step]} { set step [expr $step] }

    # Turn floats into ints
    regsub {^(-?\d+)\.\d+$} $low {\1} low
    regsub {^(-?\d+)\.\d+$} $high {\1} high
    regsub {^(-?\d+)\.\d+$} $step {\1} step

    # high argument can be a list and high will be the length of the list
    if {! [string is integer -strict $high] && [string is list -strict $high]} {
        set high [llength $high]
    }

    foreach var [list low high step] {
        set value [set $var]
        if {! [string is integer -strict $value]} {
            error "TypeError: range function $var argument must be an integer"
        }
    }

    if {$step == 0} {
        error "ValueError: range function step argument must not be zero"
    }

    set result {}
    if {$low > $high && $step < 0} {
        for {set idx $low} {$idx > $high} {incr idx $step} {
            lappend result $idx
        }
    } else {
        for {set idx $low} {$idx < $high} {incr idx $step} {
            lappend result $idx
        }
    }
    return $result
}
proc ScrambleTiles {MOTIF} {
    # Shuffles the tiles and then puts them on the screen
    global S

    set ordering [$MOTIF ShuffleTiles]
    PlaceTiles $MOTIF $ordering
}
proc PlaceTiles {MOTIF ordering} {
    # Tile N gets placed at location ordering[N]
    global G

    unset -nocomplain G
    set G(solved,tiles) {}
    set G(count) [llength $ordering]
    .c delete tiles
    foreach idx [range [llength $ordering]] {
        set where [lindex $ordering $idx]
        set G($idx,isAt) $where
        set G($where,has) $idx

        lassign [$MOTIF Tile2XY $where] x y
        set img ::img::puzzle_a_${idx}
        set tag tile_$idx
        set image_tag tile2_$idx

        .c create image $x $y -anchor c -image $img -tag [list tile $tag $image_tag]
    }
    foreach idx [range [llength [array names G *,isAt]]] {
        if {$G($idx,isAt) == $idx} {
            SolvedTile $idx False
        }
    }
    ::Animate::AllTiles
}
proc Shuffle {llist} {
    # Shuffles a list of elements
    set len [llength $llist]
    set len2 $len

    foreach i [range $len-1] {
        set n [expr {int($i + $len2 * rand())}]
        incr len2 -1

        # Swap elements at i & n
        set temp [lindex $llist $i]
        lset llist $i [lindex $llist $n]
        lset llist $n $temp
    }
    return $llist
}
proc PerfectShuffle {values} {
    # Shuffle with no item in its original location, works by swapping
    # pairs of in-place items and any odd one with a random element

    set shuffled [Shuffle $values]
    set hits [lmap v $values s $shuffled i [range [llength $values]] {
        if {$v ne $s} continue ; return -level 0 $i
    }]

    foreach {idx1 idx2} $hits {
        if {$idx2 eq ""} {
            set idx2 [expr {$idx1 == 0 ? $idx1+1 : $idx1-1}]
        }
        set item1 [lindex $shuffled $idx1]
        set item2 [lindex $shuffled $idx2]
        lset shuffled $idx1 $item2
        lset shuffled $idx2 $item1
    }
    return $shuffled
}
proc ClickDown {x y} {
    # Handles button down event
    global S G

    set S(click,who) None
    if {$S(MOTIF) eq ""} return

    set whence [$S(MOTIF) XY2Tile $x $y]
    if {$whence eq "None"} return
    set who $G($whence,has)
    if {$who in $G(solved,tiles)} return

    set S(click,who) $who

    set tag tile_$who
    set image_tag tile2_$who
    set S(click,xy) [.c coords $image_tag]
    set S(click,last) [list $x $y]
    set img ::img::puzzle_d_${who}
    .c itemconfig $image_tag -image $img
    .c raise $tag
    .c config -cursor fleur

    ::Timer::Start
}
proc ClickMove {x y} {
    # Handles button move event
    global S G

    set who $S(click,who)
    set tag tile_$who
    if {$who eq "None" || $who in $G(solved,tiles)} return

    lassign $S(click,last) x1 y1
    set dx [expr {$x - $x1}]
    set dy [expr {$y - $y1}]

    set S(click,last) [list $x $y]

    .c move $tag $dx $dy
}
proc ClickUp {x y} {
    # Handles button up event
    global S G

    .c config -cursor [lindex [.c config -cursor] 3]
    set who $S(click,who)
    if {$who eq "None" || $who in $G(solved,tiles)} return

    set img ::img::puzzle_a_${who}
    set tag tile_$who
    set image_tag tile2_$who
    .c itemconfig $image_tag -image $img

    set dest [$S(MOTIF) XY2Tile $x $y]
    if {! [$S(MOTIF) CanPlaceTile $who $dest]} {
        set dest "None"
    }
    if {$dest eq "None" || $dest in $G(solved,tiles)} {
        .c coords $image_tag $S(click,xy)
        if {[.c find withtag grid] ne {}} {
            ::Magic::ShowGrid
        }
    } else {
        SwapTiles $S(MOTIF) $tag $dest
    }
}
namespace eval ::Timer {}

proc ::Timer::Tick {} {
    # Handles updating the timer dialog display
    global STATS

    after cancel $STATS(time,aid)
    if {$STATS(time,start) == 0} return

    set duration [expr {[clock seconds] - $STATS(time,start)}]
    set seconds [expr {$duration % 60}]
    set minutes [expr {$duration / 60}]
    if {$minutes >= 100} {
        set minutes 99
    }
    set STATS(pretty,time) [format %02d:%02d $minutes $seconds]
    if {$duration > 100 * 60} return
    set STATS(time,aid) [after 1000 ::Timer::Tick]
}
proc ::Timer::Reset {} {
    # Resets display on the timer dialog
    global STATS
    set STATS(time,start) [set STATS(count) [set STATS(bad) 0]]
    set STATS(pretty,time) "00:00"
    set STATS(playback) {}
    TallyMarks False
}
proc ::Timer::Start {} {
    # Starts a stopwatch
    global STATS
    if {$STATS(time,start) == 0} {
        set STATS(time,start) [clock seconds]
        ::Timer::Tick
    }
}
proc ::Timer::Stop {} {
    # Stops a stopwatch
    global STATS
    after cancel $STATS(time,aid)
    set STATS(time,start) 0
}
proc SwapTiles {MOTIF tag1 dest} {
    # Tile with tag tag1 goes to location dest, and vice-versa
    global G
    global STATS

    set first [string range $tag1 5 end]
    set whence $G($first,isAt)

    set second $G($dest,has)
    set tag2 "tile_$second"

    set xy1 [$MOTIF Tile2XY $dest]
    set xy2 [$MOTIF Tile2XY $whence]
    .c coords $tag1 $xy1
    .c coords $tag2 $xy2

    set G($first,isAt) $dest
    set G($dest,has) $first
    set G($second,isAt) $whence
    set G($whence,has) $second

    set puzzle_done False
    if {$dest != $whence} {
        incr STATS(count)
        if {$G($first,isAt) != $first && $G($second,isAt) != $second} {
            incr STATS(bad)
            ::Stars::MarkBad
            if {$STATS(bad) == $::Stars::STAR(count)} {
                set puzzle_done True
            }
        }

        set tally "B"
        if {$G($first,isAt) == $first || $G($second,isAt) == $second} {
            set tally "G"
            if {$G($first,isAt) == $first && $G($second,isAt) == $second} {
                set tally "2"
            }
        }
        lappend STATS(playback) $tally
        TallyMarks False
    }

    if {[.c find withtag grid] ne {}} {
        ::Magic::ShowGrid
    }

    set animate [expr {! [IsSolved]}]
    if {$G($first,isAt) == $first} {
        SolvedTile $first $animate
    }
    if {$G($second,isAt) == $second} {
        SolvedTile $second $animate
    }
    if {[IsSolved]} {
        TallyMarks True
        ::Timer::Stop
        ::Victory::Victory
    }
    if {$puzzle_done && $::BB(Puzzle)} {
        ShowStatus "Export Mode" "You ran out of lives!" button=Replay
    }
}
proc IsSolved {} {
    # Check if the puzzle is solved
    global G

    foreach idx [range [llength [array names G *,isAt]]] {
        if {$G($idx,isAt) != $idx} {
            return False
        }
    }
    return True
}
proc SolvedTile {who {animation 0}} {
    # Tile $who is now solved so update display
    global G
    # assert G($who,isAt) == $who
    # assert G($who,has) == $who

    lappend G(solved,tiles) $who
    set img ::img::puzzle_g_$who
    set tag tile_$who
    set image_tag tile2_$who
    .c itemconfig $image_tag -image $img

    if {$::S(theme) eq "Ell"} {
        foreach idx [range $G(count)] {
            if {$idx ni $G(solved,tiles)} {
                .c raise tile_$idx
            }
        }
        .c raise grid
    }

    if {$animation} {
        Explode $who 0 {*}[.c bbox $tag]
    }
}
proc lpick {llist} {
    # Selects random item from list
    set len [llength $llist]
    set idx [expr {int(rand() * $len)}]
    return [lindex $llist $idx]
}
proc PickTheme {{force ""}} {
    global S

    if {$force ne ""} { return $force }

    set all {}
    foreach {name value} [array get S themes,*] {
        if {$value} {
            lappend all [lindex [split $name ","] 1]
        }
    }
    if {$all eq {}} {
        set S(themes,Rectangle) 1
        return Rectangle
    }
    set theme [lpick $all]
    return $theme
}

proc AvailableThemes {} {
    # Which themes can we do
    global S

    if {[info exists S(themes)]} { return $S(themes) }
    set S(themes) {}
    set S(themes.cannot) {}
    foreach ns [lsort [namespace children]] {
        set cmd [info commands ${ns}::New]
        if {$cmd eq ""} continue
        if {[info commands ${ns}::CanDo] eq ""} continue

        set theme [lindex [split $cmd ":"] 2]
        if {[${ns}::CanDo]} {
            lappend S(themes) $theme
            Logger "Found theme $theme"
        } elseif {$theme ne "Baseshape"} {
            lappend S(themes.cannot) $theme
            Logger "Cannot do theme $theme"
        }
    }
    return $S(themes)
}
proc ShowStatus {title msg args} {
    # Puts up a dialog with a given message and title
    kwargs ARGS killafter="" parent=. button=Close subtitle="" {*}$args

    after cancel $::S(kill,after)
    set status .status
    set inside .c
    if {$ARGS(parent) ne "."} {
        set status $ARGS(parent).status
        set inside $ARGS(parent).body
    }
    if {$title ne ""} {
        destroy $status
    }

    if {[winfo exists $status]} {
        $status.msg config -text $msg
    } else {
        ::ttk::frame $status -borderwidth 3 -relief ridge -padding .5i
        ::ttk::label $status.icon -image ::img::icon
        ::ttk::label $status.title -text $title -font $::bigger_bold_font -anchor c -justify c
        ::ttk::label $status.subtitle -text $ARGS(subtitle) -font $::big_bold_font \
            -anchor c -justify c
        ::ttk::label $status.msg -text $msg -anchor c -font $::bigger_font -justify l
        ::ttk::frame $status.bframe

        grid $status.icon $status.title -sticky news
        if {$ARGS(subtitle) ne ""} {
            grid ^ $status.subtitle -sticky news
        }
        grid $status.msg - -sticky news -pady {.2i 0}
        grid $status.bframe -

        set btext ""
        set btext2 ""
        set bcmd [list destroy $status]
        set bcmd2 [list destroy $status]
        if {$ARGS(button) eq "Close"} {
            set btext $ARGS(button)
        } elseif {$ARGS(button) eq "Start"} {
            set btext "Start"
            set bcmd GetPotDImage
        } elseif {$ARGS(button) eq "Again"} {
            set btext "Try Again"
            set bcmd GetPotDImage
        } elseif {$ARGS(button) eq "Replay"} {
            set btext $ARGS(button)
            set bcmd "::Magic::ChangeSize ; destroy $status"
            set btext2 "Play On"
        }
        if {$btext ne ""} {
            grid columnconfigure $status.bframe all -pad .5i
            ::ttk::button $status.bframe.button -text "  $btext  " -command $bcmd
            if {$btext2 eq ""} {
                grid $status.bframe.button -pady {.2i 0} -sticky ew
            } else {
                ::ttk::button $status.bframe.button2 -text "  $btext2  " -command $bcmd2
                grid $status.bframe.button $status.bframe.button2 -pady {.2i 0} -sticky ew
                grid $status.bframe.button -padx {0 .25i}
                grid $status.bframe.button2 -padx {.25i 0}

            }
        }
        place $status -in $inside -anchor c -relx .5 -rely .4
    }
    set width [expr {[winfo reqwidth $status.icon] + [winfo reqwidth $status.title]}]
    $status.msg config -wraplength $width

    update
    if {[string is integer -strict $ARGS(killafter)]} {
        set ::S(kill,after) [after $ARGS(killafter) [list destroy $status]]
    }
}
proc kwargs {dest args} {
    # Turns list of key=value into array of dest($key) = $value
    upvar 1 $dest var
    if {[array exists var]} {
        array unset var
    }
    foreach arg $args {
        lassign [split $arg "="] key value
        if {$value eq {""}} {
            set var($key) ""
        } else {
            set var($key) [expr {$value eq "" ? True : $value}]
        }
    }
}
proc GetPotDImage {{service ""} {override ""}} {
    # Download PotD image from Wikipedia or Wiki Commons
    global S
    global meta all
    ::Victory::Stop
    destroy .status

    if {$service eq ""} {
        set service [expr {rand() > .5 ? "Wikipedia" : "Commons"}]
    } else {
        set service [string totitle $service]
    }

    set fitness [list $S(maxWidth) $S(maxHeight)]

    Logger ""
    if {$override ne ""} {
        lassign $override year month day
        set when "$year/$month/$day"
        ShowStatus "Picture of the Day" "Downloading $service PotD for $when" button=None
        Logger "::POTD::GetPOTD $service $when {$fitness}"
        set start [clock microseconds]
        lassign [::POTD::GetPOTD $service $year $month $day $fitness] meta all
        set end [clock microseconds]
    } else {
        ShowStatus "Picture of the Day" "Downloading random $service PotD" button=None
        Logger "::POTD::RandomPOTD $service {$fitness}"
        set start [clock microseconds]
        lassign [::POTD::RandomPOTD $service $fitness] meta all
        set end [clock microseconds]
    }
    set ms [expr {$end - $start}]
    Logger "Downloading image metadata took [PrettyTime $ms]"

    set status [dict get $meta status]
    set date [dict get $meta date]
    set seconds [clock scan $date -format %Y/%m/%d]
    set when [clock format $seconds -format "%A %B %d, %Y"]

    if {$status == 0} {
        set emsg [dict get $meta emsg]
        set txt "Error downloading $service PotD\nfor $when:\n\"$emsg\""
        if {[string first "Unterminated element 'video'" $emsg] > -1} {
            set txt "PotD is a video"
        }
        destroy .status
        Logger $txt emsg
        ShowStatus "PotD Fetch Error" $txt button=Again
        return
    }
    if {$status == 1} {
        set desc [dict get $meta desc]
        set txt "Problem downloading $service PotD\nfor $when:\n\"$desc\""
        destroy .status
        Logger $txt emsg
        ShowStatus "PotD Fetch Error" $txt button=Again
        return
    }

    _DownloadBestSize $all $fitness

    set S(local,current) ""
    set S(potd,current) [EncodePotDFilename $service $date $S(img,url)]
    Logger $S(potd,current)
    set potd_desc [dict get $meta desc]
    regsub -all {\s\s+} $potd_desc " " potd_desc
    set short_desc [FirstSentence $potd_desc]

    .potd.save config -state normal

    set sizes [lmap a $all { return -level 0 "[lindex $a 0]x[lindex $a 1]" }]
    Logger "Sizes: $sizes"
    Logger "Best fit: [PrettySize $S(iwidth) $S(iheight)] (to fit into [join $fitness x])"
    set S(ratio) [expr {double(min($S(iwidth), $S(iheight))) / max($S(iwidth), $S(iheight))}]
    Logger "Ratio: $S(ratio)"
    Logger "Description: $potd_desc"
    incr ::STATS(total,$service)

    TallyUsage $S(potd,current) $short_desc
    _Go $S(img) "$service Picture of the Day for $when" $short_desc $potd_desc
}
proc _DownloadBestSize {all fitness} {
    global S meta

    lassign $fitness maxWidth maxHeight

    set bestfit [dict get $meta bestfit]

    # NB. reported size doesn't always match actual size
    # e.g. potd_2024_02_16_c.jpg size 768x768 was actually 960x960 in size
    while {$bestfit >= 0} {
        lassign [lindex $all $bestfit] S(iwidth) S(iheight) url
        Logger "bestfit: #$bestfit [PrettySize $S(iwidth) $S(iheight)]"
        dict set meta image_url $url
        regsub {\?.*} $url "" url
        set idata [::POTD::DownloadUrl $url] ; list
        set S(itype) [ImageType $idata $url]
        set S(img) [image create photo ::img::master -data $idata]
        set S(img,url) $url

        # Check for fitness
        set iwidth [image width $S(img)]
        set iheight [image height $S(img)]
        if {$iwidth <= $maxWidth && $iheight <= $maxHeight} break

        Logger [string cat "ERROR: image size claims to [PrettySize $S(iwidth) $S(iheight)]" \
                    " but is [PrettySize ${iwidth} $iheight]"] emsg
        if {$::ST(alwaysResize,onoff)} {
            set S(img) [_ResizeWebImage $S(img) $S(itype) $maxWidth $maxHeight]
            set iwidth [image width $S(img)]
            set iheight [image height $S(img)]
            Logger [string cat "New size with ImageMagick: [PrettySize $iwidth $iheight]"]
            break
        }

        incr bestfit -1
    }
}
proc _ResizeWebImage {img itype maxWidth maxHeight} {
    # Some web images are bigger than they claim, e.g. potd_2019_07_24_w.jpg
    # This code scales them to best fit into the max size using ImageMagick
    global S

    set ifile [file join $S(tempdir) _resize_pre.$itype]
    set ofile [file join $S(tempdir) _resize_post.$itype]
    $img write $ifile -format $itype

    set max_size "$S(maxWidth)x$S(maxHeight)"
    Logger "Resizing web image with ImageMagick"
    Logger "  exec magick /.../[file tail $ifile] -resize $max_size /.../[file tail $ofile]"
    exec magick $ifile -resize $max_size $ofile
    set img [image create photo -file $ofile]

    file delete $ifile
    file delete $ofile
    return $img
}
proc _Go {img source pretty_desc potd_desc {theme ""}} {
    # Starts puzzle with given image
    global S STATS

    .c delete all
    .c create rect -1000 -1000 10000 10000 -tag background -fill white
    set theme [PickTheme $theme]
    set S(theme) $theme
    Logger "Theme: $theme"

    set S(img,original) $img
    ::ShadowBorder::MakeShadowPhoto $img ::img::fmaster
    set S(img) ::img::fmaster
    set S(iwidth) [image width $S(img)]
    set S(iheight) [image height $S(img)]

    set S(pretty,source) $source
    set S(pretty,desc) $pretty_desc
    set S(potd,desc) $potd_desc
    ::tooltip::tooltip .bottom.desc [::textutil::adjust $S(potd,desc)]

    UpdateDescriptionDialog $S(pretty,source) $S(potd,desc)
    ::Magic::UpdateImage
    ::Timer::Reset
    ::Stars::MarkBad

    destroy .status
    ::Victory::Stop

    image delete {*}[info commands ::img::puzzle_*]
    .c config -width $S(iwidth) -height $S(iheight)
    .bottom.desc config -wraplength $S(iwidth)
    set S(magic,grid) 0

    if {$S(iwidth) < $S(min,width) || $S(iheight) < $S(min,height)} {
        .c config -width 800 -height 600
        set msg "Picture is too small to scramble: [PrettySize $S(iwidth) $S(iheight)]"
        Logger $msg emsg
        ShowStatus "Error" $msg button=Again
        .bottom.desc config -wraplength 800
        return
    }
    if {$S(ratio) < $S(min,ratio)} {
        .c config -width 800 -height 600
        set bad [expr {$S(iwidth) > $S(iheight) ? "short and wide" : "tall and narrow"}]
        set msg "Picture is too $bad to scramble:\n[PrettySize $S(iwidth) $S(iheight)]"
        Logger $msg emsg
        ShowStatus "Error" $msg button=Again
        .bottom.desc config -wraplength 800
        return
    }
    ShowStatus "Processing image..." "" button=None

    set S(MOTIF) [$S(theme)::New $S(img) $S(itype) $S(tempdir)]
    wm title . "$S(title) \u2014 $theme Theme"
    try {
        raise .
        Busy 1
        PreviewImage create
        set start [clock microseconds]
        $S(MOTIF) SplitImage
    } finally {
        set end [clock microseconds]
        PreviewImage wait
        Busy 0
    }
    set ms [expr {$end - $start}]
    Logger "Splitting image into tiles took [PrettyTime $ms]"

    destroy .status
    .c create image 0 0 -image ::img::puzzle_frame -anchor nw -tag frame
    .c lower frame
    .c lower background
    ScrambleTiles $S(MOTIF)
    if {$::BB(Puzzle)} {
        Puzzle
    }

}
proc GetLocalPicture {{next False} {iname ""}} {
    # Open file from local storage
    global S

    ::Victory::Stop
    destroy .status

    Logger ""
    if {$iname eq ""} {
        set iname [WhichLocalPicture $next]
    }
    if {$iname eq ""} return

    lassign [CheckSize $iname] yesno scaling
    if {! $yesno} return

    set S(local,current) $iname
    set S(potd,current) ""
    set S(itype) [ImageType "" $iname]

    BuildNextImageList

    .potd.save config -state disabled
    LoadScaledImage $scaling

    lassign [GetLocalDescription $iname] pretty_desc source
    set ::meta [dict create desc $pretty_desc image_url $S(local,current)]

    incr ::STATS(total,Local)
    TallyUsage $S(local,current) $pretty_desc
    _Go $S(img) $source $pretty_desc $pretty_desc
}
proc GetLocalDescription {iname} {
    global S

    set source $iname
    set desc "Picture from [PrettyFname [file dirname [file normalize $iname]]]"

    lassign [DecodePotDFilename $iname] status service year month day
    if {$status} {
        set seconds [clock scan "$year/$month/$day" -format %Y/%m/%d]
        set when [clock format $seconds -format "%A, %B %d, %Y"]
        set source "Local copy of $service Picture of the Day for $when"

        set better_desc [FindPotDDescription $iname]
        if {$better_desc ne ""} {
            set desc $better_desc
            Logger "Cache hit for PotD description $iname"
            Logger $desc
        }
    }
    return [list $desc $source]
}
proc WhichLocalPicture {next} {
    # Either asks user to pick a file or gets the next picture
    global S

    if {$next} {
        while {True} {
            set S(local,images) [lassign $S(local,images) iname]
            if {[file readable $iname]} {
                lappend S(local,images) $iname
                break
            }
            if {[llength $S(local,images)] == 0} {
                set iname ""
                break
            }
        }
        set iname [file normalize $iname]
        if {$iname eq "" || $iname eq $S(local,current)} {
            ShowStatus "Open Error" "No more files in directory" killafter=3000
        } else {
            Logger "Using next picture from directory: $iname"
        }
    } else {
        set types {
            {{PNG Files} .png}
            {{JPEG Files} {.jpg .jpeg}}
            {{GIF Files} .gif}
            {{All Files} *}
        }
        set iname [tk_getOpenFile -filetypes $types -title "Select Image File"]
        if {$iname ne ""} {
            Logger "Using picture saved locally: $iname"
        }
    }
    return $iname
}
proc CheckSize {iname} {
    # Check if image is too big for screen, and returns how to scale it down
    global S ST

    set img [image create photo -file $iname]
    set w [image width $img]
    set h [image height $img]
    image delete $img

    if {$w <= $S(maxWidth) && $h <= $S(maxHeight)} {
        return [list True 1]
    }

    # NB. scale will be ignored if we have ImageMagick
    set w_scale [expr {int(ceil(double($w) / $S(maxWidth)))}]
    set h_scale [expr {int(ceil(double($h) / $S(maxHeight)))}]
    set scale [expr {max($w_scale, $h_scale)}]

    if {$ST(alwaysResize,onoff)} { return [list True $scale] }

    set msg "Picture [file tail $iname] is too big:\n"
    append msg "[Comma $w]x[Comma $h] vs [Comma $S(maxWidth)]x[Comma $S(maxHeight)]"
    append msg "\n\nResize to make it fit?"

    set ans [tk_messageBox -icon question -type yesno -message $msg \
                 -title $S(title) -parent .]

    return [list [expr {$ans == "yes"}] $scale]
}
proc LoadScaledImage {scaling} {
    # Loads S(local,current) into S(img) with possible scaling
    global S

    set iname $S(local,current)

    if {$scaling == 1} {
        set S(img) [image create photo ::img::master -file $S(local,current)]
        set S(iwidth) [image width $S(img)]
        set S(iheight) [image height $S(img)]
        set S(ratio) [expr {double(min($S(iwidth), $S(iheight))) / max($S(iwidth), $S(iheight))}]
        return
    }
    if {! [::Baseshape::_HasImageMagick]} {
        Logger "Resizing image by subsampling -$scaling"
        set S(img) [image create photo ::img::master]
        set img [image create photo -file $S(local,current)]
        $S(img) copy $img -subsample $scaling $scaling
        image delete $img
        return
    }

    set ofile [file join $S(tempdir) _resize[file extension $iname]]
    set max_size "$S(maxWidth)x$S(maxHeight)"

    Logger "Resizing with ImageMagick"
    Logger "  exec magick $iname -resize $max_size $ofile"
    exec magick $iname -resize $max_size $ofile
    set S(img) [image create photo ::img::master -file $ofile]
    set S(iwidth) [image width $S(img)]
    set S(iheight) [image height $S(img)]
    set S(ratio) [expr {double(min($S(iwidth), $S(iheight))) / max($S(iwidth), $S(iheight))}]

    file delete $ofile
}
proc BuildNextImageList {{dirname ""}} {
    # Gets a list of image files on local storage
    global S

    if {$dirname eq ""} {
        set dirname [file dirname $S(local,current)]
    }
    if {$dirname eq $S(local,cwd)} return

    set S(local,cwd) $dirname
    set S(local,images) {}
    foreach ext {.jpg .jpeg .png .gif} {
        lappend S(local,images) {*}[glob -nocomplain [file join $dirname "*$ext"]]
    }
    set S(local,images) [Shuffle $S(local,images)]

    set n [lsearch -exact $S(local,images) $S(local,current)]
    if {$n != -1} {
        set S(local,images) [concat [lreplace $S(local,images) $n $n] $S(local,current)]
    }
    set txt "Select next image\nfrom last directory\n[llength $S(local,images)] images"
    ::tooltip::tooltip .buttons.next $txt
}
proc EncodePotDFilename {service date url} {
    # Convert service/date into a canonical filename
    set service [string tolower [string index $service 0]]
    set ext [file extension $url]
    lassign [split $date "/"] year month day
    return [format "potd_%04d_%02d_%02d_%s%s" $year $month $day $service $ext]
}

proc DecodePotDFilename {fname} {
    # Decodes canonical filename into service/date
    set n [scan [file tail $fname] "potd_%d_%d_%d_%1s.%s" year month day service ext]
    if {$n != 5} {
        if {[string match potd_* $fname]} {
            Logger "Couldn't decode $fname"
        }
        return [list 0 _ _ _ _]
    }
    set service [expr {$service eq "c" ? "Commons" : "Wikipedia"}]
    return [list 1 $service $year $month $day]
}
proc _forcePotD {fname} {
    # Download PotD for service/date given a canonical filename
    set tail [file tail $fname]
    lassign [DecodePotDFilename $tail] status service year month day
    if {! $status} {
        puts "could not decode $tail"
        return
    }
    set override [list $year $month $day]
    GetPotDImage $service $override
}
proc FirstSentence {para} {
    # Given a paragraph of text, extract its first sentence
    # Fails on "An image ... STS-1. Lorem ipsum."

    set n [regexp {[.?!].} $para]
    if {$n == 0} { return $para }

    # All capital words that can end a sentence
    set ewords {
        USA UTC WW1 WW2 WWI WWII "World\\sWar\\sI" "World\\sWar\\sII"
        "World\\sWar\\s1" "World\\sWar\\s2" "II" "CE" "FC" "D.C." "BC"
        "\[0-9,\]+ m"
    }
    foreach eword $ewords {
        # Turn "... USA." into "... USA@aa."
        regsub "\\m($eword)\\." $para {\1@aa.} para
    }

    # Capital word inside parentheses, e.g. "Larry Bird ... (NBA). Lorem ipsum."
    set re {(\s\([[:upper:]0-9]+\))\.}
    regsub $re $para {\1@aa.} para

    # Abbreviations that prematurely end a sentence
    foreach abbrev {Mrs vs Gens Gen Jan Feb Mar Apr May Jun Jul Aug Sep Sept Oct Nov Dec
        ca bap St Mt Jr} {
        # Turn "... Mrs. Jones" into "... Mrs@ Jones"
        regsub -all "\\m($abbrev)\\." $para {\1@} para
    }

    set re {(^.*?[[:alnum:]\)""]{2,}[.!?]"?"?)\s+\W*[A-Z0-9]}
    set n [regexp $re $para _ sentence]

    set result [expr {$n ? $sentence : $para}]
    regsub -all {@aa\.} $result "." result
    regsub -all {@} $result "." result
    return $result
}
proc FirstSentenceTest {} {
    set tests {
        "This is a test. Lorem ipsum."
        "Is this a test? Lorem ipsum."
        "This is a test! Lorem ipsum."
        "This is a simple test. Lorem ipsum."
        "Is this a question? Lorem ipsum."
        "This is a test! Lorem ipsum."
        "The year was 1825. Lorem ipsum."
        "Winslow Homer (1836-1910). Lorem ipsum."
        "The poem \"The Raven\". Lorem ipsum."
        "He said \"I love you.\" Lorem ipsum."
        "See you at 20:43 UTC. Lorem ipsum."
        "See you at 20:43 UTC. on friday. Lorem ipsum."
        "I'm flying to New Mexico, USA. Lorem ipsum."
        "The coin was issued on Nov. 28, 1921. Lorem ipsum."
        "He died fighting in World War I. Lorem ipsum."
        "He died fighting in World War\xA0I. Lorem ipsum."
        "He died fighting in World War 1. Lorem ipsum."
        "He died fighting in World War\xA01. Lorem ipsum."
        "He died fighting in World War II. Lorem ipsum."
        "He died fighting in World War\xA0II. Lorem ipsum."
        "He died fighting in World War 2. Lorem ipsum."
        "He died fighting in World War\xA02. Lorem ipsum."
        "I invited Mrs. Bill Stagg of Boston. Lorem ipsum."
        "The love the revalry of the sharks vs. the jets. Lorem ipsum."
        "Seated are Gens. Grant and Sherman. Lorem ipsum."
        "Under Charles I and Charles II. Lorem ipsum."
        "He bought a Roman sculpture dating from about 125\xA0CE. Lorem ipsum."
        "The American club New York City FC. Lorem ipsum."
        "Photograph ca. 1847 hand-tinted. Lorem ipsum."
        "Martin Ryckaert (bap. 1587 – 1631) was a Flemish painter. Lorem ipsum."
        "Maya Lin's monument Washington, D.C.. Lorem ipsum."
        "Somewhere in North Africa. Lorem ipsum."
        "The Complex is dated to 1950 BC. Lorem ipsum."
        "Dennis Schröder ... (NBA). Lorem ipsum."
        "His name is Richard Genée. Lorem ipsum."
        "Fatinitza is an opera by Richard Genée. Lorem ipsum."
        "The JFK Library by I. M. Pei at dusk. Lorem ipsum."
        "Azores juniper occurs at altitude up to 1,500 m. Lorem ipsum."
        "The Church of St. Augustine and St. John was founded around 1180. Lorem ipsum."
        "A Storm in the Rocky Mountains, Mt. Rosalie is an oil painting. Lorem ipsum."
        "John Doe Jr. was a man. Lorem ipsum."
    }
    set fails {
        "An image of the first Space Shuttle Mission, STS-1. Lorem ipsum."
    }

    set success True
    foreach datum $tests {
        set actual [FirstSentence $datum]
        regexp {(.*?)\sLorem ipsum.*} "$datum Lorem ipsum" _ expected
        if {$actual ne $expected} {
            puts stderr "Test failure"
            puts stderr "  datum   : '$datum'"
            puts stderr "  actual  : '$actual'"
            puts stderr "  expected: '$expected'"
            puts stderr ""
            set success False
        }
    }

    if {$success} {
        puts "all tests pass"
    }
    return success
}
proc SavePotD {} {
    # Saves current image locally
    global S

    if {$S(potd,current) eq ""} {
        ShowStatus "Picture of the Day" "Error: current image is not PotD"
        return
    }

    set fname [tk_getSaveFile -initialfile $S(potd,current) -title "Save PotD" -parent .c]
    if {$fname ne ""} {
        ::img::master write $fname -format jpeg
        ShowStatus "Picture of the Day" "Saving POTD to $fname" killafter=3000
    }
}
proc SavePotDFast {} {
    # Saves current image locally using its canonical filename
    global S

    if {$S(potd,current) eq ""} {
        ShowStatus "Picture of the Day" "Error: current image is not PotD"
        return
    }
    set fname [file join $S(local,cwd) $S(potd,current)]
    ::img::master write $fname -format jpeg
    ShowStatus "Picture of the Day" "Saving POTD to $fname" killafter=3000
    Logger "Saving $S(potd,current) to $S(local,cwd)"
}

proc FindPotDDescription {potdname} {
    # Tries to locate cached description for a given canonical potdname
    global S

    set desc ""
    set tail [file tail $potdname]
    if {[file readable $S(inifile,tally)]} {
        set data ""
        set n [catch {
            set fin [open $S(inifile,tally) r]
            set data [read $fin] ; list
            close $fin
        }]
        set fname [string map {"." "\\." "*" "\\*" "?" "\\?"} $tail]
        set re "$fname.*\t(.*)$"
        set n [regexp -line -nocase $re $data _ desc]
        if {$n} { return $desc }
    }
    return ""
}
proc Restart {{theme ""}} {
    # Restarts current image with new theme

    global S
    ::Victory::Stop

    if {$S(pretty,source) eq ""} return
    Logger "Rescrambling: $S(pretty,source)"
    _Go $S(img,original) $S(pretty,source) $S(pretty,desc) $S(potd,desc) $theme
}
proc PreviewImage {verb} {
    # Previews the current puzzle image on screen for S(preview,delay)
    # while the image is being processed. Uses a hidden window and
    # tkwait to timeout appropriately
    global S ST

    if {! $ST(preview,onoff)} return
    ::Favorites::PlaceWindow

    if {$verb eq "create"} {
        .c create image 0 0 -image $S(img) -anchor nw -tag preview
    } elseif {$verb eq "wait"} {
        if {[.c find withtag preview] eq ""} return
        if {$S(preview,delay) > 100} {
            destroy .status
            PreviewMsg
            PreviewThrobber

            set S(preview,active) 1
            after $S(preview,delay) "set S(preview,active) 0"
            tkwait variable S(preview,active)
            .c delete preview
        }
    }
}
proc PreviewMsg {} {
    # Displays our preview message and sets up preview throbber
    global S
    set font $::bigger_bold_font2
    set x [expr {$S(iwidth) / 2}]
    set y1 $S(iheight)
    set y [winfo height .c]

    set S(preview,throbbers,delay) 500

    set steps [expr {int($S(preview,delay) / $S(preview,throbbers,delay))}]
    set S(preview,throbbers) {}
    foreach cnt [range $steps 0 -1] {
        lappend S(preview,throbbers) [string repeat "." $cnt]
    }

    set first [lindex $S(preview,throbbers) 0]
    set text " Preview$first "

    .c delete preview_msg
    .c create text $x $y -text $text -anchor s -font $font -tag {preview_msg preview_msg1 preview}
    lassign [.c bbox preview_msg] x0 y0 x1 y1
    .c coords preview_msg1 $x0 $y0
    .c itemconfig preview_msg1 -anchor nw
    .c create rect $x0 $y0 $x1 $y1 -fill yellow -width 2 -outline black -tag {preview_msg preview}

    .c raise {*}[.c find withtag preview_msg]
}
proc PreviewThrobber {} {
    # Replaces preview text with next item in S(preview,throbbers)
    global S

    if {[.c find withtag preview_msg1] ne ""} {
        set S(preview,throbbers) [lassign $S(preview,throbbers) first]
        set text " Preview$first "

        .c itemconfig preview_msg1 -text $text
        after $S(preview,throbbers,delay) PreviewThrobber
    }
}
proc PrettyFname {fname} {
    foreach {prefix str} [list [pwd] "./" [file normalize ~] "~/"] {
        if {[string match "$prefix*" $fname]} {
            set fname [string replace $fname 0 [string length $prefix] $str]
            return $fname
        }
    }
    return $fname
}
proc PrettyTime {ms} {
    if {$ms < 1000*1000} {
        return "[Comma $ms] microseconds"
    }
    set seconds [expr {$ms / 1000.0 / 1000.0}]
    return [format "%.1f seconds" $seconds]
}
proc PrettySize {w h} {
    return "[Comma $w]x[Comma $h]"
}
proc Comma {num} {
    while {[regsub {^([-+]?[0-9]+)([0-9][0-9][0-9])} $num {\1,\2} num]} {}
    return $num
}
proc TallyUsage {who desc} {
    global S ST

    if {! $S(filesystem,writable)} return

    if {$S(beta) || $ST(tallyfile,onoff)} {
        set when [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %A"]
        set fout [open $S(inifile,tally) "a"]
        puts $fout "$when\t$who\t$desc"
        close $fout
    }
}
proc DialogTemplate {who top subtitle} {
    # Generic toplevel dialog with standard icon, title and layout
    destroy $top
    toplevel $top
    wm transient $top .
    wm title $top $::S(title)
    wm protocol $top WM_DELETE_WINDOW [list DialogOnOff $who off]
    wm resizable $top 0 0

    ::ttk::frame $top.logo
    ::ttk::frame $top.body

    ::ttk::label $top.logo.icon -image ::img::icon
    ::ttk::label $top.logo.title -text $::S(title) -font $::bigger_bold_font -anchor c
    ::ttk::label $top.logo.title2 -text $subtitle -font $::bigger_bold_font2 -anchor c

    grid $top.logo -row 0 -sticky news
    grid columnconfigure $top.logo 1 -weight 1
    grid $top.logo.icon -row 0 -column 0 -rowspan 2 -padx {.2i .2i}
    grid $top.logo.title -row 0 -column 1 -sticky news
    grid $top.logo.title2 -row 1 -column 1 -sticky news

    grid $top.body -row 1 -sticky news
    grid rowconfigure $top 1 -weight 1
    grid columnconfigure $top 0 -weight 1

    return $top.body
}
namespace eval ::Magic {
    variable MAGIC
    set MAGIC(top) .magic
}

proc ::Magic::OneTile {} {
    # Solves one tile in the puzzle
    global G S STATS

    if {$S(img) eq "TBD"} return
    if {[IsSolved]} return

    ::Timer::Start
    if {! [::Magic::IsForced] && "S" ni $STATS(playback)} {
        lappend STATS(playback) "S"
    }
    set unsolved {}
    foreach idx [range [llength [array names G *,isAt]]] {
        if {$G($idx,isAt) != $idx} {
            lappend unsolved $idx
        }
    }
    set who [lpick $unsolved]
    Logger "Solving tile $who"
    SwapTiles $S(MOTIF) tile_$who $who
}
proc ::Magic::RandomSwap {} {
    global G S

    if {$S(img) eq "TBD"} return
    if {[IsSolved]} return

    ::Timer::Start
    set unsolved_tiles {}
    foreach idx [range [llength [array names G *,isAt]]] {
        if {$G($idx,isAt) != $idx} {
            lappend unsolved_tiles $idx
        }
    }
    set who [lpick $unsolved_tiles]

    set candidates {}
    foreach dest [range [llength [array names G *,isAt]]] {
        if {$G($dest,has) == $dest} continue
        if {$G($dest,has) == $who} continue
        if {[$S(MOTIF) CanPlaceTile $who $dest]} {
            lappend candidates $dest
        }
    }
    set whither [lpick $candidates]
    Logger "Randomly moving tile $who to position $whither"

    Explode $who 0 {*}[.c bbox tile_$who]
    Explode $whither 0 {*}[.c bbox tile_$whither]

    SwapTiles $S(MOTIF) tile_$who $whither
}
proc ::Magic::Row {} {
    # Solves one row of the puzzle
    global G S

    if {$S(img) eq "TBD"} return
    if {[IsSolved]} return

    ::Timer::Start
    unset -nocomplain unsolved
    set all_rows {}
    foreach slot [range [llength [array names G *,isAt]]] {
        lassign [$S(MOTIF) Tile2XY $slot] x y
        lappend all_rows $y

        if {$G($slot,has) != $slot} {
            lappend unsolved($y) $slot
        }
    }
    set row [lpick [array names unsolved]]
    set rownumber [lsearch [lsort -real -unique $all_rows] $row]

    Logger "Solving row [expr {1 + $rownumber}]"
    foreach slot $unsolved($row) {
        SwapTiles $S(MOTIF) tile_$slot $slot
    }
}
proc ::Magic::Solve {} {
    # Solves the puzzle completely
    global G S STATS

    if {$S(img) eq "TBD"} return
    if {[IsSolved]} return

    ::Timer::Start
    if {! [::Magic::IsForced] && "S" ni $STATS(playback)} {
        lappend STATS(playback) "S"
    }
    Logger "Solving puzzle"
    while {True} {
        set unsolved {}
        foreach idx [range [llength [array names G *,isAt]]] {
            if {$G($idx,isAt) != $idx} {
                lappend unsolved $idx
            }
        }
        set who [lindex $unsolved 0]
        SwapTiles $S(MOTIF) tile_$who $who
        if {[IsSolved]} break
    }
    ::Timer::Stop
}
proc ::Magic::UnsolvedSets {} {
    global G S

    if {$S(img) eq "TBD"} return
    if {[IsSolved]} return

    set unsolved_tiles {}
    foreach idx [range [llength [array names G *,isAt]]] {
        if {$G($idx,isAt) != $idx} {
            lappend unsolved_tiles $idx
        }
    }
    unset -nocomplain USETS
    foreach tile $unsolved_tiles {
        set found False
        foreach dest [array names USETS] {
            if {[$S(MOTIF) CanPlaceTile $tile $dest]} {
                lappend USETS($dest) $tile
                set found True
                break
            }
        }
        if {! $found} {
            set USETS($tile) [list $tile]
        }
    }
    set result [lmap {_ x} [array get USETS] { return -level 0 $x }]
    return $result
}
proc ::Magic::IsForced {} {
    set usets [::Magic::UnsolvedSets]
    if {$usets eq {}} {return False }
    foreach uset $usets {
        if {[llength $uset] > 3} { return False }
    }
    return True
}
proc ::Magic::ShowGrid {} {
    # Shows the underlying tiling grid
    global G S

    .c delete grid
    if {! $S(magic,grid)} return
    if {$S(img) eq "TBD"} return

    set font {Helvetica 48 bold}
    set color1 darkblue
    set color2a magenta
    set color2b lightgreen

    foreach {key value} [array get $S(theme)::SQ xy,*] {
        lassign $value xy c
        set idx [lindex [split $key ","] 1]
        if {! [string is integer $idx]} continue
        set who $G($idx,has)
        set n1 [.c create text $c -text $who -font $font -fill $color1 -tag grid]
        .c move $n1 -3 -3
        set color [expr {$who == $idx ? $color2b : $color2a}]
        .c create text $c -text $who -font $font -fill $color -tag grid
        .c create poly $xy -fill "" -outline $color -width 5 -tag grid
    }
}
proc ::Magic::UpdateImage {} {
    # Displays current image at half size in the magic dialog
    variable MAGIC
    global S

    image create photo ::img::grid
    if {$S(img) ne "TBD"} {
        ::img::grid copy $S(img) -subsample 2 2
        destroy $MAGIC(top).tbd
    }
}
proc ::Magic::CleanUp {} {
    variable MAGIC
    # Tasks to do when the magic dialog goes away
    set ::BB(Magic) 0
    .c delete grid
    destroy $MAGIC(top)
}
proc ::Magic::Dialog {} {
    variable MAGIC
    global S ST

    set top $MAGIC(top)
    set S(magic,grid) 0
    set S(magic,url1) [set S(magic,url2) ""]

    ::Magic::UpdateImage
    if {[winfo exists $top]} return

    set body [DialogTemplate Magic $top "Magic Page"]
    set left $body.left
    wm protocol $top WM_DELETE_WINDOW ::Magic::CleanUp

    ::ttk::label $body.img -image ::img::grid -relief ridge -borderwidth 5 -anchor c

    ::ttk::frame $left
    ::ttk::label $left.title -text "Magics" -font $::big_font
    ::ttk::checkbutton $left.show -text "Show grid" \
        -command ::Magic::ShowGrid -variable S(magic,grid)

    ::ttk::button $left.bdiff -text "Rescramble" -command ::Magic::ChangeSize
    ::ttk::scale $left.sdiff -variable ST(difficulty,raw) \
        -from -2 -to 2 -command ::Magic::UpdateDifficultyDisplay
    ::ttk::label $left.ldiff -textvariable S(difficulty,pretty) -anchor c
    ::tooltip::tooltip $left.bdiff "Resize scramble from easiest to hardest"
    ::tooltip::tooltip $left.ldiff "Resize scramble from easiest to hardest"
    ::tooltip::tooltip $left.sdiff "Resize scramble from easiest to hardest"
    ::Magic::UpdateDifficultyDisplay $ST(difficulty,raw)
    ::Magic::InsertNewLevel [expr {int(round($ST(difficulty,raw)))}]

    ::ttk::button $left.month -text "Month URL" -command {::Magic::URL month}
    ::ttk::button $left.day -text "Day URL" -command {::Magic::URL day}
    ::ttk::button $left.image -text "Image URL" -command {::Magic::URL image}
    ::ttk::button $left.potdname -text "PotD name" -command {::Magic::URL potdname}

    set styling Toolbutton
    set styling ""
    ::ttk::checkbutton $left.preview -text "Preview image" -variable ST(preview,onoff) \
        -style $styling -command SaveInifile
    ::ttk::checkbutton $left.shadows -text "Color borders" -variable ST(color,shadows) \
        -command ::Magic::ColorShadows -style $styling -command ::Magic::ColorShadows
    ::ttk::checkbutton $left.scale -text "Automatic resizing" -variable ST(alwaysResize,onoff) \
        -style $styling -command SaveInifile
    if {! [::Baseshape::_HasImageMagick]} {
        $left.scale config -state disabled
        set ST(alwaysResize,onoff) 0
    }
    ::ttk::checkbutton $left.ini -text "Save settings" -variable ST(inifile,onoff) \
        -style $styling -command SaveInifile

    ::ttk::button $left.quit -text "Close" -command ::Magic::CleanUp
    ::ttk::label $left.msg1 -textvariable S(magic,url1) -anchor c \
        -font $::big_font -justify c
    ::ttk::label $left.msg2 -textvariable S(magic,url2) -anchor c \
        -font $::big_font -justify c

    ::tooltip::tooltip $left.show "Toggle showing cutout grid"
    ::tooltip::tooltip $left.month "Copy PotD month URL to clipboard"
    ::tooltip::tooltip $left.day "Copy PotD day URL to clipboard"
    ::tooltip::tooltip $left.image "Copy PotD image URL to clipboard"
    ::tooltip::tooltip $left.potdname "Copy PotD encoded name to clipboard"
    ::tooltip::tooltip $left.preview "Preview image while loading it"
    ::tooltip::tooltip $left.shadows "Toggle color or black & white tile shadows"
    ::tooltip::tooltip $left.scale "Always resize images to fit using ImageMagick"
    ::tooltip::tooltip $left.ini "Save game state between sessions"
    ::tooltip::tooltip $left.quit "Close dialog"

    grid columnconfigure $body 1 -weight 1
    grid $left $body.img -sticky news
    grid $left.title -pady {0 .2i}
    grid $left.show -sticky ew -padx .1i
    grid $left.bdiff -sticky ew -pady {.3i 0}
    grid $left.sdiff -sticky ew -padx .1i
    grid $left.ldiff -sticky ew
    grid $left.month -sticky ew -pady {.3i 0}
    grid $left.day -sticky ew
    grid $left.image -sticky ew
    grid $left.potdname -sticky ew
    grid $left.msg1 -sticky ew
    grid $left.msg2 -sticky ew
    grid $left.preview -sticky ew -pady {.3i 0}
    grid $left.shadows -sticky ew
    grid $left.scale -sticky ew
    grid $left.ini -sticky ew
    grid $left.quit -row 102 -pady .2i
    grid rowconfigure $left 100 -weight 1

    if {$S(img) eq "TBD"} {
        ::ttk::label $top.tbd -text "No Image\nLoaded" -just c -font $::bigger_bold_font
        place $top.tbd -in $body.img -relx .5 -rely .5 -anchor s
    }
}

proc ::Magic::URL {which} {
    # Copies various PotD urls to the clipboard
    global S

    global meta
    clipboard clear

    set key "${which}_url"
    set url ""
    if {[dict exists $meta $key]} {
        set url [dict get $meta $key]
        clipboard append $url
        Logger "Copying $which url to clipboard: $url"
        set S(magic,url1) "Copied"
        set S(magic,url2) "$which url"
    } elseif {$which eq "potdname" && $S(potd,current) ne ""} {
        clipboard append $S(potd,current)
        Logger "Copying PotD name to clipboard: $S(potd,current)"
        set S(magic,url1) "Copied"
        set S(magic,url2) "PotD name"
    } else {
        lassign [DecodePotDFilename $S(local,current)] status
        if {$which eq "potdname" && $status} {
            set tail [file tail $S(local,current)]
            clipboard append $tail
            Logger "Copying local PotD name to clipboard: $tail"
            set S(magic,url1) "Copied"
            set S(magic,url2) "PotD name"
        } else {
            clipboard append "Wikipedia url: Not PotD"
            set S(magic,url1) "Not PotD"
            set S(magic,url2) ""
        }
    }
    after 3000 {set ::S(magic,url1) [set ::S(magic,url2) ""]}
    if {$url ne "" && $S(potd,current) ne ""} {
        catch {LaunchBrowser $url}
    }
}
proc ::Magic::UpdateDifficultyDisplay {raw} {
    # Updates difficutly scale text on the magic dialog
    global S ST
    set idx [expr {round($raw)}]
    set text [lindex $S(difficulty,labels) $idx+2]

    if {$text eq $S(difficulty,pretty)} return
    set S(difficulty,pretty) $text

    set level [expr {int(round($ST(difficulty,raw)))}]
    SaveInifile
    ::Magic::InsertNewLevel $level
    Logger "Resizing to $S(difficulty,pretty) difficulty ($level)"
}
proc ::Magic::InsertNewLevel {level} {
    # Injects new difficulty level into our shape object
    if {$level != int($level)} {
        error "SQ(size,adjust) being set to a non-integer"
    }
    set ::Baseshape::base_SQ(size,adjust) $level
}
proc ::Magic::ChangeSize {} {
    # Redraws puzzle with new difficulty level
    global S ST

    set level [expr {int(round($ST(difficulty,raw)))}]
    ::Magic::InsertNewLevel $level
    if {$S(img) eq "TBD"} return
    set theme $S(theme)
    Logger "Resrambling $theme to $S(difficulty,pretty) difficulty ($level)"
    Restart $theme
}
proc ::Magic::ColorShadows {} {
    # Toggles between black & white borders and color borders
    global S ST

    set shadows [list white gray25]
    if {$ST(color,shadows)} {
        set shadows [list magenta springgreen2]
    }
    Logger "Setting shadows to $shadows"
    lassign $shadows ::Baseshape::base_SQ(color,shade1) ::Baseshape::base_SQ(color,shade2)
}
namespace eval ::Animate {
    variable ANIM
    set ANIM(step,size) 50
    set ANIM(step,delay) 10
}
proc ::Animate::AllTiles {} {
    # Animates placing tiles into their puzzle starting positions
    variable ANIM
    global G ST

    set ANIM(running) 0
    foreach tile [range $::Baseshape::SQ(n,total)] {
        set tag tile_$tile
        lassign [::Baseshape::Tile2XY $G($tile,isAt)] x1 y1
        set xy [::Animate::GetXYPath $tag $x1 $y1]

        incr ANIM(running)
        ::Animate::Go $tag $xy

    }
    if {$ANIM(running) > 0} {
        tkwait variable ::Animate::ANIM(done)
    }
}

proc ::Animate::GetXYPath {tag x1 y1} {
    # Gets path tile needs to traverse while being animated into starting position
    variable ANIM

    set x0 [expr {[winfo width .c] / 2}]
    set y0 0

    set vx [expr {$x1 - $x0}]
    set vy [expr {$y1 - $y0}]

    set steps [expr {int(hypot($vx,$vy) / $ANIM(step,size))}]
    set xy [list]
    foreach idx [range $steps] {
        set xx [expr {$x0 + $idx * $vx / $steps}]
        set yy [expr {$y0 + $idx * $vy / $steps}]
        lappend xy $xx $yy
    }
    lappend xy $x1 $y1
    return $xy
}

proc ::Animate::Go {tag xy} {
    # Does the animation for item $tag along path $xy
    variable ANIM

    set xy [lassign $xy xx yy]
    .c coords $tag $xx $yy
    .c raise $tag

    if {$xy ne {}} {
        after $ANIM(step,delay) [list ::Animate::Go $tag $xy]
    } else {
        incr ANIM(running) -1
        if {$ANIM(running) == 0} {
            set ANIM(done) 1
        }
    }
}

proc ErrorBox {msg details} {
    tk_messageBox -message $msg -detail $details -icon error -title $::S(title) -parent .
    exit 1
}
proc TimerDialog {} {
    # Dialog with puzzle timer plus some stats
    global STATS

    set top .timer
    destroy $top
    if {[winfo exists $top]} return

    set body [DialogTemplate Timer $top "Stats"]

    set timer $body.timer
    ::ttk::frame $timer -borderwidth 5 -relief ridge
    set totals $body.totals
    ::ttk::frame $totals -borderwidth 5 -relief ridge

    grid $timer -sticky news
    grid $totals -sticky news

    # Stopwatch section
    ::ttk::label $timer.title -text Timer \
        -anchor c -font $::bigger_bold_font2
    ::ttk::label $timer.stopwatch -textvariable STATS(pretty,time) \
        -anchor c -font $::biggest_bold_mono_font
    ::ttk::label $timer.lcount -text "Move Count" \
        -font $::bigger_font
    ::ttk::label $timer.vcount -textvariable STATS(count) \
        -font $::bigger_font
    ::ttk::label $timer.lbad -text "Bad Move Count" \
        -font $::bigger_font
    ::ttk::label $timer.vbad -textvariable STATS(bad) \
        -font $::bigger_font
    grid $timer.title - -sticky news
    grid $timer.stopwatch - -pady {0 .2i} -sticky news
    grid $timer.lcount $timer.lbad
    grid $timer.vcount $timer.vbad

    grid columnconfigure $timer {0 1} -weight 1
    grid rowconfigure $timer 100 -minsize .2i

    # Totals section
    ::ttk::label $totals.title -text Totals \
        -anchor c -font $::bigger_bold_font2
    grid $totals.title -columnspan 6 -sticky news
    foreach var {Local Wikipedia Commons Solved} {row col} {2 0  2 2  2 4  3 0} {
        set w1 $totals.l$var
        set w2 $totals.v$var
        ::ttk::label $w1 -text "$var:" -font $::bigger_font
        ::ttk::label $w2 -textvariable ::STATS(total,$var) -font $::bigger_font
        grid $w1 -row $row -column $col -sticky e
        grid $w2 -row $row -column [expr {$col + 1}] -sticky w
    }
    grid columnconfigure $totals all -weight 1

}

proc DescriptionDialog {show} {
    global S

    set top .desc
    if {! [winfo exists $top]} {
        set body [DialogTemplate Desc $top "PotD Descriptions"]
        wm title $top "$S(title) PotD Descriptions"
        wm protocol $top WM_DELETE_WINDOW [list wm withdraw $top]
        wm resizable [winfo toplevel $body] 1 1

        text $body.t -font $::text_font -wrap word
        pack $body.t -side top -fill both -expand 1
        $body.t insert end "Picture of the Day descriptions\n\n"
        # $body.t config -state disabled
    }
    if {$show} {
        wm deiconify $top
    } else {
        wm withdraw $top
    }
}
proc UpdateDescriptionDialog {source description} {
    # Adds description to the Description dialog text widget
    set t .desc.body.t
    if {$description ne ""} {
        $t config -state normal
        $t insert end $source\n
        $t insert end "\u2022 $description\n\n"
        $t see end
    }
}

proc Puzzle {} {
    # Toggles "puzzling" by obscuring 3 tiles
    global G S BB

    set text [expr {$BB(Puzzle) ? "Expert On" : "Expert Off"}]
    $BB(Puzzle,w) config -text $text

    if {$S(img) eq "TBD" || [IsSolved]} {
        set msg "Expert mode turned off"
        if {$BB(Puzzle)} {
            set msg "Expert mode turned on"
        }
        if {$S(img) eq "TBD"} {
            set msg "You need to open an image first"
        }
        ShowStatus "Expert Mode" $msg killafter=3000
        return
    }
    if {$BB(Puzzle) == 1} {
        $S(MOTIF) MakeQuestionTiles 3 $G(solved,tiles)
        Logger "Obscuring 3 tiles"
        ::Stars::MakeStars
    } else {
        $S(MOTIF) UnmakeQuestionTiles
        Logger "Clearing all tiles"
        ::Stars::UnMakeStars
    }
}
proc PuzzleAgain {} {
    # Called when we change puzzling pixelation flag
    global G S BB ST

    if {$BB(Puzzle) == 0 || $S(img) eq "TBD" || [IsSolved]} return
    $S(MOTIF) UnmakeQuestionTiles
    $S(MOTIF) MakeQuestionTiles 3 $G(solved,tiles)
    Logger "Puzzling 3 tiles with pixelated tiles"
}
proc Busy {onoff} {
    # Code to mark that the UI is busy, discarding all events until turned off
    if {! [winfo exists .__busy]} {
        toplevel .__busy
        wm geom .__busy +10000+10000
        wm withdraw .__busy
    }

    global BUSY
    if {$onoff} {
        incr BUSY(busy)
        if {$BUSY(busy) == 1} {
            grab .__busy
        }
    } else {
        incr BUSY(busy) -1
        if {$BUSY(busy) <= 0} {
            set BUSY(busy) 0
            grab release .__busy
        }
    }
}

proc ImageType {idata iname} {
    # Determines image type from content because url extension can be wrong
    if {$idata ne ""} {
        set prefix [string range $idata 0 7]
        if {$prefix eq "\x89PNG\r\n\x1a\n"} { return png }

        set prefix [string range $idata 0 2]
        if {$prefix eq "\xFF\xD8\xFF"} { return jpeg }

        set prefix [string toupper [string range $idata 0 5]]
        if {$prefix eq "GIF87A" || $prefix eq "GIF89A"} { return gif }

        error "unknown image format: $iname"
    }

    set ext [string tolower [file extension $iname]]
    if {$ext eq ".png"} { return png }
    if {$ext in {".jpg" ".jpeg"}} { return jpeg }
    if {$ext eq ".gif"} { return png ;# yes, png not gif -- bug: some frames have too many colors }
    return ""
}
namespace eval ::Favorites {
    variable POTDNAME
    variable TREE ""
    variable SORTED {}
    variable VISITED {}
}
proc ::Favorites::Dialog {} {
    variable TREE

    set top .favorites
    set body [DialogTemplate Favorites $top "Favorite PotD Images"]
    wm transient $top .
    wm resizable [winfo toplevel $body] 1 1
    ::Favorites::PlaceWindow

    set parent $body.upper
    destroy $parent
    ::ttk::frame $parent
    ::ttk::frame $body.buttons
    ::ttk::button $body.buttons.random -text "Pick Random" -command ::Favorites::Random
    ::ttk::button $body.buttons.add -text "Add Current" -command ::Favorites::Add
    grid rowconfigure $body 0 -weight 1
    grid columnconfigure $body 0 -weight 1
    grid $parent -sticky news
    grid $body.buttons -pady .25i -sticky news
    pack $body.buttons.random $body.buttons.add -side left -expand 1
    if {! $::S(filesystem,writable)} { destroy $body.buttons.add }

    set font [::ttk::style lookup [$parent cget -style] -font]
    set headers {"" Date Service Description}
    set hwidths [list [font measure $font "\u2714\u2714"] \
                 [font measure $font "December 31, 2023 xxxx"] \
                     [font measure $font "Wikipedia xx"] \
                     [font measure $font [string repeat "e" 70]]]
    set TREE [::ButtonListBox::Create $parent -headers $headers -widths $hwidths -banding 1]
    set cnt [::Favorites::FillIn $TREE]
    $TREE config -height [expr {min(30, $cnt)}]
    bind $TREE <<ButtonListBoxPress>> [list ::Favorites::ClickMe %d]
    ::Favorites::FixDescriptionSize $TREE
}

proc ::Favorites::FillIn {tree} {
    global FAVORITES

    foreach {potdname desc} $FAVORITES {
        ::Favorites::FillInSingle $tree $potdname $desc
    }
    return [expr {[llength $FAVORITES] / 2}]
}
proc ::Favorites::FillInSingle {tree potdname description} {
    variable POTDNAME
    variable VISITED

    set visited [expr {$potdname in $VISITED ? "\u2714" : " "}]
    lassign [DecodePotDFilename $potdname] status service year month day
    if {$status} {
        set month [clock format [clock scan "$year-$month-$day"] -format %B]
        set date "$month $day, $year"
    } else {
        set date [file tail $potdname]
    }
    if {[string match "/*" $potdname]} {
        set service "Local"
    }
    set id [::ButtonListBox::AddItem $tree [list $visited $date $service $description]]
    set POTDNAME($id) $potdname
    set POTDNAME($potdname) $id

    return $id
}
proc ::Favorites::ClickMe {id} {
    variable TREE
    variable POTDNAME

    set who $POTDNAME($id)
    $TREE selection set $id
    $TREE see $id
    ::Favorites::MarkVisited $id $who

    if {[string match "/*" $who] || [string match "./*" $who]} {
        GetLocalPicture False $who
    } else {
        _forcePotD $who
    }
    ::Favorites::PlaceWindow
}
proc ::Favorites::MarkVisited {id who} {
    variable TREE
    variable VISITED

    if {$who ni $VISITED} { lappend VISITED $who }

    set values [$TREE item $id -values]
    lset values 0 \u2714
    $TREE item $id -values $values
}
proc ::Favorites::PlaceWindow {} {
    set slave .favorites
    if {! [winfo exists $slave]} return
    set n [scan [wm geometry .] "%dx%d+%d+%d" width height x0 y0]
    if {$n != 4} return
    set x1 [expr {$x0 + $width + 5}]
    wm geometry $slave +$x1+$y0
}

proc ::Favorites::FixDescriptionSize {tree} {
    # We need this code to happen after the window has been drawn with the default size
    update
    set width [$tree column \#4 -width]
    set font [::ttk::style lookup [$tree cget -style] -font]
    foreach id [$tree children {}] {
        set description [lindex [$tree item $id -values] end]
        set needed_width [font measure $font $description]
        set width [expr {max($width, $needed_width)}]
    }
    $tree column \#4 -width $width
}
proc ::Favorites::Add {} {
    global S FAVORITES
    variable TREE
    variable SORTED {}

    if {! $S(filesystem,writable)} return

    set parent [expr {[winfo exists .favorites] ? ".favorites" : "."}]
    set potdname [expr {$S(potd,current) ne "" ? $S(potd,current) : $S(local,current)}]
    set desc $S(pretty,desc)

    if {$potdname eq ""} {
        set emsg "You need to open an image first"
        ShowStatus "Favorites Error" $emsg parent=$parent killafter=3000
        return
    }
    if {$potdname in $FAVORITES} {
        ShowStatus "Favorites" "Current image already in favorites" parent=$parent killafter=3000
        return
    }

    lappend FAVORITES $potdname $desc
    set fout [open $S(inifile,favorites) a]
    puts $fout "$potdname\t$desc"
    close $fout
    Logger "adding $potdname to favorites"
    if {[winfo exists $TREE]} {
        ShowStatus "Favorites" "Current image saved to favorites" parent=.favorites killafter=3000
        set id [::Favorites::FillInSingle $TREE $potdname $desc]
        $TREE see $id
    } else {
        ShowStatus "Favorites" "Current image saved to favorites" parent=. killafter=3000
    }
}
proc ::Favorites::ReadInifile {} {
    global S FAVORITES
    Logger "Loading favorites"
    set count 0
    if {! [file readable $S(inifile,favorites)]} return
    set fin [open $S(inifile,favorites) r]
    while {[gets $fin line] >= 0} {
        if {[string match "#*" $line]} continue
        if {! [string match "potd_*" $line] \
                && ! [string match "./*" $line] \
                && ! [string match "/*" $line]} {
            Logger "bad favorites line: '$line'"
            continue
        }
        set parts [split $line "\t"]
        if {[llength $parts] != 2} {
            Logger "bad favorites line: '$line'"
            continue
        }
        set potdname [string trim [lindex $parts 0]]
        set desc [string trim [lindex $parts 1]]
        lappend FAVORITES $potdname $desc
        incr count
    }
    close $fin
    Logger "Added $count favorites"
}
proc ::Favorites::Random {} {
    variable TREE
    variable SORTED
    variable POTDNAME

    if {$SORTED eq {}} {
        set all [lmap {x y} $::FAVORITES { if {[string match "/*" $x]} continue ; set x}]
        set SORTED [Shuffle $all]
    }
    set SORTED [lassign $SORTED potd]

    if {[info commands $TREE] eq ""} {
        _forcePotD $potd
    } else {
        set id $POTDNAME($potd)
        ::Favorites::ClickMe $id
    }
}

proc Shuffle {myList} {
    set len [llength $myList]
    while {$len} {
        set n [expr {int($len * rand())}]
        set tmp [lindex $myList $n]
        lset myList $n [lindex $myList [incr len -1]]
        lset myList $len $tmp
    }
    return $myList
}

proc CheckImageMagick {} {
    # Checks for having ImageMagick installed
    global S

    if {[::Baseshape::_HasImageMagick]} return
    if {! $S(filesystem,writable)} return
    if {$S(inside,zip)} return
    set url "https://imagemagick.org/script/download.php"

    set msg "INFO: Could not locate a copy of ImageMagick."
    set details "$S(title) will work fine without ImageMagick but with it "
    append details "will be faster and "
    append details "[llength $S(themes.cannot)] more tiling shapes are "
    append details "available: [join $S(themes.cannot) {, }].\n\n"
    append details "You can download ImageMagick from $url"

    tk_messageBox -icon info -type ok -message $msg -detail $details -title $S(title) -parent .
}
proc LoadInifile {} {
    global S ST

    if {! [file exists $::S(inifile,file)]} {
        Logger "No inifile $::S(inifile,file), skipping"
        return
    }
    Logger "Reading inifile $::S(inifile,file)"

    try {
        set fin [open $::S(inifile,file) r]
        set inidata [read $fin]
    } on error {emsg} {
        Logger "Error reading $::S(inifile,file): $emsg" emsg
        return
    } finally {
        if {[info exists fin]} { close $fin }
    }

    foreach line [split [string trim $inidata] "\n"] {
        if {[string match "#*" $line]} continue

        if {[regexp {^themes\s+(.*)} $line _ themes]} {
            set S(themes.start) $themes
            continue
        }
        if {[regexp {^geometry\s+(\d+)\s+(\d+)} $line _ x y]} {
            wm geom . +${x}+${y}
            continue
        }
        set n [regexp {^(\S+)\s+(\S+)\s*$} $line _ key value]
        set type [expr {$n && $key eq "difficulty,raw" ? "integer" : "boolean"}]
        if {$n && [info exists ST($key)] && [string is $type -strict $value]} {
            set ST($key) $value
        } else {
            Logger "bad inifile line: $line" emsg
        }
    }
    if {! [::Baseshape::_HasImageMagick]} {
        set ST(alwaysResize,onoff) 0
    }
}
proc SaveInifile {} {
    global S ST

    if {! $ST(inifile,onoff)} return
    if {! $S(filesystem,writable)} return

    set data "# Ini file for $S(title)\n"
    foreach key [lsort -nocase [array names ST]] {
        if {$key eq "last"} continue
        set value $ST($key)
        if {$key eq "difficulty,raw"} {
            set value [expr {int(round($value))}]
        }
        append data "$key $value\n"
    }
    scan [wm geom .] %dx%d+%d+%d _ _ x y
    append data "geometry $x $y\n"

    set themes [lsort [lmap {k v} [array get S themes,*] {
        if {! $v} continue ; string range $k 7 end}]]
    append data "themes $themes"

    if {$data eq $ST(last)} {
        Logger "Skipping saving inifile, no changes $::S(inifile,file)"
        return
    }
    Logger "Saving inifile $::S(inifile,file)"

    set fout [open $::S(inifile,file) w]
    try {
        set ST(last) $data
        puts $fout $data
    } on error {emgs} {
        Logger "Error writing $::S(inifile,file): $emsg" emsg
    } finally {
        close $fout
    }
}
proc main {} {
    global S

    foreach tinfo [trace info execution exit] {
        trace remove execution exit {*}$tinfo
    }
    trace add execution exit enter AtExit
    catch {trace add execution xx enter AtExit}

    CreateLogsDialog
    LoadShapes
    LoadInifile
    DoDisplay
    ::Magic::ColorShadows
    ::Favorites::ReadInifile

    set idir [expr {[file isdirectory images] ? "images" : "."}]
    BuildNextImageList $idir

    set S(local,images) [Shuffle $S(local,images)]
    set S(local,current) ""
    set S(pretty,source) ""

    set title "$S(title)"
    set subtitle "by Keith Vetter $S(creation,date)\nVerson $S(version)"
    set msg "Loading..."
    ShowStatus $title $msg button=None subtitle=$subtitle

    update
    ComputeBestSize

    ::POTD::SetLogger ::Logger

    set arrow "\u27a1"
    set msg ""
    append msg "To get started:\n"
    append msg "    $arrow Load image from Wikipedia PotD\n"
    append msg "    $arrow Load image from Commons PotD\n"
    append msg "    $arrow Grab an image from Favorites\n"
    append msg "    $arrow Open a local image"
    ShowStatus $title $msg button=Start subtitle=$subtitle

    CheckImageMagick
}
namespace eval ::Stars {
    variable STAR
    set STAR(count) 5
    set STAR(top,left) [list 39 40]
    set STAR(delta) 15
    set STAR(spacing) 35
    set STAR(config,on) "-width 1 -outline black -fill red"
    set STAR(config,off) "-fill white"
}
proc ::Stars::MakeStars {} {
    variable STAR
    .c delete stars
    lassign $STAR(top,left) x0 y0
    foreach id [range $STAR(count)] {
        set tag star_[expr {$STAR(count) - $id}]
        set x [expr {$x0 + $id * $STAR(spacing)}]
        set xy [::Stars::_XY $x $y0 $STAR(delta)]
        .c create poly $xy -tag [list stars $tag] {*}$STAR(config,on)
    }
    ::Stars::MarkBad
}
proc ::Stars::UnMakeStars {} {
    .c delete stars
}
proc ::Stars::MarkBad {} {
    variable STAR
    foreach id [range 1 $STAR(count)+1] {
        set tag star_$id
        set config $STAR(config,on)
        if {$id <= $::STATS(bad)} {
            set config $STAR(config,off)
        }
        .c itemconfig $tag {*}$config
    }
}
proc ::Stars::_XY {x y delta} {
    set pi [expr {acos(-1)}]

    # Compute distance to inner corner
    #set x1 [expr {$delta * cos(54 * $pi/180)}]  ;# Unit vector to inner point
    set y1 [expr {sin(54 * $pi/180)}]
    set y2 [expr {$delta * sin(18 * $pi/180)}]  ;# Y value to match
    set delta2 [expr {$y2 / $y1}]

    # Now get all coordinates of the 5 outer and 5 inner points
    for {set i 0} {$i < 10} {incr i} {
        set d [expr {($i % 2) == 0 ? $delta : $delta2}]
        set theta [expr {(90 + 36 * $i) * $pi / 180}]
        set x1 [expr {$x + $d * cos($theta)}]
        set y1 [expr {$y - $d * sin($theta)}]

        lappend coords $x1 $y1
    }
    return $coords
}
proc bird {what} {
    # Too many damn birds on Wikipedia PotD
    global S
    if {[regexp {^[a-z]+! } $S(pretty,desc)]} return

    Logger "Another $what $S(potd,current)"
    set S(pretty,desc) "$what! $S(pretty,desc)"
    set fname jsBirds.txt
    if {! [file exists $fname]} return
    catch {
        set fout [open $fname a]
        puts $fout "$S(potd,current)\t$what\t$S(potd,desc)"
        close $fout
    }
}
if {$S(beta)} {bind all <Control-b> {bird bird}}
if {$S(beta)} {bind all <Control-p> {bird portrait}}
if {$S(beta)} {bind all <Control-a> {bird animal}}

proc TallyMarks {solved} {
    global STATS

    set symbol_g \u2611
    set symbol_b \u2612
    set symbol_2 \u2731
    set symbol_S \u22ee
    set symbol_done "\u2764\ufe0f"

    set mapping [list G [list $symbol_g green] B [list $symbol_b red] 2 [list $symbol_2 green]]
    lappend mapping S [list $symbol_S black]
    set tuples [string map $mapping $STATS(playback)]
    if {$solved} {
        lappend tuples "  Solved!" magenta
    } elseif {[::Magic::IsForced]} {
        lappend tuples $symbol_done black
    }

    CanvasColoredString tallymarks 0 0 $::big_font $tuples
}
proc CanvasColoredString {tag x y font tuples} {
    # Draws text at x,y with given tag & font and tuples is list of {text color}
    .c delete $tag
    set x0 $x
    foreach {text color} $tuples {
        if {$text eq "\n"} {
            set x $x0
            incr y [font metrics $font -linespace]
            continue
        }
        .c create text $x $y -tag $tag -font $font -text $text -anchor nw -fill $color
        incr x [font measure $font $text]
    }
}
proc LaunchBrowser {url} {
    global tcl_platform

    if {$tcl_platform(platform) eq "windows"} {
        # first argument to "start" is "window title", which is not used here
        set command [list {*}[auto_execok start] {}]
        # (older) Windows shell would start a new command after &, so shell escape it with ^
        # set url [string map {& ^&} $url]
        # but 7+ don't seem to (?) so this nonsense is gone
        if {[file isdirectory $url]} {
            # if there is an executable named eg ${url}.exe, avoid opening that instead:
            set url [file nativename [file join $url .]]
        }
    } elseif {$tcl_platform(os) eq "Darwin"} {
        set command [list open]
    } else {
        set command [list xdg-open]
    }
    exec {*}$command $url &
}

################################################################
################################################################

# set color red
# ttk::style configure TFrame -background $color

main
