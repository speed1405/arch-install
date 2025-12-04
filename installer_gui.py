#!/usr/bin/env python3
"""
Arch Linux Installer GUI Module
Python-based GUI interface using dialog library
Replaces whiptail with a Python implementation
"""

import sys
from typing import List, Tuple, Optional

try:
    from dialog import Dialog
except ImportError:
    print("ERROR: pythondialog module not found.", file=sys.stderr)
    print("Please install it with: python3 -m pip install --break-system-packages pythondialog", file=sys.stderr)
    sys.exit(1)


class InstallerGUI:
    """Main GUI class for the Arch Linux installer."""
    
    def __init__(self, backtitle: str = "Arch Linux Installer"):
        """Initialize the GUI with dialog library."""
        self.d = Dialog(dialog="dialog", autowidgetsize=True)
        self.d.set_background_title(backtitle)
    
    def msgbox(self, title: str, message: str, height: int = 10, width: int = 60) -> int:
        """Display a message box."""
        code = self.d.msgbox(message, height=height, width=width, title=title)
        return code
    
    def yesno(self, title: str, message: str, height: int = 10, width: int = 60) -> bool:
        """Display a yes/no dialog. Returns True for yes, False for no."""
        code = self.d.yesno(message, height=height, width=width, title=title)
        return code == self.d.OK
    
    def inputbox(self, title: str, message: str, init: str = "", height: int = 10, width: int = 60) -> Optional[str]:
        """Display an input box. Returns the input string or None if cancelled."""
        code, result = self.d.inputbox(message, height=height, width=width, title=title, init=init)
        if code == self.d.OK:
            return result
        return None
    
    def passwordbox(self, title: str, message: str, height: int = 10, width: int = 60, insecure: bool = False) -> Optional[str]:
        """Display a password input box. Returns the password or None if cancelled."""
        code, result = self.d.passwordbox(message, height=height, width=width, title=title, insecure=insecure)
        if code == self.d.OK:
            return result
        return None
    
    def menu(self, title: str, message: str, height: int = 20, width: int = 70, 
             menu_height: int = 10, choices: List[Tuple[str, str]] = None) -> Optional[str]:
        """
        Display a menu dialog.
        choices: List of (tag, item) tuples
        Returns: Selected tag or None if cancelled
        """
        if choices is None:
            choices = []
        code, tag = self.d.menu(message, height=height, width=width, 
                                menu_height=menu_height, choices=choices, title=title)
        if code == self.d.OK:
            return tag
        return None
    
    def checklist(self, title: str, message: str, height: int = 20, width: int = 70,
                  list_height: int = 10, choices: List[Tuple[str, str, bool]] = None) -> Optional[List[str]]:
        """
        Display a checklist dialog.
        choices: List of (tag, item, status) tuples where status is True/False for checked/unchecked
        Returns: List of selected tags or None if cancelled
        """
        if choices is None:
            choices = []
        code, tags = self.d.checklist(message, height=height, width=width,
                                      list_height=list_height, choices=choices, title=title)
        if code == self.d.OK:
            return tags
        return None
    
    def gauge_start(self, title: str, message: str, height: int = 8, width: int = 60, percent: int = 0):
        """Start a progress gauge."""
        return self.d.gauge_start(message, height=height, width=width, title=title, percent=percent)
    
    def gauge_update(self, percent: int, message: str = "", update_text: bool = False):
        """Update the progress gauge."""
        self.d.gauge_update(percent, message, update_text=update_text)
    
    def gauge_stop(self):
        """Stop and close the progress gauge."""
        self.d.gauge_stop()


def main():
    """Test the GUI module."""
    gui = InstallerGUI("Arch Linux Installer Test")
    
    # Test msgbox
    gui.msgbox("Test Message", "This is a test message box.", 10, 50)
    
    # Test yesno
    if gui.yesno("Test Question", "Do you want to continue?", 10, 50):
        print("User selected Yes")
    else:
        print("User selected No")
    
    # Test inputbox
    result = gui.inputbox("Test Input", "Enter your name:", "default", 10, 50)
    if result:
        print(f"User entered: {result}")
    
    # Test menu
    choices = [
        ("1", "Option 1"),
        ("2", "Option 2"),
        ("3", "Option 3"),
    ]
    selected = gui.menu("Test Menu", "Select an option:", 15, 60, 5, choices)
    if selected:
        print(f"User selected: {selected}")
    
    # Test checklist
    checklist_choices = [
        ("item1", "First item", False),
        ("item2", "Second item", True),
        ("item3", "Third item", False),
    ]
    selected_items = gui.checklist("Test Checklist", "Select items:", 15, 60, 5, checklist_choices)
    if selected_items:
        print(f"User selected: {selected_items}")
    
    print("GUI test completed successfully!")


if __name__ == "__main__":
    main()
