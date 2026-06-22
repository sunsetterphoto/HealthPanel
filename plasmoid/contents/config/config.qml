import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("System")
        icon: "computer-symbolic"
        source: "configSystem.qml"
    }
    ConfigCategory {
        name: i18n("Battery / Energy")
        icon: "battery"
        source: "configBattery.qml"
    }
    ConfigCategory {
        name: i18n("Controls")
        icon: "settings-configure"
        source: "configControls.qml"
    }
    ConfigCategory {
        name: i18n("Panel icons")
        icon: "view-list-icons"
        source: "configPanel.qml"
    }
}
