# AltStore / SideStore source; fields for both the 2.x format (versions, appPermissions) and the legacy one.
{
  name: "FLX-Pad",
  identifier: "io.github.mathr81.flxpad.source",
  sourceURL: "https://github.com/\($repo)/releases/latest/download/source.json",
  iconURL: $icon,
  apps: [{
    name: "FLX-Pad",
    bundleIdentifier: "io.github.mathr81.flxpad",
    developerName: "Mathr81",
    subtitle: "Contrôleur DJ façon DDJ-FLX4 en Wi-Fi",
    localizedDescription: "Contrôleur DJ multitouch pour iPad qui envoie les messages MIDI d'une Pioneer DDJ-FLX4 via rtpMIDI. Marche avec le mapping DDJ-FLX4 de Mixxx.",
    iconURL: $icon,
    tintColor: "#FF8C00",
    category: "entertainment",
    versions: [{ version: $version, buildVersion: $build, date: $date, size: $size, downloadURL: $url, minOSVersion: "16.0" }],
    version: $version,
    versionDate: $date,
    downloadURL: $url,
    size: $size,
    appPermissions: {
      entitlements: [],
      privacy: { NSLocalNetworkUsageDescription: "FLX-Pad envoie le MIDI à ton ordinateur via le réseau local (rtpMIDI)." }
    }
  }],
  news: []
}
