/* kOS slideshow */
import QtQuick 2.0;
import calamares.slideshow 1.0;
Presentation {
    id: presentation
    function nextSlide() { presentation.goToNextSlide(); }
    Timer { interval: 7500; running: true; repeat: true; onTriggered: nextSlide() }
    property string themeColor: "#86C8FF"
    property string shadowColor: "#06101f"
    property color panelColor: "#000000"
    Rectangle { anchors.fill: parent; color: "#0A1022"; z: -1 }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "1-reproductive-system.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t1.contentWidth+16; height: t1.contentHeight+16; anchors.horizontalCenter: t1.horizontalCenter; anchors.top: t1.top; anchors.topMargin: -8 }
        Text { id: t1; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Welcome to kOS</h1><br/><h2>An operating system built different.</h2>") }
    } }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "2-start-reproduction.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t2.contentWidth+16; height: t2.contentHeight+16; anchors.horizontalCenter: t2.horizontalCenter; anchors.top: t2.top; anchors.topMargin: -8 }
        Text { id: t2; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Runs your Windows apps</h1><br/><h2>Powered by Wine — your .exe files just work.</h2>") }
    } }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "3-its-your-system.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t3.contentWidth+16; height: t3.contentHeight+16; anchors.horizontalCenter: t3.horizontalCenter; anchors.top: t3.top; anchors.topMargin: -8 }
        Text { id: t3; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Plays nice with Apple</h1><br/><h2>Opens your iPhone photos and Mac files out of the box.</h2>") }
    } }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "4-eggs-presentation.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t4.contentWidth+16; height: t4.contentHeight+16; anchors.horizontalCenter: t4.horizontalCenter; anchors.top: t4.top; anchors.topMargin: -8 }
        Text { id: t4; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Security toolkit built in</h1><br/><h2>nmap, Wireshark, Burp Suite, Ghidra and the Kali tools.</h2>") }
    } }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "5-wait-hatching.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t5.contentWidth+16; height: t5.contentHeight+16; anchors.horizontalCenter: t5.horizontalCenter; anchors.top: t5.top; anchors.topMargin: -8 }
        Text { id: t5; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Installing kOS...</h1><br/><h3>Sit tight — your system is being set up.</h3>") }
    } }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "6-follow-penguins.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t6.contentWidth+16; height: t6.contentHeight+16; anchors.horizontalCenter: t6.horizontalCenter; anchors.top: t6.top; anchors.topMargin: -8 }
        Text { id: t6; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Stay in the loop</h1><br/><h3>kOS lets you know when there's news.</h3>") }
    } }

    Slide { Item { anchors.centerIn: parent
        width: Math.min(parent.width, parent.height*(810.0/485.0)); height: Math.min(parent.height, parent.width/(810.0/485.0))
        Image { source: "7-created-by.png"; anchors.fill: parent }
        Rectangle { color: panelColor; opacity: 0.45; radius: 8; width: t7.contentWidth+16; height: t7.contentHeight+16; anchors.horizontalCenter: t7.horizontalCenter; anchors.top: t7.top; anchors.topMargin: -8 }
        Text { id: t7; font.family: "Helvetica"; font.pixelSize: 22; font.bold: true; color: themeColor; style: Text.Outline; styleColor: shadowColor; anchors.centerIn: parent; wrapMode: Text.WordWrap; width: parent.width*0.9; horizontalAlignment: Text.Center; textFormat: Text.RichText
            text: qsTr("<h1>Made by Kai</h1><br/><h2>Thanks for trying kOS!</h2>") }
    } }

    function onActivate() { presentation.currentSlide = 0; }
}
