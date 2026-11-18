import QtQuick
import qs.config

// Text in the shell's font. The pixel font renders natively with full hinting (hard pixels), at a size on its
// grid (Style.px); any other font renders smooth.
Text {
    color: Colors.accent
    font.family: Style.font
    font.pixelSize: Style.text
    font.hintingPreference: Style.pixel ? Font.PreferFullHinting : Font.PreferDefaultHinting
    renderType: Style.pixel ? Text.NativeRendering : Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
