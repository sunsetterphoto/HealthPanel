// i18n.js — tiny in-widget translation. English strings are the source/keys;
// DE maps them to German. tr(lang, s) returns the German translation for lang
// "de", otherwise the English source. Shared by all components.
.pragma library

var DE = {
    // --- system column ---
    "Power mode": "Power-Modus",
    "Performance": "Leistung",
    "Balanced": "Ausgewogen",
    "Power Saver": "Sparen",
    "Cores": "Kerne",
    "Threads": "Threads",
    "Down": "Down",
    "Up": "Up",
    // --- battery card ---
    "Charge": "Ladung",
    "left": "verbleibend",
    "to full": "bis voll",
    "Health": "Gesundheit",
    "Cycles": "Ladezyklen",
    "Designed": "Auslegung",
    "Full (now)": "Voll (aktuell)",
    "Remaining": "Verbleibend",
    "Status": "Status",
    "Power draw": "Leistungsaufnahme",
    "Voltage": "Spannung",
    "design min": "Auslegung min",
    "Technology": "Technologie",
    "Serial": "Seriennummer",
    "Charge limit": "Ladegrenze",
    "Charge mode": "Lademodus",
    "no battery found": "kein Akku gefunden",
    "Battery": "Akku",
    // --- control column ---
    "Controls": "Steuerung",
    "Prevent standby & lock": "Standby & Sperre verhindern",
    "Screen": "Bildschirm",
    "Keyboard": "Tastatur",
    "Volume": "Lautstärke",
    "System Settings": "Systemeinstellungen",
    "System Monitor": "Systemmonitor",
    "Widget Settings": "Widget-Einstellungen",
    // --- config: general ---
    "Refresh interval:": "Aktualisierungsintervall:",
    "Language:": "Sprache:",
    "System default": "Systemstandard",
    "German": "Deutsch",
    "English": "Englisch",
    // --- config: columns / sections ---
    "Show system column": "System-Spalte anzeigen",
    "Show battery column": "Akku-Spalte anzeigen",
    "Show controls column": "Steuer-Spalte anzeigen",
    "Shows:": "Zeigt:",
    "Style:": "Stil:",
    "CPU + cores": "CPU + Kerne",
    "Show logical cores (threads) instead of physical": "Logische Kerne (Threads) statt physische",
    "GPU + VRAM": "GPU + VRAM",
    "RAM + swap": "RAM + Swap",
    "Disk": "Festplatte",
    "Network": "Netzwerk",
    "SSD SMART (health / hours / TBW)": "SSD-SMART (Gesundheit / Stunden / TBW)",
    "Temperatures (CPU / disk / GPU)": "Temperaturen (CPU / Festplatte / GPU)",
    "Bar": "Balken",
    "Ring": "Ring",
    "Sparkline": "Sparkline",
    "Text": "Text",
    "Text only": "Nur Text",
    "CPU load": "CPU-Last",
    "VRAM": "VRAM",
    // --- config: battery ---
    "Battery cycles": "Ladezyklen",
    "Capacity (designed / full / remaining)": "Kapazität (Auslegung / Voll / Verbleibend)",
    "Live values (status / power / voltage)": "Live-Werte (Status / Leistung / Spannung)",
    "Estimated remaining time (hours)": "Geschätzte Restlaufzeit (Stunden)",
    "Vendor charge thresholds": "Hersteller-Ladeschwellen",
    // --- config: controls ---
    "Prevent standby & lock screen": "Standby & Sperrbildschirm verhindern",
    "Screen brightness": "Bildschirmhelligkeit",
    "Keyboard backlight": "Tastaturbeleuchtung",
    "Volume + mute": "Lautstärke + Stummschalten",
    // --- config: panel ---
    "Panel icons": "Panel-Icons",
    "Choose which icons appear in the panel / compact view and which values are shown as text. Reorder with ↑ ↓.": "Lege fest, welche Icons in der Leiste / Kompaktansicht erscheinen und welche Werte als Text daneben stehen. Reihenfolge per ↑ ↓.",
    "Icon:": "Icon:",
    "Text beside it:": "Text daneben:",
    "Add icon": "Icon hinzufügen",
    "Charge %": "Ladung %",
    "Wear/Health %": "Verschleiß/Gesundheit %",
    "Power (W)": "Leistung (W)",
    "Load %": "Last %",
    "Temperature": "Temperatur",
    "Usage %": "Belegung %",
    "Used (GB)": "Benutzt (GB)",
    "Swap %": "Swap %",
    "Read": "Lesen",
    "Write": "Schreiben",
    "Download": "Download",
    "Upload": "Upload",
    // --- config category names ---
    "Pinned — stays open": "Angeheftet — bleibt offen",
    "Pin": "Anheften",
    "General": "Allgemein",
    "System": "System",
    "Battery / Energy": "Akku / Energie"
};

function tr(lang, s) {
    if (lang === "de" && DE[s] !== undefined) return DE[s];
    return s;
}
