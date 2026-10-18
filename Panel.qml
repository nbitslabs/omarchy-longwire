import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// longwire in the Omarchy bar: the connection to longwire.ai at a glance,
// and — on a machine nobody has added yet — the pairing code, with a one
// click "add in browser" that opens the claim page with the code filled in.
Panel {
  id: root
  moduleName: "nbitslabs.longwire"
  ipcTarget: "nbitslabs.longwire"
  manageIpc: false

  property int cursorIndex: 0
  property bool cursorActive: false
  property double nowMs: Date.now()

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color accent: Commons.Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var actions: Model.actions(longwire.state, longwire.status, longwire.pinnedVersion)
  readonly property bool live: Model.isLive(longwire.state)
  readonly property bool attention: Model.needsAttention(longwire.state)
  readonly property bool paired: Model.machineName(longwire.status) !== ""
  readonly property color barIconColor: live || attention ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property color packetColor: live ? accent : (attention ? urgent : Qt.darker(barForeground, 1.55))

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    nowMs = Date.now()
    panelFlick.contentY = 0
    longwire.refresh()
    if (longwire.status === null) longwire.probeInstalled()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onActionsChanged: if (cursorIndex >= actions.length) cursorIndex = Math.max(0, actions.length - 1)

  function moveCursor(dy) {
    if (actions.length === 0) return
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(actions.length - 1, cursorIndex + dy))
  }

  function activate(index) {
    if (index < 0 || index >= actions.length) return
    longwire.run(actions[index].id)
    // Leaving for the browser: get out of the way.
    var id = actions[index].id
    if (id === "openPairing" || id === "openChat" || id === "openDashboard" || id === "install" || id === "update") root.close()
  }

  Service {
    id: longwire
  }

  // The pairing code's countdown and "connected for" only need minute
  // precision, and only while someone is looking.
  Timer {
    interval: 15000
    repeat: true
    running: root.opened
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { longwire.refresh(); return "ok" }
    function status(): string { return longwire.state + ": " + longwire.headline }
    function code(): string { return longwire.pairingCode }
    function pair(): string { longwire.openPairing(); return longwire.pairingURL }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "longwire · " + longwire.headline
    iconComponent: Component {
      Item {
        LongwireMark {
          anchors.centerIn: parent
          size: Style.space(15)
          color: root.barIconColor
          packetColor: root.packetColor
        }
      }
    }
    onPressed: function(buttonCode) {
      // Right click is the shortcut for whatever the machine needs next.
      if (buttonCode === Qt.RightButton) {
        if (longwire.state === "pairing") longwire.openPairing()
        else if (root.live) longwire.openDashboard()
        else root.toggle()
      } else if (buttonCode === Qt.MiddleButton) {
        longwire.refresh()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activate(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var k = String(t).toLowerCase()
        if (k === "r") longwire.refresh()
        else if (k === "o") root.activate(0)
        else if (k === "c" && longwire.pairingCode !== "") longwire.copyCode()
        else if (k === "d" && root.paired) { longwire.openDashboard(); root.close() }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "longwire"
            meta: longwire.headline
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.live || root.attention ? 1.0 : 0.6
            iconComponent: Component {
              LongwireMark {
                size: Style.font.display * 1.25
                color: root.foreground
                packetColor: root.live ? root.accent : (root.attention ? root.urgent : root.dim)
                pulse: root.opened && (longwire.state === "pairing" || longwire.state === "connecting" || longwire.state === "reconnecting")
              }
            }
          }

          // Pairing: the code is the hero of this state.
          Column {
            visible: longwire.state === "pairing"
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "Add this machine"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Rectangle {
              width: parent.width
              height: codeText.implicitHeight + Style.space(22)
              radius: Style.space(6)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: 1
              border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)

              Text {
                id: codeText
                anchors.centerIn: parent
                width: parent.width - Style.space(16)
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: longwire.pairingCode
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading * 1.25
                font.bold: true
                font.letterSpacing: 1
                elide: Text.ElideRight
              }
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: Model.codeExpiryText(longwire.status, root.nowMs)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            visible: longwire.actionStatus !== "" || ((longwire.state === "reconnecting" || longwire.state === "pairingOffline") && String((longwire.status && longwire.status.last_error) || "") !== "")
            width: parent.width
            textFormat: Text.PlainText
            text: longwire.actionStatus !== "" ? longwire.actionStatus : String((longwire.status && longwire.status.last_error) || "")
            color: longwire.actionStatus !== "" ? root.dim : root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
          }

          // Paired: what this machine is and how it's connected.
          Column {
            visible: root.paired && longwire.state !== "pairing"
            width: parent.width
            spacing: Style.spacing.labelGap

            InfoPair { label: "Machine"; value: Model.machineName(longwire.status) }
            InfoPair { label: "Server"; value: Model.hostOf(longwire.server) }
            InfoPair {
              visible: root.live
              label: "Connected for"
              value: Model.sinceText(longwire.status ? longwire.status.since : "", root.nowMs)
            }
            InfoPair { label: "Engines"; value: Model.engineSummary(longwire.status); visible: longwire.status !== null && longwire.state !== "stopped" }
            InfoPair {
              label: "longwire"
              value: longwire.status ? String(longwire.status.version || "") + (longwire.status.auto_update ? " · updates automatically" : "") : ""
            }
          }

          Column {
            visible: root.actions.length > 0
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.actions
              ActionRow {
                required property var modelData
                required property int index
                width: parent.width
                action: modelData
                rowIndex: index
              }
            }
          }

          PanelSeparator {
            visible: root.paired && longwire.models.length > 0 && longwire.state !== "stopped"
            foreground: root.foreground
          }

          Column {
            visible: root.paired && longwire.models.length > 0 && longwire.state !== "stopped"
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "Shared models"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: longwire.models.slice(0, 12)
              RowLayout {
                required property var modelData
                width: parent.width
                spacing: Style.space(8)

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: modelData.name
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideMiddle
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.kind
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Text {
              visible: longwire.models.length > 12
              textFormat: Text.PlainText
              text: "+ " + (longwire.models.length - 12) + " more"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            visible: root.paired && longwire.models.length === 0 && root.live
            width: parent.width
            textFormat: Text.PlainText
            text: "No models yet. Start ollama, llama.cpp, LM Studio or vLLM on this machine and its models are shared within seconds."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: row
    property var action: ({})
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      enabled: !longwire.busy
      onEntered: {
        root.cursorActive = true
        root.cursorIndex = row.rowIndex
      }
      onClicked: root.activate(row.rowIndex)
    }

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: String(row.action.icon || "")
        color: row.rowIndex === 0 && longwire.state === "pairing" ? root.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: String(row.action.title || "")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: String(row.action.subtitle || "")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value; width: Math.min(implicitWidth, parent.width * 0.68) }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignRight
  }
}
