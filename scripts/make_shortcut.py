#!/usr/bin/env python3
"""Generate the unsigned helper shortcut bundled by the app."""

from __future__ import annotations

import plistlib
import sys
import uuid
from pathlib import Path


def new_id() -> str:
    return str(uuid.uuid4()).upper()


def output(uuid_value: str, name: str) -> dict:
    return {
        "Value": {
            "OutputUUID": uuid_value,
            "Type": "ActionOutput",
            "OutputName": name,
        },
        "WFSerializationType": "WFTextTokenAttachment",
    }


def action(identifier: str, parameters: dict) -> dict:
    return {
        "WFWorkflowActionIdentifier": identifier,
        "WFWorkflowActionParameters": parameters,
    }


def build() -> dict:
    clipboard_id = new_id()
    lock_item_id = new_id()
    lock_image_id = new_id()
    home_item_id = new_id()
    home_image_id = new_id()

    actions = [
        action("is.workflow.actions.getclipboard", {"UUID": clipboard_id}),
        action(
            "is.workflow.actions.getitemfromlist",
            {
                "WFInput": output(clipboard_id, "剪贴板"),
                "WFItemSpecifier": "Item At Index",
                "WFItemIndex": 1,
                "UUID": lock_item_id,
            },
        ),
        action(
            "is.workflow.actions.getwebpagecontents",
            {"WFInput": output(lock_item_id, "来自列表的项目"), "UUID": lock_image_id},
        ),
        action(
            "is.workflow.actions.wallpaper.set",
            {
                "WFInput": output(lock_image_id, "网页的内容"),
                "WFWallpaperLocation": "Lock Screen",
                "WFWallpaperShowPreview": False,
                "WFWallpaperPerspectiveZoom": False,
                "UUID": new_id(),
            },
        ),
        action(
            "is.workflow.actions.getitemfromlist",
            {
                "WFInput": output(clipboard_id, "剪贴板"),
                "WFItemSpecifier": "Item At Index",
                "WFItemIndex": 2,
                "UUID": home_item_id,
            },
        ),
        action(
            "is.workflow.actions.getwebpagecontents",
            {"WFInput": output(home_item_id, "来自列表的项目"), "UUID": home_image_id},
        ),
        action(
            "is.workflow.actions.wallpaper.set",
            {
                "WFInput": output(home_image_id, "网页的内容"),
                "WFWallpaperLocation": "Home Screen",
                "WFWallpaperShowPreview": False,
                "WFWallpaperPerspectiveZoom": False,
                "UUID": new_id(),
            },
        ),
    ]

    return {
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowIcon": {
            "WFWorkflowIconStartColor": -1263359489,
            "WFWorkflowIconGlyphNumber": 61440,
        },
        "WFWorkflowClientVersion": "1146.16",
        "WFWorkflowActions": actions,
        "WFWorkflowHasOutputFallback": False,
        "WFWorkflowOutputContentItemClasses": [],
        "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
        "WFWorkflowImportQuestions": [],
        "WFWorkflowTypes": [],
        "WFQuickActionSurfaces": [],
        "WFWorkflowHasShortcutInputVariables": False,
    }


def main() -> None:
    destination = Path(sys.argv[1] if len(sys.argv) > 1 else "DualWallpaperPicker/Resources/双壁纸设置.shortcut")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("wb") as handle:
        plistlib.dump(build(), handle, fmt=plistlib.FMT_BINARY, sort_keys=False)
    print(destination)


if __name__ == "__main__":
    main()

