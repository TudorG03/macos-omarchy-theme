#!/usr/bin/env python3
"""Build Spotlight's bang table from Kagi's MIT-licensed list.

Usage: build-bangs.py <kagi bangs.json> <output.tsv>
Source: https://github.com/kagisearch/bangs (data/bangs.json)
"""
import json
import re
import sys

# Everyday triggers come first because Spotlight treats earlier rows as more popular.
EVERYDAY = ("g yt r rd w wiki gh so ddg gi gm maps gt tr amzn imdb npm mdn aur arch tw x fb ig li hn "
            "spotify sp netflix twitch ebay pypi crates wa ud gcal gmail drive").split()


def clean(value):
    return re.sub(r"[\x00-\x1f\x7f]+", " ", str(value)).strip()


source, out = sys.argv[1:3]
table = {}
for bang in json.load(open(source, encoding="utf8")):
    trigger = clean(bang.get("t", "")).lower()
    url = re.sub(r"\s", "%20", clean(bang.get("u", "")))
    if not re.match(r"^[^\s!]{1,40}$", trigger) or not re.match(r"^https?://\S+$", url):
        continue
    table[trigger] = (trigger, clean(bang.get("s", "")) or trigger, clean(bang.get("d", "")), url)

# Kagi leaves out these short everyday triggers.
for trigger, name, domain, url in (
    ("r", "Reddit", "www.reddit.com", "https://www.reddit.com/search/?q={{{s}}}"),
    ("rd", "Reddit", "www.reddit.com", "https://www.reddit.com/search/?q={{{s}}}"),
    ("w", "Wikipedia", "en.wikipedia.org", "https://en.wikipedia.org/w/index.php?search={{{s}}}"),
    ("wiki", "Wikipedia", "en.wikipedia.org", "https://en.wikipedia.org/w/index.php?search={{{s}}}"),
    ("so", "Stack Overflow", "stackoverflow.com", "https://stackoverflow.com/search?q={{{s}}}"),
    ("ddg", "DuckDuckGo", "duckduckgo.com", "https://duckduckgo.com/?q={{{s}}}"),
    ("gm", "Google Maps", "www.google.com", "https://www.google.com/maps/search/{{{s}}}"),
    ("maps", "Google Maps", "www.google.com", "https://www.google.com/maps/search/{{{s}}}"),
    ("gt", "Google Translate", "translate.google.com", "https://translate.google.com/?text={{{s}}}"),
    ("tr", "Google Translate", "translate.google.com", "https://translate.google.com/?text={{{s}}}"),
    ("amzn", "Amazon", "www.amazon.com", "https://www.amazon.com/s?k={{{s}}}"),
    ("npm", "npm", "www.npmjs.com", "https://www.npmjs.com/search?q={{{s}}}"),
    ("mdn", "MDN", "developer.mozilla.org", "https://developer.mozilla.org/search?q={{{s}}}"),
    ("tw", "X", "x.com", "https://x.com/search?q={{{s}}}"),
    ("fb", "Facebook", "www.facebook.com", "https://www.facebook.com/search/top?q={{{s}}}"),
    ("twitch", "Twitch", "www.twitch.tv", "https://www.twitch.tv/search?term={{{s}}}"),
    ("crates", "crates.io", "crates.io", "https://crates.io/search?q={{{s}}}"),
):
    table.setdefault(trigger, (trigger, name, domain, url))

rank = {trigger: index for index, trigger in enumerate(EVERYDAY)}
rows = sorted(table.values(), key=lambda row: (rank.get(row[0], len(rank)), row[0]))
with open(out, "w", encoding="utf8") as handle:
    for row in rows:
        handle.write("\t".join(row) + "\n")
print(f"{len(rows)} bangs written to {out}")
