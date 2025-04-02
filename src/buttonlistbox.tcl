##+##########################################################################
#
# buttonlistbox.tcl -- creates a list box with play buttons
# by Keith Vetter 2025-03-25
#

namespace eval ::ButtonListBox {
    package require Tk
    variable CONFIG
    variable DEFAULT
    array set DEFAULT {
        headers {}
        widths {}
        banding 0
        buttonText \u25b6\uFE0F
        color,0 white color,1 \#aaffff
    }
    # NB. buttonText is a unicode character for a play button
}

##+##########################################################################
#
# ::ButtonListBox::Create -- Creates and packs a new tile table widget
# into a parent frame.
#
proc ::ButtonListBox::Create {parent args} {
    variable CONFIG

    set w $parent.tree
    ::ButtonListBox::_ParseArgs $w $args

    set font [::ttk::style lookup Treeview -font]
    # ttk::style configure Treeview \
    #     -rowheight 24 ;# [expr {[font metrics $font -linespace] + 2}]

    ::ttk::treeview $w -columns $CONFIG($w,headers) -selectmode browse \
        -yscroll "$parent.vsb set" -xscroll "$parent.hsb set"
    scrollbar $parent.vsb -orient vertical -command "$w yview"
    scrollbar $parent.hsb -orient horizontal -command "$w xview"

    # Set up headings and widths
    foreach col $CONFIG($w,headers) hSize $CONFIG($w,widths) {
        $w heading $col -text $col -anchor c \
            -image ::bitmap::arrowBlank \
            -command [list ::ButtonListBox::_SortBy $w $col 0]
        if {[string is integer -strict $hSize]} {
            $w column $col -width $hSize
        } else {
            if {$hSize eq ""} { set hSize $col }
            set width [font measure $font [string cat $hSize $hSize]]
            $w column $col -width $width
        }
        $w column $col -stretch 0
    }
    $w column \#0 -width 45 -stretch 0
    $w heading \#3 -anchor w

    #bind $w <<TreeviewSelect>> {set ::id [%W selection]} ;# Debugging
    bind $w <1> [list ::ButtonListBox::_ButtonPress %W %x %y single]
    bind $w <Double-Button-1> [list ::ButtonListBox::_ButtonPress %W %x %y double]

    grid $w $parent.vsb -sticky nsew
    grid $parent.hsb          -sticky nsew
    grid column $parent 0 -weight 1
    grid row    $parent 0 -weight 1

    return $w
}
proc ::ButtonListBox::_ParseArgs {widget myargs} {
    variable CONFIG
    variable DEFAULT
    foreach {key value} [array get DEFAULT] {
        set CONFIG($widget,$key) $value
    }

    foreach {key value} $myargs {
        set key2 [string range $key 1 end]
        if {[string index $key 0] ne "-" || $key2 ni [array names DEFAULT]} {
            error "unknown option $key"
        }
        if {$value eq {}} { error "missing value for $key" }
        set CONFIG($widget,$key2) $value
    }
}
proc ::ButtonListBox::AddItem {w itemData} {
    variable CONFIG
    set id [$w insert {} end -text $CONFIG($w,buttonText) -values $itemData]
    $w item $id -tags $id ;# For banding
    ::ButtonListBox::_BandTable $w
    return $id
}
##+##########################################################################
#
# ::ButtonListBox::Clear -- Deletes all items
#
proc ::ButtonListBox::Clear {w} {
    $w delete [$w child {}]
}
##+##########################################################################
#
# ::ButtonListBox::_SortBy -- Code to sort tree content when clicked on a header
#
proc ::ButtonListBox::_SortBy {tree col direction} {
    # Build something we can sort

    if {$col eq "Date" && [array names ::Favorites::POTDNAME] ne {}} {
        set sortData [lmap id [$tree children {}] {list $::Favorites::POTDNAME($id) $id}]
    } else {
        set sortData [lmap id [$tree children {}] {list [$tree set $id $col] $id}]
    }
    set dir [expr {$direction ? "-decreasing" : "-increasing"}]
    set sortedData [lsort -dictionary -index 0 $dir $sortData]

    # Now reshuffle the rows into the sorted order
    set r -1
    foreach rinfo $sortedData {
        incr r
        $tree move [lindex $rinfo 1] {} $r
    }
    $tree see [lindex $sortedData 0 1]

    # Switch the heading command so that it will sort in the opposite direction
    set cmd [list ::ButtonListBox::_SortBy $tree $col [expr {!$direction}]]
    $tree heading $col -command $cmd

    ::ButtonListBox::_BandTable $tree
    ::ButtonListBox::_ArrowHeadings $tree $col $direction
}
##+##########################################################################
#
# ::ButtonListBox::_ArrowHeadings -- Puts in up/down arrows to show sorting
#
proc ::ButtonListBox::_ArrowHeadings {tree sortCol dir} {
    set idx -1
    foreach col [$tree cget -columns] {
        incr idx
        set img ::bitmap::arrowBlank
        if {$col == $sortCol} {
            set img ::bitmap::arrow($dir)
        }
        $tree heading $idx -image $img
    }
    set img ::bitmap::arrowBlank
    if {$sortCol eq "\#0"} {
        set img ::bitmap::arrow($dir)
    }
    $tree heading "\#0" -image $img
}
##+##########################################################################
#
# ::ButtonListBox::_BandTable -- Draws bands on our table
#
proc ::ButtonListBox::_BandTable {tree} {
    variable CONFIG
    if {! $CONFIG($tree,banding)} return

    set banding_id 0
    foreach row_id [$tree children {}] {
        set banding_id [expr {! $banding_id}]
        set tag [$tree item $row_id -tag]
        $tree tag configure $tag -background $CONFIG($tree,color,$banding_id)
    }
}
##+##########################################################################
#
# ::ButtonListBox::_ButtonPress -- handles mouse click which can
#  toggle checkbutton, control selection or resize headings.
#
proc ::ButtonListBox::_ButtonPress {w x y how} {
    lassign [$w identify $x $y] what id detail

    # Disable resizing heading #0
    if {$what eq "separator" && $id eq "\#0"} {
        return -code break
    }
    if {$what eq "item"} {
        event generate $w <<ButtonListBoxPress>> -data $id
        return -code break
    }
}


if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {
    "proc" ClickMe {who} {
        puts "$who was pressed"
    }

    destroy {*}[winfo children .]
    set parent [::ttk::frame .f]
    pack $parent -fill both -expand 1

    set font [::ttk::style lookup [$parent cget -style] -font]
    set headers {Date Service Description}
    set hwidths [list [font measure $font "December 31, 2023 xxxx"] \
                     [font measure $font "Wikipedia xx"] \
                     [font measure $font [string repeat "e" 70]]]
    set TREE [::ButtonListBox::Create $parent -headers $headers -widths $hwidths -banding 1]
    bind $TREE <<ButtonListBoxPress>> [list ClickMe %d]

    set low [clock scan "10 years ago"]
    set now [clock scan now]

    for {set i 1} {$i < 20} {incr i} {
        set when [expr {int($low + ($now - $low) * rand())}]
        set date [clock format $when -format "%B %d, %Y"]
        set service [expr {rand() < .5 ? "Wikipedia" : "Commons"}]
        set desc "Description for item $i"

        set id [::ButtonListBox::AddItem $TREE [list $date $service $desc]]
    }

}
