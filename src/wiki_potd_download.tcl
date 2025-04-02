namespace eval ::WikiPotD {
    # Code to fetch from tcler's Wiki "Picture of the Day" code

    variable url https://wiki.tcl-lang.org/page/Picture+of+the+Day
    variable fname wiki_potd.tcl
    variable fname_download wiki_potd_download.tcl
}

proc ::WikiPotD::Load {} {
    # Loads WikiPotD either locally or from the tcler's Wiki
    variable fname
    variable fname_download
    variable url

    set fullname [::WikiPotD::_Search $fname]
    if {$fullname eq ""} {
        set fullname [::WikiPotD::_Search $fname_download]
    }
    if {$fullname ne ""} {
        Logger "Loading Wiki PotD module from [file tail $fullname]"
        source $fullname
        return
    }
    set msg "Module Wiki PotD not found"
    set details "It can be found at $url\n\n"
    append details "Do you want to download and install it (safely) from the web?"

    set resp [tk_messageBox -message $msg -detail $details -icon question \
                  -title "Wiki PotD Demo" -type yesno -parent .]
    if {$resp ne "yes"} {
        puts stderr "Download module Wiki PotD from $url"
        exit 1
    }

    set code [::WikiPotD::_Fetch] ; list
    set potd_code [::WikiPotD::_SafeLoadCode $code]
    ::WikiPotD::_Save $potd_code
}
proc ::WikiPotD::_Save {potd_code} {
    # Optionally save our downloaded code to avoid having to re-download it
    variable fname_download
    variable url

    set msg "Module Wiki PotD successfully downloaded"
    set details "Save the downloaded code as $fname_download?"

    set resp [tk_messageBox -message $msg -detail $details -icon question \
                  -title "Wiki PotD Demo" -type yesno -parent .]
    if {$resp ne "yes"} {
        Logger "Not saving Wiki PotD code"
        return
    }
    Logger "Saving Wiki PotD code to $fname_download"
    set fout [open $fname_download "w"]
    puts $fout $potd_code
    close $fout
}
proc ::WikiPotD::_Search {fname} {
    # Tries to find WikiPotD code locally

    Logger "Searching for Wiki PotD module $fname"
    set dirs [list [file dirname [file normalize $::argv0]] . ..]
    foreach dir $dirs {
        set fullname [file join $dir $fname]
        if {[file exists $fullname]} { return $fullname }
    }
    return ""
}

proc ::WikiPotD::_Fetch {} {
    # Downloads the WikiPotD code from the tcler's Wiki
    variable url

    set html [::WikiPotD::_DownloadUrl $url]
    set code [::WikiPotD::_ExtractCode $html]
    return $code

}
proc ::WikiPotD::_DownloadUrl {url} {
    # Downloads a given URL

    Logger "Fetching tcler's Wiki page for Picture of the Day"
    set token [::http::geturl $url]
    set html [::http::data $token]
    set ncode [::http::ncode $token]
    ::http::cleanup $token

    if {$ncode != 200} {
        ErrorBox "Error Installing Wiki POTD" "Failed to download $url with code $ncode"
    }
    return $html
}
proc ::WikiPotD::_ExtractCode {html {index 1}} {
    # Scrapes the WikiPotD code from the html downloaded from the tcler's Wiki
    set n [catch {set dom [::dom parse -html $html]} emsg]
    if {$n} {ErrorBox "Error Installing Wiki POTD" "Bad HTML: $emsg" }

    Logger "Scraping Wiki page for code section"
    set xpath {//pre[contains(@class, "sh_sourceCode")]}
    set code_nodes [$dom selectNodes $xpath]

    set cnt [llength $code_nodes]
    if {$cnt == 0} {
        ErrorBox "Error Installing Wiki POTD" "Scraping error: No code sections found"
    }
    set code [[lindex $code_nodes $index-1] asText]
    return $code
}
proc ::WikiPotD::_SafeLoadCode {code} {
    # Evaluates $code in a safe interpreter then extracts the good stuff
    # One step safer than running arbitrary code

    variable url

    set in [interp create -safe]
    interp expose $in source
    interp eval $in { proc package {args} {} }
    interp eval $in { namespace eval ::http {} }
    interp eval $in { proc ::http::register {args} {} }
    interp eval $in [list eval $code]

    set when [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set faux_code "# Code downloaded from $url on $when\n\n"

    namespace eval ::POTD {}
    append faux_code "namespace eval ::POTD {}\n\n"

    set vars [interp eval $in {info vars ::POTD::* }]
    foreach var $vars {
        # If any var is an array then this code breaks
        set value [interp eval $in [list set $var]]
        set $var $value

        append faux_code [list set $var $value] "\n"
        # puts "set $var $value"
    }
    append faux_code "\n"
    set funcs [interp eval $in {info procs ::POTD::* }]
    foreach pname $funcs {
        set func [::WikiPotD::_CopyProc $in $pname]
        append faux_code $func "\n"
        # puts "CopyProc \$in $pname"
    }

    interp delete $in
    return $faux_code
}
proc ::WikiPotD::_CopyProc {in pname} {
    # Helper function to copy a function from safe interpreter $in

    set args {}
    foreach arg [interp eval $in info args $pname] {
        if {[interp eval $in info default $pname $arg _default_]} {
            set default [interp eval $in set _default_]
            lappend args [list $arg $default]
        } else {
            lappend args $arg
        }
    }
    set body [interp eval $in info body $pname]
    uplevel "#0" [list proc $pname $args $body]
    return "[list proc $pname $args $body]"
}
