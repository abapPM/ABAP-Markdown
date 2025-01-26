![Version](https://img.shields.io/endpoint?url=https://shield.abappm.com/github/abapPM/ABAP-Markdown/src/zcl_markdown.clas.abap/c_version&label=Version&color=blue)

[![License](https://img.shields.io/github/license/abapPM/ABAP-Markdown?label=License&color=success)](https://github.com/abapPM/ABAP-Markdown/blob/main/LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg?color=success)](https://github.com/abapPM/.github/blob/main/CODE_OF_CONDUCT.md)
[![REUSE Status](https://api.reuse.software/badge/github.com/abapPM/ABAP-Markdown)](https://api.reuse.software/info/github.com/abapPM/ABAP-Markdown)

# Markdown for ABAP

...

NO WARRANTIES, [MIT License](https://github.com/abapPM/ABAP-Markdown/blob/main/LICENSE)

## Usage


```abap
DATA(markdown_as_html) = NEW zcl_markdown( )->text( raw_markdown ).
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

Made with ❤️ in Canada

Copyright 2025 apm.to Inc. <https://apm.to>

Follow [@marcf.be](https://bsky.app/profile/marcf.be) on Blueksy and [marcfbe](https://linkedin.com/in/marcfbe) or LinkedIn
