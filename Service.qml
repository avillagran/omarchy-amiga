import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root
  readonly property string ipcTarget: "io.github.avillagran.omarchy-amiga"
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  property string selectedDemo: ""
  property string selectedMode: "direct"
  property string lastOutput: ""

  Process {
    id: startProcess
    command: [root.pluginDir + "/bin/omarchy-amiga", "start", root.selectedDemo, root.selectedMode]
    stdout: StdioCollector { onStreamFinished: root.lastOutput = String(text || "") }
  }

  Process {
    id: stopProcess
    command: [root.pluginDir + "/bin/omarchy-amiga", "stop"]
    stdout: StdioCollector { onStreamFinished: root.lastOutput = String(text || "") }
  }

  IpcHandler {
    target: root.ipcTarget

    function start(path: string, mode: string): void {
      root.selectedDemo = path
      root.selectedMode = mode === "background" ? "background" : "direct"
      startProcess.running = true
    }

    function stop(): void {
      stopProcess.running = true
    }

    function toggleLoop(): void {
      Quickshell.execDetached([root.pluginDir + "/bin/omarchy-amiga", "toggle-loop"])
    }

    function toggleMute(): void {
      Quickshell.execDetached([root.pluginDir + "/bin/omarchy-amiga", "toggle-mute"])
    }

    function status(): string {
      return root.lastOutput
    }
  }
}
