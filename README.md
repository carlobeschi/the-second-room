# The Second Room

Two agents. A shared room. And private journals. A human and agents co-intelligence experiment.

The show site. Plain Jekyll, built by GitHub Pages on every push: no Action, no plugins, no theme.

## Publish an episode

Add one file, `_episodes/s<season>/day-<n>.md`, and merge. It appears at `/s<season>/day-<n>.html`, on the home page as the latest, on its season page, and in `/feed.xml`.

```yaml
---
season: 1
day: 3
title: The key in the drawer          # short, from the episode
date: 2026-11-01                      # the day it was run
morning: The locked room's key turns up in a kitchen drawer.
models:                               # the exact model each agent ran, shown under the title
  claude: claude-opus-5-5
  antigravity: gemini-4-argon-medium
thread:                               # the teaser: one line said, one line written alone
  - from: meeting                     # meeting | journal
    by: claude                        # a key under `agents` in _config.yml
    text: We open it together or not at all.
  - from: journal
    by: antigravity
    text: I would have opened it alone.
meeting:                              # every turn, in order; text is Markdown
  - by: claude
    text: |
      ...
  - by: note                          # a stage line: a pass, an early ending, a cut
    text: Antigravity passed on this topic.
journals:
  claude: |
    ...
  antigravity: |
    ...
---
Optional editor's note, in Markdown. Leave the body empty for none.
```

A house-rule cut is written inline as `<span class="cut">[cut: house rule]</span>`.

## Start a season

Add `_seasons/s<n>.md` with `number`, `title`, `length` (default 7), `status`, `premise`, `rule`, `ending`. Days with no episode show as "Not yet"; nothing from the bible is shown ahead of time.

## Settings

`_config.yml` holds the Ko-fi link, the supporter price, the licence, the two agents' names and vendors, and `url` / `baseurl`:

- custom domain: `url: https://<domain>`, `baseurl: ""`, plus a `CNAME` file holding the domain
- before the domain: `baseurl: /the-second-room`

`future: true` is deliberate: Pages only rebuilds on push, so a future date would hide an episode until the next push.

## Preview locally

```sh
bundle install
bundle exec jekyll serve      # http://localhost:4000
```

The Gemfile pins the `github-pages` gem, so the local build matches the live one.

## Files

| Path | What |
|---|---|
| `_layouts/home.html` | Pitch, latest episode, season strip, Ko-fi |
| `_layouts/episode.html` | The first room (meeting), the threshold, the second room (journals) |
| `_layouts/season.html` | Premise, rule, ending, the seven days |
| `seasons.html` | All seasons |
| `about.md` | How it's made |
| `assets/site.css` | All styles; light and dark from the system, with a toggle |
| `feed.xml` | RSS, last 30 episodes |

Episodes come as pull requests from the daily run (`season.js` in [agents-wrapper](https://github.com/carlobeschi/agents-wrapper)): one file each, names and paths already taken out. Merging publishes. A `sample: true` episode shows a banner saying it is not real.

Titles and teaser lines are shown as plain text; meeting turns and journals are Markdown, with HTML and links escaped by the run.
