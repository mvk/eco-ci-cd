import pytest

from scripts import git_url_norm

@pytest.mark.parametrize("input_data,expected", [
    (("git@github.com:telcov10n/eco-ci-cd.git", True), "https://github.com/telcov10n/eco-ci-cd"),
    (("git@github.com:telcov10n/eco-ci-cd.git", True), "https://github.com/telcov10n/eco-ci-cd"),
    (("git@github.com:telcov10n/eco-ci-cd.git", False), "https://git@github.com/telcov10n/eco-ci-cd"),
    (("git+ssh://git@github.com:telcov10n/eco-ci-cd.git", True), "https://github.com/telcov10n/eco-ci-cd"),
    (("git+ssh://git@github.com:telcov10n/eco-ci-cd.git", False), "https://git@github.com/telcov10n/eco-ci-cd"),
    (("https://github.com/telcov10n/eco-ci-cd.git", True), "https://github.com/telcov10n/eco-ci-cd"),
    (("https://myuser@github.com/telcov10n/eco-ci-cd.git", False), "https://myuser@github.com/telcov10n/eco-ci-cd"),
    (("https://mysuser:mypass@github.com/telcov10n/eco-ci-cd.git", False), "https://mysuser:mypass@github.com/telcov10n/eco-ci-cd"),
    (("https://github.com/telcov10n/eco-ci-cd", True), "https://github.com/telcov10n/eco-ci-cd"),
    (("https://github.com/telcov10n/eco-ci-cd", False), "https://github.com/telcov10n/eco-ci-cd"),
    (("https://github.com/telcov10n/eco-ci-cd.git", True), "https://github.com/telcov10n/eco-ci-cd"),
    (("https://github.com/telcov10n/eco-ci-cd.git", False), "https://github.com/telcov10n/eco-ci-cd"),
    (("https://github.com/telcov10n/eco-ci-cd.git", True), "https://github.com/telcov10n/eco-ci-cd"),
])
def test_normalize_git_url(input_data, expected):
    url, public = input_data
    assert git_url_norm.normalize_git_url(url, public=public) == expected