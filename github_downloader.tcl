#!/bin/sh
# Restart with tcl: -*- mode: tcl; tab-width: 8; -*- \
exec tclsh $0 ${1+"$@"} & \
exit

##+##########################################################################
#
# github_downloader.tcl -- Automatically download a github zip file
# by Keith Vetter 2025-04-01
#

package require Tk
package require vfs::zip
package require http
package require tls
http::register https 443 [list ::tls::socket -tls1 1]
package require uri

set github_url https://github.com/kpvetter/jigsaw-tiles/archive/refs/heads/main.zip
set zipMainFile jigsaw-tiles-main/jsTiles.tcl


proc DownloadGithubZip {github_url} {
    # Downloads a given URL

    set token [geturl_followRedirects $github_url]

    set code [::http::ncode $token]
    set data [::http::data $token] ; list
    ::http::cleanup $token

    if {$code != 200} {
        puts stderr "ERROR: wrong http code ($code) downloading $github_url"
        exit 1
    }
    return $data
}

proc SaveGithubZip {data} {
    # Saves data into a temporary file and returns that filename
    close [file tempfile tmpZipFile kpv.zip]

    set fout [open $tmpZipFile wb]
    puts -nonewline $fout $data
    close $fout

    return $tmpZipFile
}

proc geturl_followRedirects {url args} {
    # Calls http::geturl while following redirects

    array set URI [::uri::split $url] ;# Need host info from here
    set maxTries 10
    while {[incr maxTries -1] >= 0} {
        set token [http::geturl $url {*}$args]
        if {![string match {30[1237]} [::http::ncode $token]]} {return $token}
        array set meta [set ${token}(meta)]
        if {![info exist meta(Location)]} {
            return $token
        }
        http::reset $token

        array set uri [::uri::split $meta(Location)]
        unset meta
        if {$uri(host) == ""} { set uri(host) $URI(host) }
        # problem w/ relative versus absolute paths
        set url [eval ::uri::join [array get uri]]
    }
}
proc Popup {title msg} {
    set bigger_bold_font [concat [font actual TkDefaultFont] -size 48 -weight bold]
    set big_font [concat [font actual TkDefaultFont] -size 24]

    destroy .pop
    toplevel .pop
    wm withdraw .pop
    wm overrideredirect .pop 1

    ::ttk::frame .pop.f -padding .3i -borderwidth 3 -relief solid
    pack .pop.f -side left -fill both -expand 1
    ::ttk::label .pop.f.title -text $title -font $bigger_bold_font
    ::ttk::label .pop.f.msg -text $msg -anchor c -justify c -font $big_font
    grid .pop.f.title -pady {0 .2i}
    grid .pop.f.msg

    update
    set x [expr {[winfo screenwidth .] / 2 - [winfo reqwidth .pop] / 2}]
    wm geom .pop +$x+200
    wm deiconify .pop
    update
    raise .pop
}

################################################################
################################################################

wm withdraw .

set title "Jigsaw Tiles Downloader"
set msg "Downloading and expanding\nJigsaw Tiles from github"
Popup $title $msg

if {$tcl_interactive} return

set data [DownloadGithubZip $github_url] ; list
set tmpZipFile [SaveGithubZip $data]
destroy .pop

try {
    set zipVFS [::vfs::zip::Mount [file normalize $tmpZipFile] /__zip]
    cd /__zip/[file dirname $zipMainFile]/
    wm deiconify .

    set S(inside,zip) 1
    source [file tail $zipMainFile]
} finally {
    catch {file delete $tmpZipFile}
    catch {::vfs::zip::Unmount $zipVFS /__zip}
}

return
