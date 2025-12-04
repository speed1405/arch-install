#!/usr/bin/env python3
"""
Arch Linux Installer TUI Module
Python-based TUI (Text User Interface) using dialog library
Enhanced with progress bars and better visual aesthetics
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
    """Main TUI class for the Arch Linux installer with enhanced visual design."""
    
    def __init__(self, backtitle: str = "Arch Linux Installer"):
        """Initialize the TUI with dialog library and enhanced settings."""
        self.d = Dialog(dialog="dialog", autowidgetsize=True)
        self.d.set_background_title(backtitle)
    
    def msgbox(self, title: str, message: str, height: int = 10, width: int = 60) -> int:
        """
        Display a message box with enhanced TUI formatting.
        Returns Dialog.OK on success, Dialog.ESC if user presses ESC.
        """
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
        """
        Start a progress gauge with enhanced TUI display.
        Shows a visual progress bar with percentage.
        """
        formatted_message = self._format_progress_message(message, percent)
        return self.d.gauge_start(formatted_message, height=height, width=width, title=title, percent=percent)
    
    def gauge_update(self, percent: int, message: str = "", update_text: bool = True):
        """
        Update the progress gauge with new percentage and optional message.
        Always updates text by default for better feedback.
        """
        formatted_message = self._format_progress_message(message, percent)
        self.d.gauge_update(percent, formatted_message, update_text=update_text)
    
    def gauge_stop(self):
        """Stop and close the progress gauge."""
        self.d.gauge_stop()
    
    def _format_progress_message(self, message: str, percent: int = 0) -> str:
        """
        Format progress message for gauge display.
        Returns the message as-is for display in progress gauge.
        """
        if message:
            return message
        return f"Progress: {percent}%"
    
    def mixedgauge(self, title: str, message: str, height: int = 0, width: int = 0, 
                   percent: int = 0, elements: List[Tuple[str, str]] = None):
        """
        Display a mixed gauge showing multiple progress items.
        Useful for showing progress of multiple parallel tasks.
        
        elements: List of (tag, status) tuples where status can be:
                  - A percentage (0-100)
                  - "Pending", "Running", "Done", "Failed", etc.
        """
        if elements is None:
            elements = []
        code = self.d.mixedgauge(message, height=height, width=width, 
                                percent_overall=percent, elements=elements, title=title)
        return code
    
    def progressbox(self, title: str, file_path: str = None, height: int = 20, width: int = 78):
        """
        Display a progress box showing streaming output from a file or command.
        Useful for showing real-time command output.
        """
        if file_path:
            code = self.d.progressbox(file_path=file_path, height=height, width=width, title=title)
        else:
            code = self.d.progressbox(height=height, width=width, title=title)
        return code
    
    def infobox(self, title: str, message: str, height: int = 10, width: int = 60):
        """
        Display an information box that doesn't wait for user input.
        Useful for showing quick status messages during operations.
        """
        code = self.d.infobox(message, height=height, width=width, title=title)
        return code


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
