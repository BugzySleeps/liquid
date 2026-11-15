import QtQuick
import qs.config

// Text in the pixel font: rendered natively with full hinting (hard pixels), at a size on its grid (Style.px).
Text {
    color: Colors.accent
    font.family: Style.font
    font.pixelSize: Style.text
    font.hintingPreference: Font.PreferFullHinting
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
