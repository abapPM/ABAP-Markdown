# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
The project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and [ISO Date Format](https://www.iso.org/iso-8601-date-and-time-format.html).

See [unreleased changes] for the latest updates.

## Version [1.4.1] - 2025-01-26

Initial Release

- Original from https://github.com/koemaeda/abap-markdown

 Added by apm:

- Option to render href and img src links with different root
- Option to use sapevent for launching links in external browser
- Option to set root path for internal links
- Normalizing of link paths
- Support for sapevent as protocol
- Syntax highlighting (based on abapGit + diff + markdown)
- Support for internal links (# Heading {#custom-id})
- Support for strikethrough, subscript, superscript, highlight
- Support for task list ([ ] or [x] task)
- Fix a few regular expressions
- Support for GitHub alerts
- Fix for escaped | in tables
- CSS
- Remove variable prefixes, strict abaplint rules

[unreleased changes]: https://github.com/abapPM/ABAP-Markdown/compare/1.4.1...main
[1.4.1]: https://github.com/abapPM/ABAP-Markdown/releases/tag/1.4.1
