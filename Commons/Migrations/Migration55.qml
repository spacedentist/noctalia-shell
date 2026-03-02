import QtQuick
import qs.Commons

QtObject {
  id: root

  // Remove network/UI state properties that moved to ShellState,
  // transferring existing values so the user keeps their state.
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v55: moving network/UI state to ShellState");

    var networkPanelViewMigrated = false;

    if (rawJson && rawJson.network) {
      // Transfer existing values to ShellState before deleting them.
      // ShellState's file won't have these keys yet, so the adapter
      // keeps whatever we set here; the next auto-save persists them.
      if (rawJson.network.wifiEnabled !== undefined)
        ShellState.data.network.wifiEnabled = rawJson.network.wifiEnabled;
      if (rawJson.network.airplaneModeEnabled !== undefined)
        ShellState.data.network.airplaneModeEnabled = rawJson.network.airplaneModeEnabled;
      if (rawJson.network.networkPanelView !== undefined) {
        ShellState.data.ui.networkPanelView = rawJson.network.networkPanelView;
        networkPanelViewMigrated = true;
      }
      if (rawJson.network.wifiDetailsViewMode !== undefined)
        ShellState.data.ui.wifiDetailsViewMode = rawJson.network.wifiDetailsViewMode;
      if (rawJson.network.bluetoothDetailsViewMode !== undefined)
        ShellState.data.ui.bluetoothDetailsViewMode = rawJson.network.bluetoothDetailsViewMode;

      delete rawJson.network.wifiEnabled;
      delete rawJson.network.airplaneModeEnabled;
      delete rawJson.network.networkPanelView;
      delete rawJson.network.wifiDetailsViewMode;
      delete rawJson.network.bluetoothDetailsViewMode;
    }

    // Bug fix: networkPanelView was also written to ui by NetworkPanel.qml
    if (rawJson && rawJson.ui && rawJson.ui.networkPanelView !== undefined) {
      if (!networkPanelViewMigrated)
        ShellState.data.ui.networkPanelView = rawJson.ui.networkPanelView;
      delete rawJson.ui.networkPanelView;
    }

    return true;
  }
}
