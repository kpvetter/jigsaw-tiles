##+##########################################################################
#
# ::ShadowBorder::MakeShadowPhoto -- creates an image with a shadow border
# see http://wiki.tcl.tk/ShadowPhoto
#
namespace eval ::ShadowBorder {}

package require Tk

proc ::ShadowBorder::MakeShadowPhoto {imgSrc imgDst} {
    ::ShadowBorder::_MakeBorderImages
    set w [image width $imgSrc]
    set h [image height $imgSrc]

    set depth [image width ::img::border::TR]

    set w1 [expr {$w + $depth}]
    set w2 [expr {$w + 2 * $depth}]
    set h1 [expr {$h + $depth}]
    set h2 [expr {$h + 2 * $depth}]

    set imgTmp [image create photo -width $w2 -height $h2]
    $imgTmp copy ::img::border::TL
    $imgTmp copy ::img::border::T -to $depth 0 $w1 $depth
    $imgTmp copy ::img::border::TR -to $w1 0
    $imgTmp copy ::img::border::L -to 0 $depth $depth $h1
    $imgTmp copy ::img::border::R -to $w1 $depth $w2 $h1
    $imgTmp copy ::img::border::BL -to 0 $h1
    $imgTmp copy ::img::border::B -to $depth $h1 $w1 $h2
    $imgTmp copy ::img::border::BR -to $w1 $h1
    $imgTmp copy $imgSrc -to $depth $depth

    if {$imgDst in [image names]} { image delete $imgDst }
    image create photo $imgDst -width $w2 -height $h2
    $imgDst copy $imgTmp
    image delete $imgTmp

    return $imgDst
}

##+##########################################################################
#
# ::ShadowBorder::_MakeBorderImages -- makes 8 images which forming the shadow
# gradient for the four sides and four corners.
#
proc ::ShadowBorder::_MakeBorderImages {{depth 25}} {
    if {[info commands ::img::border::T] ne ""} return

    set gradient {\#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#8d8d8d \#999999
        \#a6a6a6 \#b2b2b2 \#bebebe \#c8c8c8 \#d0d0d0 \#dadada \#e2e2e2 \#e8e8e8
        \#eeeeee \#f2f2f2 \#f7f7f7 \#fcfcfc \#fdfdfd \#fdfdfd \#ffffff \#ffffff
        \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff
        \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff}

    # set depth 25

    image create photo ::img::border::T -width 1 -height $depth
    image create photo ::img::border::B -width 1 -height $depth
    image create photo ::img::border::L -width $depth -height 1
    image create photo ::img::border::R -width $depth -height 1
    image create photo ::img::border::TR -width $depth -height $depth
    image create photo ::img::border::TL -width $depth -height $depth
    image create photo ::img::border::BR -width $depth -height $depth
    image create photo ::img::border::BL -width $depth -height $depth

    for {set x 0} {$x < $depth} {incr x} {
        ::img::border::B put [lindex $gradient $x] -to 0 $x
        ::img::border::R put [lindex $gradient $x] -to $x 0

        for {set y 0} {$y < $depth} {incr y} {
            set idx [expr {$x<5&& $y<5 ? 0 : round(hypot($x,$y))}]
            ::img::border::BR put [lindex $gradient $idx] -to $x $y
        }
    }
    ::img::border::TL copy ::img::border::BR -subsample -1 -1
    ::img::border::TR copy ::img::border::BR -subsample 1 -1
    ::img::border::BL copy ::img::border::BR -subsample -1 1

    ::img::border::L copy ::img::border::R -subsample -1 1
    ::img::border::T copy ::img::border::B -subsample 1 -1
}

if {[info exists argv0] && [file tail [info script]] eq [file tail $argv0]} {
    image create photo ::img::icon -data {
        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}

    ::ShadowBorder::MakeShadowPhoto ::img::icon ::img::shadowed

    label .img1 -image ::img::icon -bd 2 -relief solid -text "Without shadow" -compound top
    label .img2 -image ::img::shadowed -bd 2 -relief solid -text "With shadow" -compound top
    pack .img1 .img2 -side top

}
