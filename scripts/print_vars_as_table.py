#!/usr/bin/env python3

import os
import sys
from typing import List

EDGE_COL_CHAR = "|"
MID_COL_CHAR = "+"
HR_CHAR = "-"


def print_separator(name_width: int, value_width: int, col_char: str = MID_COL_CHAR, hr_char: str = HR_CHAR):
    """Print horizontal separator line."""
    print(f"{col_char}{hr_char * (name_width + 2)}{col_char}{hr_char * (value_width + 2)}{col_char}")

def print_data_row(name: str, name_width: int, value: str, value_width: int, col_char: str = EDGE_COL_CHAR):
    """Print a data row."""
    print(f"{col_char} {name:<{name_width}} {col_char} {value:<{value_width}} {col_char}")

def print_table(var_names: List[str], edge_col_char: str = EDGE_COL_CHAR, mid_col_char: str = MID_COL_CHAR, hr_char: str = HR_CHAR):
    """Print a formatted table of environment variables."""
    if not var_names:
        return 0
    data = [(name, os.getenv(name, "")) for name in var_names]
    name_width = max(len("Name"), max(len(name) for name, _ in data))
    value_width = max(len("Value"), max(len(value) for _, value in data))
    # Header
    print_separator(name_width, value_width, col_char=mid_col_char, hr_char=hr_char)
    print_data_row('Name:', name_width, 'Value:', value_width, col_char=edge_col_char)
    print_separator(name_width, value_width, col_char=mid_col_char, hr_char=hr_char)
    # Data rows
    for name, value in data:
        print_data_row(name, name_width, value, value_width, col_char=edge_col_char)
    print_separator(name_width, value_width, col_char=mid_col_char, hr_char=hr_char)
    return 0


if __name__ == "__main__":
    edge_col_char = os.environ.get("EDGE_COL_CHAR", EDGE_COL_CHAR)
    mid_col_char = os.environ.get("MID_COL_CHAR", MID_COL_CHAR)
    hr_char = os.environ.get("HR_CHAR", HR_CHAR)
    sys.exit(
        print_table(
            sys.argv[1:],
            edge_col_char=os.getenv('EDGE_COL_CHAR', EDGE_COL_CHAR),
            mid_col_char=os.getenv('MID_COL_CHAR', MID_COL_CHAR),
            hr_char=os.getenv('HR_CHAR', HR_CHAR)
        )
    )
