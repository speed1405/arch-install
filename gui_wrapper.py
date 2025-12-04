#!/usr/bin/env python3
"""
GUI Wrapper for Arch Linux Installer
Provides command-line interface to GUI dialogs
Called from bash script to display GUI elements
"""

import sys
from installer_gui import InstallerGUI


def main():
    if len(sys.argv) < 2:
        print("Usage: gui_wrapper.py <command> [args...]", file=sys.stderr)
        sys.exit(1)
    
    command = sys.argv[1]
    backtitle = "Arch Linux Installer v2.0.0"
    
    # Allow backtitle override
    if "--backtitle" in sys.argv:
        idx = sys.argv.index("--backtitle")
        if idx + 1 < len(sys.argv):
            backtitle = sys.argv[idx + 1]
    
    gui = InstallerGUI(backtitle)
    
    try:
        if command == "msgbox":
            # gui_wrapper.py msgbox <title> <message> [height] [width]
            title = sys.argv[2] if len(sys.argv) > 2 else "Message"
            message = sys.argv[3] if len(sys.argv) > 3 else ""
            height = int(sys.argv[4]) if len(sys.argv) > 4 else 10
            width = int(sys.argv[5]) if len(sys.argv) > 5 else 60
            gui.msgbox(title, message, height, width)
            sys.exit(0)
        
        elif command == "yesno":
            # gui_wrapper.py yesno <title> <message> [height] [width]
            title = sys.argv[2] if len(sys.argv) > 2 else "Question"
            message = sys.argv[3] if len(sys.argv) > 3 else ""
            height = int(sys.argv[4]) if len(sys.argv) > 4 else 10
            width = int(sys.argv[5]) if len(sys.argv) > 5 else 60
            result = gui.yesno(title, message, height, width)
            sys.exit(0 if result else 1)
        
        elif command == "inputbox":
            # gui_wrapper.py inputbox <title> <message> [default] [height] [width]
            title = sys.argv[2] if len(sys.argv) > 2 else "Input"
            message = sys.argv[3] if len(sys.argv) > 3 else ""
            default = sys.argv[4] if len(sys.argv) > 4 else ""
            height = int(sys.argv[5]) if len(sys.argv) > 5 else 10
            width = int(sys.argv[6]) if len(sys.argv) > 6 else 60
            result = gui.inputbox(title, message, default, height, width)
            if result is not None:
                print(result)
                sys.exit(0)
            else:
                sys.exit(1)
        
        elif command == "passwordbox":
            # gui_wrapper.py passwordbox <title> <message> [height] [width]
            title = sys.argv[2] if len(sys.argv) > 2 else "Password"
            message = sys.argv[3] if len(sys.argv) > 3 else ""
            height = int(sys.argv[4]) if len(sys.argv) > 4 else 10
            width = int(sys.argv[5]) if len(sys.argv) > 5 else 60
            result = gui.passwordbox(title, message, height, width)
            if result is not None:
                print(result)
                sys.exit(0)
            else:
                sys.exit(1)
        
        elif command == "menu":
            # gui_wrapper.py menu <title> <message> <height> <width> <menu_height> <tag1> <item1> <tag2> <item2> ...
            title = sys.argv[2] if len(sys.argv) > 2 else "Menu"
            message = sys.argv[3] if len(sys.argv) > 3 else ""
            height = int(sys.argv[4]) if len(sys.argv) > 4 else 20
            width = int(sys.argv[5]) if len(sys.argv) > 5 else 70
            menu_height = int(sys.argv[6]) if len(sys.argv) > 6 else 10
            
            # Parse menu items (tag, item pairs)
            choices = []
            i = 7
            while i < len(sys.argv):
                if i + 1 < len(sys.argv):
                    tag = sys.argv[i]
                    item = sys.argv[i + 1]
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
            title = sys.argv[2] if len(sys.argv) > 2 else "Checklist"
            message = sys.argv[3] if len(sys.argv) > 3 else ""
            height = int(sys.argv[4]) if len(sys.argv) > 4 else 20
            width = int(sys.argv[5]) if len(sys.argv) > 5 else 70
            list_height = int(sys.argv[6]) if len(sys.argv) > 6 else 10
            
            # Parse checklist items (tag, item, status triples)
            choices = []
            i = 7
            while i < len(sys.argv):
                if i + 2 < len(sys.argv):
                    tag = sys.argv[i]
                    item = sys.argv[i + 1]
                    status_str = sys.argv[i + 2].lower()
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
