#!/usr/bin/env python3
"""
GUI Wrapper for Arch Linux Installer
Provides command-line interface to GUI dialogs
Called from bash script to display GUI elements
"""

import sys
from installer_gui import InstallerGUI

# Version constant - should match install-arch.sh SCRIPT_VERSION
DEFAULT_BACKTITLE = "Arch Linux Installer v2.0.0"


def main():
    # Parse and remove backtitle if present (only process first occurrence)
    backtitle = DEFAULT_BACKTITLE
    args = sys.argv[1:]  # Skip script name
    
    # Check for --backtitle flag and remove it from args
    try:
        if "--backtitle" in args:
            idx = args.index("--backtitle")
            if idx + 1 < len(args):
                backtitle = args[idx + 1]
                # Remove both --backtitle and its value
                args = args[:idx] + args[idx+2:]
    except (ValueError, IndexError):
        # Ignore errors in backtitle parsing, use default
        pass
    
    if len(args) < 1:
        print("Usage: gui_wrapper.py <command> [args...]", file=sys.stderr)
        sys.exit(1)
    
    command = args[0]
    gui = InstallerGUI(backtitle)
    
    try:
        if command == "msgbox":
            # gui_wrapper.py msgbox <title> <message> [height] [width]
            title = args[1] if len(args) > 1 else "Message"
            message = args[2] if len(args) > 2 else ""
            height = int(args[3]) if len(args) > 3 else 10
            width = int(args[4]) if len(args) > 4 else 60
            gui.msgbox(title, message, height, width)
            sys.exit(0)
        
        elif command == "yesno":
            # gui_wrapper.py yesno <title> <message> [height] [width]
            title = args[1] if len(args) > 1 else "Question"
            message = args[2] if len(args) > 2 else ""
            height = int(args[3]) if len(args) > 3 else 10
            width = int(args[4]) if len(args) > 4 else 60
            result = gui.yesno(title, message, height, width)
            sys.exit(0 if result else 1)
        
        elif command == "inputbox":
            # gui_wrapper.py inputbox <title> <message> [default] [height] [width]
            title = args[1] if len(args) > 1 else "Input"
            message = args[2] if len(args) > 2 else ""
            default = args[3] if len(args) > 3 else ""
            height = int(args[4]) if len(args) > 4 else 10
            width = int(args[5]) if len(args) > 5 else 60
            result = gui.inputbox(title, message, default, height, width)
            if result is not None:
                print(result)
                sys.exit(0)
            else:
                sys.exit(1)
        
        elif command == "passwordbox":
            # gui_wrapper.py passwordbox <title> <message> [height] [width]
            title = args[1] if len(args) > 1 else "Password"
            message = args[2] if len(args) > 2 else ""
            height = int(args[3]) if len(args) > 3 else 10
            width = int(args[4]) if len(args) > 4 else 60
            result = gui.passwordbox(title, message, height, width)
            if result is not None:
                print(result)
                sys.exit(0)
            else:
                sys.exit(1)
        
        elif command == "menu":
            # gui_wrapper.py menu <title> <message> <height> <width> <menu_height> <tag1> <item1> <tag2> <item2> ...
            title = args[1] if len(args) > 1 else "Menu"
            message = args[2] if len(args) > 2 else ""
            height = int(args[3]) if len(args) > 3 else 20
            width = int(args[4]) if len(args) > 4 else 70
            menu_height = int(args[5]) if len(args) > 5 else 10
            
            # Parse menu items (tag, item pairs)
            choices = []
            i = 6
            while i < len(args):
                if i + 1 < len(args):
                    tag = args[i]
                    item = args[i + 1]
                    choices.append((tag, item))
                    i += 2
                else:
                    break
            
            result = gui.menu(title, message, height, width, menu_height, choices)
            if result is not None:
                print(result)
                sys.exit(0)
            else:
                sys.exit(1)
        
        elif command == "checklist":
            # gui_wrapper.py checklist <title> <message> <height> <width> <list_height> <tag1> <item1> <status1> ...
            title = args[1] if len(args) > 1 else "Checklist"
            message = args[2] if len(args) > 2 else ""
            height = int(args[3]) if len(args) > 3 else 20
            width = int(args[4]) if len(args) > 4 else 70
            list_height = int(args[5]) if len(args) > 5 else 10
            
            # Parse checklist items (tag, item, status triples)
            choices = []
            i = 6
            while i < len(args):
                if i + 2 < len(args):
                    tag = args[i]
                    item = args[i + 1]
                    status_str = args[i + 2].lower()
                    status = status_str in ['on', 'true', '1', 'yes']
                    choices.append((tag, item, status))
                    i += 3
                else:
                    break
            
            result = gui.checklist(title, message, height, width, list_height, choices)
            if result is not None:
                # Output as space-separated quoted strings (like whiptail)
                output = ' '.join(f'"{tag}"' for tag in result)
                print(output)
                sys.exit(0)
            else:
                sys.exit(1)
        
        else:
            print(f"Unknown command: {command}", file=sys.stderr)
            sys.exit(1)
    
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
