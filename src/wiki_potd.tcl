# Code downloaded from https://wiki.tcl-lang.org/page/Picture+of+the+Day on 2025-03-23 23:15:41

namespace eval ::POTD {}

set ::POTD::SUCCESS_STATUS 2
set ::POTD::day_url {}
set ::POTD::month_url {}
set ::POTD::ERROR_STATUS 0
set ::POTD::PEDIA_URL https://en.wikipedia.org/wiki/Wikipedia:Picture_of_the_day
set ::POTD::POTD_SERVICES {"Wikipedia" "Commons"}
set ::POTD::USER_LOGGER {}
set ::POTD::COMMONS_URL https://commons.wikimedia.org/wiki/Template:Potd
set ::POTD::NO_PICTURE_STATUS 1
set ::POTD::meta {}

proc ::POTD::RandomPOTD {service {fitness {}}} {
    # Gets POTD from Wikipedia or Wikimedia Commons for a random date

    lassign [::POTD::_RandomDate $service] year month day
    return [::POTD::GetPOTD $service $year $month $day $fitness]
}
proc ::POTD::_UrlHost {url} {
    # Extracts the host part of a URL

    set n [regexp {^https?://[^/]*} $url host]
    if {! $n} {
        ::POTD::_Error "Could not extract host part of '$url'"
    }
    return $host
}
proc ::POTD::_ExtractResolutions {day_url {html {}}} {
    # Extracts links to images at all resolutions possible
    # each entry is {width height url}, sorted by height

    # NB. fails on older pages with "No higher resolution available"
    # NB. if page has a 1x1 image, then that image has been deleted

    ::POTD::_Logger "Extracting all image sizes from day page"

    if {$html eq ""} {
        set html [::POTD::DownloadUrl $day_url]
    }
    set host [::POTD::_UrlHost $day_url]
    set n [catch {set dom [::dom parse -html $html]} emsg]
    if {$n} { set ::HTML $html ; ::POTD::_Error "Bad HTML: $emsg" }

    set xpath {//*[contains(@class,"mw-thumbnail-link")]}
    set a_nodes [$dom selectNodes $xpath]

    if {[llength $a_nodes] == 0} {
        return [::POTD::_ExtractSingleResolution $dom $host]
    }

    set all {}
    foreach a_node $a_nodes {
        set url [$a_node getAttribute href]
        set size [$a_node asText]
        set size [regsub -all "," $size ""]
        set n [regexp {(\d+)\s+.\s+(\d+)} $size . width height]
        if {! $n} { ::POTD::_Error "could not extract size from '$size'" }
        lappend all [list $width $height [::POTD::_FixUrl $url $host]]
    }
    set all [lsort -index 1 -integer $all]
    ::POTD::_Logger "Found [::POTD::_Plural [llength $all] size]"
    set sizes [lmap x $all { lassign $x w h; return -level 0 "${w}x$h"}]
    ::POTD::_Logger "$sizes"
    return $all
}
proc ::POTD::_lpick {llist} {
    # Selects random item from list
    set len [llength $llist]
    set idx [expr {int(rand() * $len)}]
    return [lindex $llist $idx]
}
proc ::POTD::_MakeValidHtml {html} {
    # As of March 2025, the Wikipedia html contains <source> and <track> tags
    # Technically they are void tags and do not need a closing tag,
    # but tdom throws an error if it sees an unclosed source or track tag.
    # As a fix, we turn <source src="...."> into <source src="..."/>

    regsub -all {(<source[^>]*?[^/])>} $html {\1/>} html
    regsub -all {(<track[^>]*?[^/])>} $html {\1/>} html
    return $html

    # regsub -all {<video.*?</video>} $html {<video></video>} html
    # regsub -all {<audio.*?</audio>} $html {<audio></audio>} html
    # regsub -all {<picture.*?</picture>} $html {<picture></picture>} html
    # return $html
}
proc ::POTD::_range {args} {
    # Akin to python's range command, except:
    # * accepts numbers of form a, a+b or a-b
    # * cannot handle downward ranges

    if {[llength $args] == 1} {
        lassign [concat 0 $args 1] lo hi step
    } elseif {[llength $args] == 2} {
        lassign [concat $args 1] lo hi step
    } elseif {[llength $args] == 3} {
        lassign $args lo hi step
    } else {
        error "Wrong number of arguments to ::POTD::_range: '$args'"
    }
    if {[regexp {^-?\d+[+-]\d+$} $lo]} { set lo [expr $lo] }
    if {[regexp {^-?\d+[+-]\d+$} $hi]} { set hi [expr $hi] }
    if {[regexp {^-?\d+[+-]\d+$} $step]} { set step [expr $step] }

    set result {}
    for {set idx $lo} {$idx < $hi} {incr idx $step} {
        lappend result $idx
    }
    return $result
}
proc ::POTD::SetLogger {func} {
    # Installs custom logger: a function which takes one argument: msg
    set ::POTD::USER_LOGGER $func
}
proc ::POTD::RandomImage {service fitness} {
    # Download from wikipedia's and commons' "Random" page and extract main image
    set service [string totitle $service]
    if {$service eq "Wikipedia"} {
        foreach cnt {1 2 3 4 5 6 7 9 LAST} {
            set wiki_url https://en.wikipedia.org/wiki/Special:Random
            set html [::POTD::DownloadUrl $wiki_url]
            set image_page_url [::POTD::_ExtractInfoBoxImage $html]
            if {$image_page_url ne ""} break
            ::POTD::_Logger "Random Wikipedia page had no images, trying again"
        }
        if {$cnt eq "LAST"} {
            ::POTD::_Logger "Failed finding random Wikipedia page with any images"
            return [list "" ""]
        }
        set redirect_url $::DOWNLOADED_URL
        set html [::POTD::DownloadUrl $image_page_url]
    } else {
        set commons_url https://commons.wikimedia.org/wiki/Special:Random/File
        set html [::POTD::DownloadUrl $commons_url]
        set redirect_url $::DOWNLOADED_URL
        set image_page_url $::DOWNLOADED_URL
    }

    set resolutions [::POTD::_ExtractResolutions $image_page_url]
    lassign [::POTD::_ExtractDescriptionDate $html] date desc

    set bestfit -1
    if {$fitness ne {}} {
        lassign $fitness maxWidth maxHeight
        set bestfit [::POTD::_BestFit $resolutions $maxWidth $maxHeight]
    }

    set meta [dict create date $date image_page_url $image_page_url desc $desc emsg ""  \
                  status $::POTD::SUCCESS_STATUS bestfit $bestfit service "Random $service" \
                  redirect_url $redirect_url]

    return [list $meta $resolutions]
}
proc ::POTD::_ExtractDayPage {month_url year month day} {
    # Scrape the potd template for the url to the correct day's image

    set date "$year/$month/$day"
    ::POTD::_Logger "Extracting day $day from monthly page"
    set html [::POTD::DownloadUrl $month_url]

    set n [catch {set dom [::dom parse -html $html]} emsg]
    if {$n} { set ::HTML $html ; ::POTD::_Error "Bad HTML: $emsg" }

    # Search for id with the day tag: usually id="$day"
    # Some POTD are multiple images, with id="$day/#"
    # Some POTD have leading 0: id="08"
    foreach xpath [list "//*\[@id='$day/1'\]" "//*\[@id='$day'\]" "//*\[@id='0$day'\]"] {
        set id_nodes [$dom selectNodes $xpath]
        if {$id_nodes ne {}} break
    }
    if {$id_nodes eq {}} {
        ::POTD::_Error "could not find id tag for image page for $date"
    }

    set id_node [lindex $id_nodes 0]
    if {[$id_node nodeName] eq "span" || [$id_node nextSibling] eq ""} {
        set id_node [$id_node parent]
    }

    set table [$id_node nextSibling]
    if {$table eq ""} {
        ::POTD::_Error "could not find day html for $date"
    }
    if {[$table nodeName] eq "style"} {
        set table [$table nextSibling]
    }
    if {[$table nodeName] eq "div"} {
        set table [$table selectNodes {.//table[1]}]
    }
    if {$table eq "" || [$table nodeName] ne "table"} {
        ::POTD::_Error "could not find table with img for $date"
    }

    set img [lindex [$table selectNodes {.//img}] 0]
    if {$img eq {}} {
        if {[$table selectNodes .//video] ne ""} {
            ::POTD::_Error "POTD for $date is a video"
        }
        if {[$table selectNodes {.//*[contains(text(),'File deleted')]}] ne ""} {
            ::POTD::_Error "POTD for $date has been deleted"
        }
        ::POTD::_Error "could not find img in old month page for $date"
    }
    set a_node [$img parent]
    if {[$a_node nodeName] ne "a"} { ::POTD::_Error "could not find <a> in old month page for $date" }
    set day_url [$a_node getAttribute href]
    set day_url [::POTD::_FixUrl $day_url [::POTD::_UrlHost $month_url]]

    # Get description if possible
    set desc "missing description"
    set fig_node [$table selectNodes .//figcaption\[1\]]
    if {$fig_node ne ""} {
        # Commons uses a <figcaption> node for the description
        set desc [$fig_node asText]
    } else {
        # Wikipedia: first <td> contains the image, second <td> description
        # except for some animations which is in the third <td>
        # Usually these <td> are in the same <tr> but sometimes not

        # set p_node [$table selectNodes {.//td[2]//p[1]}]
        set td_nodes [$table selectNodes .//td]
        if {[llength $td_nodes] >= 2} {
            set p_nodes [[lindex $td_nodes 1] selectNodes {.//p}]
            while {$p_nodes ne ""} {
                set desc [string trim [[lindex $p_nodes 0] asText]]
                if {$desc ne "View animation"} break
                set p_nodes [lrange $p_nodes 1 end]
            }
        }
    }
    return [list $day_url $desc]
}
proc ::POTD::_RandomDate {service} {
    # Picks a random date in the range of available POTD images

    # Wikimedia Commons starts 2004/11
    # Wikipedia starts 2004/4 with funky HTML until 2007

    scan [clock format [clock seconds] -format "%Y %m %d"] {%d %d %d} YEAR MONTH DAY
    if {$service eq "Wikipedia"} {
        set years [::POTD::_range 2007 $YEAR+1]
    } else {
        set years [::POTD::_range 2004 $YEAR+1]
    }
    set year [::POTD::_lpick $years]

    if {$year == 2004} {
        set months {11 12}
    } elseif {$year == $YEAR} {
        set months [::POTD::_range 1 $MONTH+1]
    } else {
        set months [::POTD::_range 1 12+1]
    }
    set month [::POTD::_lpick $months]

    if {$year == $YEAR && $month == $MONTH} {
        set days [::POTD::_range 1 $DAY+1]
    } elseif {$year == 2004 && $month == 5} {
        setg days [::POTD::_range 14 31+1]
    } elseif {$month eq 2} {
        set days [::POTD::_range 1 29]
    } elseif {$month in {4 6 9 11}} {
        set days [::POTD::_range 1 31]
    } else {
        set days [::POTD::_range 1 32]
    }
    set day [::POTD::_lpick $days]
    return [list $year $month $day]
}
proc ::POTD::_GetPOTD {service year month day {fitness {}}} {
    # First gets the month POTD page, then extracts the day POTD page,
    # then extracts all resolutions of the POTD image

    variable month_url
    variable day_url

    set service [string totitle $service]
    if {$service ni $::POTD::POTD_SERVICES} {
        ::POTD::_Error "Unknown service '$service', should be either $::POTD::POTD_SERVICES"
    }

    set date $year/$month/$day
    ::POTD::_Logger "Getting $service Picture of the Day for $date"

    if {$service eq "Commons"} {
        # Before 2011-07, the day id must be two digits long
        if {$year < 2011 || ($year == 2011 && $month < 7)} {
            set month_url [format "%s/%d-%02d#%02d" $::POTD::COMMONS_URL $year $month $day]
        } else {
            set month_url [format "%s/%d-%02d#%d" $::POTD::COMMONS_URL $year $month $day]
        }
    } else {
        set month_name [clock format [clock scan "2000-$month-24" -format %Y-%m-%d] -format %B]
        set month_url "${::POTD::PEDIA_URL}/${month_name}_$year#$day"
    }

    lassign [::POTD::_ExtractDayPage $month_url $year $month $day] day_url desc

    if {[file tail $day_url] eq "File:No_image.svg"} {
        set desc "No image available for $date"
        set meta [dict create date $date month_url $month_url day_url $day_url desc $desc \
                      status $::POTD::NO_PICTURE_STATUS bestfit -1 service $service emsg ""]
        return [list $meta {}]
    }

    set resolutions [::POTD::_ExtractResolutions $day_url]

    set bestfit -1
    if {$fitness ne {}} {
        lassign $fitness maxWidth maxHeight
        set bestfit [::POTD::_BestFit $resolutions $maxWidth $maxHeight]
    }

    set meta [dict create date $date month_url $month_url day_url $day_url desc $desc \
                  status $::POTD::SUCCESS_STATUS bestfit $bestfit service $service emsg ""]
    return [list $meta $resolutions]
}
proc ::POTD::_RemoveInvisibleText {node} {
    foreach attr {"display:none" "display: none"} {
        set xpath ".//*\[contains(@style,'$attr')\]"
        while {True} {
            set bad [$node selectNodes $xpath]
            if {$bad eq ""} break
            [lindex $bad 0] delete
        }
    }
    return $node
}
proc ::POTD::_BestFit {resolutions maxWidth maxHeight} {
    # Returns index of largest image smaller than maxHeight and maxWidth
    # resolutions: list [list width height url] [list width height url] ...]

    set best -1
    set size ""
    foreach item $resolutions idx [::POTD::_range [llength $resolutions]] {
        lassign $item width height url
        if {$maxWidth > 0 && $width > $maxWidth} break
        if {$maxHeight > 0 && $height > $maxHeight} break
        set best $idx
        set size "${width}x${height}"
    }
    ::POTD::_Logger "finding bestfit for ${maxWidth}x$maxHeight: $best $size"

    return $best
}
proc ::POTD::_ExtractSingleResolution {dom host} {
    # Some POTD only have a single resolution with a different HTML scheme
    set all {}

    set xpath {//*[@id='file']//img[1]}
    set img [$dom selectNodes $xpath]
    if {$img ne ""} {
        set url [$img getAttribute src]
        set width [$img getAttribute width]
        set height [$img getAttribute height]
        lappend all [list $width $height [::POTD::_FixUrl $url $host]]
    }
    return $all
}
proc ::POTD::_FixUrl {url host} {
    # Makes sure url has a host component
    if {[string match "//*" $url]} {
        set url [string cat "https:" $url]
    } elseif {[string match "/*" $url]} {
        set url [string cat $host $url]
    }
    return $url
}
proc ::POTD::_Error {msg} {
    # Logs then throws an error

    catch {::POTD::_Logger $msg}
    error $msg
}
proc ::POTD::_ExtractInfoBoxImage {html} {
    # On a random Wikipedia page, use the image in the infobox
    set n [catch {set dom [::dom parse -html $html]}]
    if {$n} { set ::HTML $html ; ::POTD::_Error "Bad HTML: $emsg" }

    # <td colspan="2" class="infobox-image">
    set infobox [$dom selectNodes {//td[contains(@class,"infobox-image")]/span/a}]
    if {$infobox eq ""} { return "" }
    set infobox [lindex $infobox 0]
    set href [$infobox getAttribute href]
    set url [string cat https://en.wikipedia.org $href]
    return $url
}
proc ::POTD::DownloadUrl {url} {
    # Downloads a given URL
    global DOWNLOADED_URL

    ::POTD::_Logger "downloading $url"
    for {set i 0} {$i < 10} {incr i} {
        set DOWNLOADED_URL $url
        set token [::http::geturl $url]
        set html [::http::data $token] ; list
        set ncode [::http::ncode $token]
        set meta [::http::meta $token]
        ::http::cleanup $token

        if {$ncode == 302} {
            set url [dict get $meta location]
            ::POTD::_Logger "Redirected to $url"
            continue
        }
        if {$ncode == 200} {
            set html [::POTD::_MakeValidHtml $html]
            return $html
        }
        ::POTD::_Error "failed to download $url"
    }
    ::POTD::_Error "failed to download $url, too many redirects"
}
proc ::POTD::_ExtractDescriptionDate {html} {
    # Extract description and date from the day page, the data on
    # the month page is typically better so this is a fall back.

    set n [catch {set dom [::dom parse -html $html]}]
    if {$n} { set ::HTML $html ; ::POTD::_Error "Bad HTML: $emsg" }

    lassign {"" ""} date desc
    set dateNode [$dom selectNodes {.//*[@id="fileinfotpl_date"]/following-sibling::*}]
    if {$dateNode ne {}} {
        ::POTD::_RemoveInvisibleText $dateNode
        set date [string trim [$dateNode asText]]
    }
    set descNode [$dom selectNodes {.//*[@id="fileinfotpl_desc"]/following-sibling::*}]
    if {$descNode ne {}} {
        ::POTD::_RemoveInvisibleText $descNode
        set desc [string trim [$descNode asText]]
    }
    return [list $date $desc]
}
proc ::POTD::_Plural {cnt single {multi {}}} {
    # Returns "1 dog" or "3 dogs"

    if {$cnt == 1} { return "$cnt $single" }
    if {$multi eq ""} { set multi "${single}s"}
    return "$cnt ${multi}"
}
proc ::POTD::_Logger {msg} {
    # Logs message to screen or to custom logger

    variable USER_LOGGER
    if {$USER_LOGGER ne ""} {
        catch {$USER_LOGGER $msg}
    }
}
proc ::POTD::GetPOTD {service year month day {fitness {}}} {
    # Gets POTD from Wikipedia or Wikimedia Commons for given date
    #  date range is 2004/11 - today
    #  fitness: optional tuple listing maxWidth and maxHeight,
    #           used to compute bestfit (see below in metadata)
    #
    # Returns two items:
    #   1. meta:
    #        service  : Wikipedia or Commons
    #        status   : 0 error, 1 no picture for this day, 2 success
    #        date     : YYYY/MM/DD
    #        desc     : description of the POTD
    #        month_url: url of the month POTD page
    #        day_url  : url of the specific day page
    #        bestfit  : if fitness given, index of the largest image smaller than fitness
    #        emsg     : error message if status == 0
    #   2. list of POTD image links {width height url}, sorted by increasing height
    #      maybe empty on days with no POTD

    variable month_url ""
    variable day_url ""
    variable meta [dict create]

    set n [catch {
        set results [::POTD::_GetPOTD $service $year $month $day $fitness]
    } emsg]

    if {$n} {
        set date $year/$month/$day
        set meta [dict create status $::POTD::ERROR_STATUS service $service \
                      date $date emsg $emsg month_url $month_url day_url $day_url  \
                      desc "" bestfit -1]
        return [list $meta {}]
    }
    return $results
}

if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {
}
