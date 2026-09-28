#!/usr/bin/env python3
"""Replace the unofficial 'Nightly' branding strings inside browser/omni.ja.

Source builds without Mozilla's official branding show 'Nightly'; a stable
ESR release should not.  The name stays neutral (Mozilla trademarks cover
'Firefox' for official builds only)."""
import sys, zipfile, shutil, os

NAME = "FreeLinX Web"
omni = sys.argv[1]
tmp = omni + ".new"
repl = {
    "localization/en-US/branding/brand.ftl": {
        "-brand-shorter-name = Nightly": f"-brand-shorter-name = {NAME}",
        "-brand-short-name = Nightly": f"-brand-short-name = {NAME}",
        "-brand-shortcut-name = Nightly": f"-brand-shortcut-name = {NAME}",
        "-brand-full-name = Nightly": f"-brand-full-name = {NAME}",
    },
    "chrome/en-US/locale/branding/brand.properties": {
        "brandShorterName=Nightly": f"brandShorterName={NAME}",
        "brandShortName=Nightly": f"brandShortName={NAME}",
        "brandFullName=Nightly": f"brandFullName={NAME}",
    },
}
with zipfile.ZipFile(omni) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename in repl:
            text = data.decode()
            for a, b in repl[info.filename].items():
                text = text.replace(a, b)
            data = text.encode()
        zout.writestr(info, data)
shutil.move(tmp, omni)
print(f"rebrand: {omni} -> {NAME}")
