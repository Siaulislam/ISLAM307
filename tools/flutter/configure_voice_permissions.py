#!/usr/bin/env python3
"""Add microphone/speech permissions to generated Flutter platforms."""

from __future__ import annotations

import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"


def configure_ios() -> None:
    path = APP / "ios" / "Runner" / "Info.plist"
    if not path.exists():
        return
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    data["NSMicrophoneUsageDescription"] = (
        "Ziaulislam uses the microphone only when you tap voice input."
    )
    data["NSSpeechRecognitionUsageDescription"] = (
        "Ziaulislam converts your spoken question into text on request."
    )
    data["NSLocationWhenInUseUsageDescription"] = (
        "Qibla Direction uses your location only to calculate the bearing to the Kaaba."
    )
    with path.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=False)


def configure_android() -> None:
    path = APP / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not path.exists():
        return
    android = "http://schemas.android.com/apk/res/android"
    ET.register_namespace("android", android)
    tree = ET.parse(path)
    root = tree.getroot()
    permissions = {
        "android.permission.INTERNET",
        "android.permission.RECORD_AUDIO",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.ACCESS_FINE_LOCATION",
    }
    existing = {
        node.attrib.get(f"{{{android}}}name")
        for node in root.findall("uses-permission")
    }
    for permission in sorted(permissions - existing):
        node = ET.Element("uses-permission")
        node.set(f"{{{android}}}name", permission)
        root.insert(0, node)
    tree.write(path, encoding="utf-8", xml_declaration=True)


def main() -> int:
    configure_ios()
    configure_android()
    print("Configured generated iOS/Android voice permissions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
