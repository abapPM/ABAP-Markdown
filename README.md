![Version](https://img.shields.io/endpoint?url=https://shield.abappm.com/github/abapPM/ABAP-Markdown/src/zcl_markdown.clas.abap/c_version&label=Version&color=blue)

[![License](https://img.shields.io/github/license/abapPM/ABAP-Markdown?label=License&color=success)](https://github.com/abapPM/ABAP-Markdown/blob/main/LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg?color=success)](https://github.com/abapPM/.github/blob/main/CODE_OF_CONDUCT.md)
[![REUSE Status](https://api.reuse.software/badge/github.com/abapPM/ABAP-Markdown)](https://api.reuse.software/info/github.com/abapPM/ABAP-Markdown)

# Markdown for ABAP

This is a full-featured markdown parser and renderer for ABAP.

- 100% ABAP
- Fully tested with automated ABAP unit test cases
- Parses GitHub flavored Markdown

Compared to the original [ABAP Markdown](https://github.com/koemaeda/abap-markdown), the following has been added:

- Option to render href and img src links with different root
- Option to use sapevent for launching links in external browser
- Option to set root path for internal links
- Normalizing of link paths
- Support for sapevent as protocol
- Syntax highlighting (based on abapGit + diff + markdown)
- Support for internal links (`# Heading {#custom-id}`)
- Support for strikethrough, subscript, superscript, highlight
- Support for task list (`[ ] or [x] task`)
- Support for GitHub alerts

NO WARRANTIES, [MIT License](https://github.com/abapPM/ABAP-Markdown/blob/main/LICENSE)

## Usage

Render markdown as HTML:

```abap
DATA(markdown_as_html) = NEW zcl_markdown( )->text( raw_markdown ).
```

Get the CSS required to render the HTML correctly:

```abap
DATA(styles) = zcl_markdown=>styles( ).
```

You can set options to render HREF and IMG src links with different root, to set root path for internal links, or use sapevent for launching links in external browser:

```abap
DATA(markdown_service) = NEW zcl_markdown(
  root_href = root_href
  root_img  = root_img
  path      = path
  sapevent  = abap_true ).
```

Option | Description | Example
-------|-------------|--------
`root_href` | Absolute URL + path to prefix any HREF links        | `https://github.com/abapGit/abapGit/blob/main`
`root_img`  | Absolute URL + path to prefix any IMG src links     | `https://github.com/abapGit/abapGit/raw/main`
`path`      | Relative path to markdown file (if it's not in `/`) | `src/docs`
`sapevent`  | Flag to change href links to `sapevent` protocol    | `abap_true`

You can change render modes with the following methods:

Method | Default | Description
-------|---------|------------
`set_safe_mode`      | `abap_false` | Process untrusted user-input (see [Parsedown](https://github.com/erusev/parsedown/blob/master/README.md#security))
`set_markup_escaped` | `abap_false` | Escape HTML in trusted input (see [Parsedown](https://github.com/erusev/parsedown/blob/master/README.md#escaping-html))
`set_breaks_enabled` | `abap_false` | Allow empty lines in markdown (rendered as `<br />`)
`set_urls_linked`    | `abap_true`  | Change inline URLs to HREF links

## Example

```abap
DATA(html) = NEW zcl_markdown( )->text( 'Hello, _World_!' ).
WRITE / html.
```

Output:

```html
<p>Hello, <em>World</em>!</p>
```

## Prerequisites

SAP Basis 7.50 or higher

## Installation

Install `markdown` as a global module in your system using [apm](https://abappm.com).

or

Specify the `markdown` module as a dependency in your project and import it to your namespace using [apm](https://abappm.com).

## Contributions

All contributions are welcome! Read our [Contribution Guidelines](https://github.com/abapPM/ABAP-Markdown/blob/main/CONTRIBUTING.md), fork this repo, and create a pull request.

You can install the developer version of ABAP MARKDOWN using [abapGit](https://github.com/abapGit/abapGit) either by creating a new online repository for `https://github.com/abapPM/ABAP-Markdown`.

Recommended SAP package: `$MARKDOWN`

## Attribution

This project includes the code for the following open-source projects. Please support them if you can!

- [ABAP Markdown](https://github.com/koemaeda/abap-markdown), Guilherme Maeda, [MIT](https://github.com/koemaeda/abap-markdown/blob/master/LICENSE)
- [Parsedown](https://github.com/erusev/parsedown), Emanuil Rusev, [MIT](https://github.com/erusev/parsedown/blob/master/LICENSE.txt)

## About

Made with ❤ in Canada

Copyright 2025 apm.to Inc. <https://apm.to>

Follow [@marcf.be](https://bsky.app/profile/marcf.be) on Blueksy and [@marcfbe](https://linkedin.com/in/marcfbe) or LinkedIn
