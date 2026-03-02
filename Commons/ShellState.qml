pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Helpers/QtObj2JS.js" as QtObj2JS
import qs.Services.Power
import qs.Services.System
import qs.Services.UI

// Centralized shell state management for small cache files
Singleton {
  id: root

  property string stateFile: ""
  property bool isLoaded: false

  // State properties for different services
  readonly property alias data: adapter

  // Signals for state changes
  signal displayStateChanged
  signal notificationsStateChanged
  signal changelogStateChanged
  signal colorSchemesListChanged
  signal networkStateChanged

  Component.onCompleted: {
    // Setup state file path (needs Settings to be available)
    Qt.callLater(() => {
                   if (typeof Settings !== 'undefined' && Settings.cacheDir) {
                     stateFile = Settings.cacheDir + "shell-state.json";
                     stateFileView.path = stateFile;
                   }
                 });
  }

  // FileView for shell state
  FileView {
    id: stateFileView
    printErrors: false
    watchChanges: false

    onAdapterUpdated: save()

    adapter: JsonAdapter {
      id: adapter

      // CompositorService: display scales
      property var display: ({})

      // NotificationService: notification state
      property var notificationsState: ({
                                          lastSeenTs: 0
                                        })

      // UpdateService: changelog state
      property var changelogState: ({
                                      lastSeenVersion: ""
                                    })

      // SchemeDownloader: color schemes list
      property var colorSchemesList: ({
                                        schemes: [],
                                        timestamp: 0
                                      })

      // Network state (synced with system, not user config)
      property JsonObject network: JsonObject {
        property bool wifiEnabled: true
        property bool airplaneModeEnabled: false
      }

      // UI state: settings panel, etc.
      property JsonObject ui: JsonObject {
        property bool settingsSidebarExpanded: true
        property string networkPanelView: "wifi"
        property string wifiDetailsViewMode: "grid"
        property string bluetoothDetailsViewMode: "grid"
      }

      // Telemetry state
      property var telemetry: ({
                                 instanceId: ""
                               })

      // Launcher app usage counts
      property var launcherUsage: ({})
    }

    onLoaded: {
      root.isLoaded = true;
      Logger.d("ShellState", "Loaded state file");
    }

    onLoadFailed: error => {
      if (error === 2) {
        // File doesn't exist, will be created on first write
        root.isLoaded = true;
        Logger.d("ShellState", "State file doesn't exist, will create on first write");
      } else {
        Logger.e("ShellState", "Failed to load state file:", error);
        root.isLoaded = true;
      }
    }
  }

  // Launcher usage
  function getLauncherUsageCount(key) {
    const m = adapter.launcherUsage;
    if (!m)
      return 0;
    const v = m[key];
    return typeof v === 'number' && isFinite(v) ? v : 0;
  }

  function recordLauncherUsage(key) {
    let counts = Object.assign({}, adapter.launcherUsage || {});
    counts[key] = getLauncherUsageCount(key) + 1;
    adapter.launcherUsage = counts;
    save();
  }

  // Debounced save timer
  Timer {
    id: saveTimer
    interval: 500
    onTriggered: performSave()
  }

  property bool saveQueued: false

  function save() {
    saveQueued = true;
    saveTimer.restart();
  }

  function performSave() {
    if (!saveQueued || !stateFile) {
      return;
    }

    saveQueued = false;

    try {
      // Ensure cache directory exists
      Quickshell.execDetached(["mkdir", "-p", Settings.cacheDir]);

      Qt.callLater(() => {
                     try {
                       stateFileView.writeAdapter();
                       Logger.d("ShellState", "Saved state file");
                     } catch (writeError) {
                       Logger.e("ShellState", "Failed to write state file:", writeError);
                     }
                   });
    } catch (error) {
      Logger.e("ShellState", "Failed to save state:", error);
    }
  }

  // Convenience functions for each service

  // Display state (CompositorService)
  function setDisplay(displayData) {
    adapter.display = displayData;
    save();
    displayStateChanged();
  }

  function getDisplay() {
    return adapter.display || {};
  }

  // Notifications state (NotificationService)
  function setNotificationsState(stateData) {
    adapter.notificationsState = stateData;
    save();
    notificationsStateChanged();
  }

  function getNotificationsState() {
    return adapter.notificationsState || {
      lastSeenTs: 0
    };
  }

  // Changelog state (UpdateService)
  function setChangelogState(stateData) {
    adapter.changelogState = stateData;
    save();
    changelogStateChanged();
  }

  function getChangelogState() {
    return adapter.changelogState || {
      lastSeenVersion: ""
    };
  }

  // Color schemes list (SchemeDownloader)
  function setColorSchemesList(listData) {
    adapter.colorSchemesList = listData;
    save();
    colorSchemesListChanged();
  }

  function getColorSchemesList() {
    return adapter.colorSchemesList || {
      schemes: [],
      timestamp: 0
    };
  }

  // UI state
  function setSettingsSidebarExpanded(expanded) {
    adapter.ui.settingsSidebarExpanded = expanded;
  }

  function getSettingsSidebarExpanded() {
    return adapter.ui.settingsSidebarExpanded !== false; // default to true
  }

  // Telemetry state
  function setTelemetryState(stateData) {
    adapter.telemetry = stateData;
    save();
  }

  function getTelemetryState() {
    return adapter.telemetry || {
      instanceId: ""
    };
  }

  function getTelemetryInstanceId() {
    return getTelemetryState().instanceId || "";
  }

  function setTelemetryInstanceId(instanceId) {
    let state = getTelemetryState();
    state.instanceId = instanceId;
    setTelemetryState(state);
  }

  // -----------------------------------------------------
  function buildStateSnapshot() {
    try {
      const settingsData = QtObj2JS.qtObjectToPlainObject(Settings.data);
      const shellStateData = ShellState?.data ? QtObj2JS.qtObjectToPlainObject(ShellState.data) || {} : {};

      return {
        settings: settingsData,
        state: {
          doNotDisturb: NotificationService.doNotDisturb,
          noctaliaPerformanceMode: PowerProfileService.noctaliaPerformanceMode,
          barVisible: BarService.isVisible,
          openedPanel: PanelService.openedPanel?.objectName || "",
          lockScreenActive: PanelService.lockScreen?.active || false,
          wallpapers: WallpaperService.currentWallpapers || {},
          desktopWidgetsEditMode: DesktopWidgetRegistry.editMode || false,
          // -------------
          display: shellStateData.display || {},
          notificationsState: shellStateData.notificationsState || {},
          changelogState: shellStateData.changelogState || {},
          colorSchemesList: shellStateData.colorSchemesList || {},
          ui: shellStateData.ui || {}
        }
      };
    } catch (error) {
      Logger.e("Settings", "Failed to build state snapshot:", error);
      return null;
    }
  }
}
