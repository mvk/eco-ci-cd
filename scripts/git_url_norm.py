#!/usr/bin/env python3

import argparse
import subprocess
import sys
from typing import Optional


SUPPORTED_URL_SCHEMAS = [
    "https",
    "git+ssh",
    "ssh",
    "git",
]

def normalize_git_url(url: str, public: bool = True) -> str:
    """
    Normalizes various git remote URL formats into a standard HTTPS URL.

    This function handles the following URL formats:
    - Standard HTTPS: https://user:pass@github.com/team/repo.git
    - Explicit SSH: git+ssh://git@github.com/team/repo.git
    - Explicit SSH: ssh://git@github.com/team/repo.git
    - SCP-like SSH: git@github.com:team/repo.git

    It ensures the final URL is in the format:
        - https://server/team/repo (public)
        - https://user:pass@server/team/repo (private)

    Args:
        url: The git remote URL to normalize.
        public: If True (default), strips user information (e.g., 'user@')
                from the URL. If False, preserves user information.
    Returns:
        The normalized git URL.
    Raises:
        ValueError: If the URL is not provided.
    """
    if not url:
        raise ValueError("Cannot continue without a URL.")

    result = url
    # 1. remove supported schema prefixes:
    for schema in SUPPORTED_URL_SCHEMAS:
        prefix = f"{schema}://"
        if url.startswith(prefix):
            result = url.removeprefix(prefix)
            break

    user_info = ""
    host_and_path = result
    # 2. extract user info if present
    if "@" in host_and_path:
        # Handles both user:pass@host/path and user@host/path
        user_info, host_and_path = host_and_path.split("@", 1)
        user_info += "@"
    
    # 3. convert scp host:path separator to slash
    if ":" in host_and_path and "/" not in host_and_path.split(":", 1)[0]:
        host_and_path = host_and_path.replace(":", "/", 1) 
    
    # 4. Reconstruct the final URL in target schema
    if public:
        result = f"https://{host_and_path}"
    else:
        result = f"https://{user_info}{host_and_path}"

    # 5. removes suffix .git if present
    result = result.removesuffix(".git")

    # 6. Return the result
    return result


def cli_args_parser(args: list[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Normalize a Git remote URL to HTTPS format."
    )
    parser.add_argument(
        "-u", "--url",
        dest="remote_url",
        help="The git remote URL to normalize.",
        required=True
    )
    parser.add_argument(
        "-p", "--private",
        dest="public",
        action="store_false",
        default=True,
        help="Return a private URL (default: public URL).",
        required=False,
    )
    if args is None:
        args = sys.argv[1:]
    result = parser.parse_args(args=args)
    return result

def main():
    """Main function to parse arguments and normalize the URL."""
    args = cli_args_parser(args=sys.argv[1:])
    

    # Proceed only if we have a URL
    try:
        normalized_url = normalize_git_url(args.remote_url, public=args.public)
        print(normalized_url)
    except ValueError as ve:
        print(f"Error: {ve}", file=sys.stderr, exc_info=True)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())