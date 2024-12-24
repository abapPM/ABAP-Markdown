CLASS zcl_markdown DEFINITION
  PUBLIC
  CREATE PUBLIC.

************************************************************************
* Markdown Renderer
*
* https://github.com/koemaeda/abap-markdown
*
* Copyright (c) 2015 Guilherme Maeda
* SPDX-License-Identifier: MIT
************************************************************************
* Added by apm:
* - Option to render href and img src links with different root
* - Option to use sapevent for launching links in external browser
* - Option to set root path for internal links
* - Normalizing of link paths
* - Support for sapevent as protocol
* - Syntax highlighting (based on abapGit + diff + markdown)
* - Support for internal links (# Heading {#custom-id})
* - Support for strikethrough, subscript, superscript, highlight
* - Support for task list ([ ] or [x] task)
* - Fix a few regular expressions
* - Support for GitHub alerts
* - Fix for escaped | in tables
* - CSS
************************************************************************
  PUBLIC SECTION.

    CONSTANTS version TYPE string VALUE '1.4.0' ##NEEDED.

    CLASS-METHODS styles
      RETURNING
        VALUE(result) TYPE string.

    METHODS text
      IMPORTING
        VALUE(text)   TYPE clike
      RETURNING
        VALUE(markup) TYPE string.

    METHODS set_breaks_enabled
      IMPORTING
        VALUE(breaks_enabled) TYPE clike
      RETURNING
        VALUE(this)           TYPE REF TO zcl_markdown.

    METHODS set_markup_escaped
      IMPORTING
        VALUE(markup_escaped) TYPE clike
      RETURNING
        VALUE(this)           TYPE REF TO zcl_markdown.

    METHODS set_urls_linked
      IMPORTING
        VALUE(urls_linked) TYPE clike
      RETURNING
        VALUE(this)        TYPE REF TO zcl_markdown.

    METHODS set_safe_mode
      IMPORTING
        !iv_safe_mode TYPE clike
      RETURNING
        VALUE(this)   TYPE REF TO zcl_markdown.

    METHODS constructor
      IMPORTING
        !root_href TYPE string OPTIONAL
        !root_img  TYPE string OPTIONAL
        !path      TYPE string OPTIONAL
        !sapevent  TYPE abap_bool DEFAULT abap_false.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_element_attribute,
        name  TYPE string,
        value TYPE string,
      END OF ty_element_attribute,
      ty_t_element_attribute TYPE STANDARD TABLE OF ty_element_attribute WITH KEY name.

    TYPES:
      BEGIN OF ty_element0,
        name       TYPE string,
        handler    TYPE string,
        attributes TYPE ty_t_element_attribute,
        text       TYPE string,
        lines      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_element0,
      ty_t_element0 TYPE STANDARD TABLE OF ty_element0 WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_element1,
        name       TYPE string,
        handler    TYPE string,
        attributes TYPE ty_t_element_attribute,
        text       TYPE string,
        texts      TYPE ty_t_element0,
        lines      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_element1,
      ty_t_element1 TYPE STANDARD TABLE OF ty_element1 WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_element2,
        name       TYPE string,
        handler    TYPE string,
        attributes TYPE ty_t_element_attribute,
        text       TYPE string,
        texts      TYPE ty_t_element1,
        lines      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_element2,
      ty_t_element2 TYPE STANDARD TABLE OF ty_element2 WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_element3,
        name       TYPE string,
        handler    TYPE string,
        attributes TYPE ty_t_element_attribute,
        text       TYPE string,
        texts      TYPE ty_t_element2,
        lines      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_element3,
      ty_t_element3 TYPE STANDARD TABLE OF ty_element3 WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_element4,
        name       TYPE string,
        handler    TYPE string,
        attributes TYPE ty_t_element_attribute,
        text       TYPE string,
        texts      TYPE ty_t_element3,
        lines      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_element4,
      ty_t_element4 TYPE STANDARD TABLE OF ty_element4 WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_element5,
        name       TYPE string,
        handler    TYPE string,
        attributes TYPE ty_t_element_attribute,
        text       TYPE ty_element4,
        texts      TYPE ty_t_element4,
        lines      TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_element5.
*    TYPES:
*      ty_t_element5 TYPE STANDARD TABLE OF ty_element5 WITH DEFAULT KEY

    TYPES ty_element TYPE ty_element5.
*    TYPES:
*      ty_t_element TYPE STANDARD TABLE OF ty_element WITH DEFAULT KEY

    TYPES:
      BEGIN OF ty_block,
        "// general block fields
        continuable TYPE abap_bool,
        identified  TYPE abap_bool,
        interrupted TYPE abap_bool,
        hidden      TYPE abap_bool,
        closed      TYPE abap_bool,
        type        TYPE string,
        markup      TYPE string,
        element     TYPE ty_element,
        "// specific block fields
        char        TYPE c LENGTH 1,
        complete    TYPE abap_bool,
        indent      TYPE i,
        pattern     TYPE string,
        li          TYPE ty_element4,
        loose       TYPE abap_bool,
        name        TYPE string,
        depth       TYPE i,
        void        TYPE abap_bool,
        alignments  TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
      END OF ty_block.

    TYPES:
      BEGIN OF ty_line,
        body   TYPE string,
        indent TYPE i,
        text   TYPE string,
      END OF ty_line.

    TYPES:
      BEGIN OF ty_excerpt,
        text    TYPE string,
        context TYPE string,
      END OF ty_excerpt.

    TYPES:
      BEGIN OF ty_inline,
        position TYPE i,
        markup   TYPE string,
        extent   TYPE string,
        element  TYPE ty_element,
      END OF ty_inline.

    ">>> apm
    DATA:
      BEGIN OF config,
        root_href TYPE string,
        root_img  TYPE string,
        sapevent  TYPE abap_bool,
        path      TYPE string,
        path_util TYPE REF TO zcl_markdown_path,
      END OF config.
    "<<< apm

    DATA breaks_enabled TYPE abap_bool.
    DATA markup_escaped TYPE abap_bool.
    DATA urls_linked TYPE abap_bool VALUE abap_true ##NO_TEXT.
    DATA safe_mode TYPE abap_bool.
    DATA block_types TYPE REF TO lcl_hashmap.
    DATA unmarked_block_types TYPE REF TO lcl_string_array.
    DATA inline_types TYPE REF TO lcl_hashmap.
    "DATA inline_marker_list TYPE string VALUE '!"*_&[:<>`~\\' ##NO_TEXT
    DATA inline_marker_list TYPE string VALUE '!"*_&[:<>`~\\=^' ##NO_TEXT. " apm
    DATA definition_data TYPE REF TO lcl_hashmap.
    DATA special_characters TYPE REF TO lcl_string_array.
    DATA strong_regex TYPE REF TO lcl_hashmap.
    DATA em_regex TYPE REF TO lcl_hashmap.
    DATA regex_html_attribute TYPE string VALUE '[a-zA-Z_:][\w:.-]*(?:\s*=\s*(?:[^"''=<>`\s]+|"[^"]*"|''[^'']*''))?' ##NO_TEXT.
    DATA void_elements TYPE REF TO lcl_string_array.
    DATA text_level_elements TYPE REF TO lcl_string_array.
    DATA safe_links_whitelist TYPE REF TO lcl_string_array.
    DATA:
      methods TYPE STANDARD TABLE OF string.

    CLASS-METHODS htmlspecialchars
      IMPORTING
        !input        TYPE string
        !ent_html401  TYPE abap_bool DEFAULT abap_true
        !ent_noquotes TYPE abap_bool OPTIONAL
        !ent_quotes   TYPE abap_bool OPTIONAL
      RETURNING
        VALUE(output) TYPE string.

    CLASS-METHODS trim
      IMPORTING
        !str         TYPE string
        VALUE(mask)  TYPE string DEFAULT ' \t\n\r'
      RETURNING
        VALUE(r_str) TYPE string.

    CLASS-METHODS chop
      IMPORTING
        !str         TYPE string
        VALUE(mask)  TYPE string DEFAULT ' \t\n\r'
      RETURNING
        VALUE(r_str) TYPE string.

    CLASS-METHODS magic_move
      IMPORTING
        !from TYPE any
        !name TYPE clike OPTIONAL
      CHANGING
        !to   TYPE any.

    CLASS-METHODS match_marked_string
      IMPORTING
        VALUE(marker) TYPE string
        !subject      TYPE string
      EXPORTING
        VALUE(m0)     TYPE string
        VALUE(m1)     TYPE string
      EXCEPTIONS
        not_found.

    CLASS-METHODS _escape
      IMPORTING
        !text         TYPE string
        !allow_quotes TYPE abap_bool OPTIONAL
      RETURNING
        VALUE(output) TYPE string.

    CLASS-METHODS string_at_start
      IMPORTING
        !haystack     TYPE string
        !needle       TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS _lines
      IMPORTING
        !lines        TYPE STANDARD TABLE
      RETURNING
        VALUE(markup) TYPE string.

    METHODS block_code
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_code_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_code_complete
      IMPORTING
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_comment
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_comment_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_fencedcode
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_fencedcode_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_fencedcode_complete
      IMPORTING
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_header
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_list
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_list_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_list_complete
      IMPORTING
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_quote
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_quote_complete
      IMPORTING
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_quote_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_rule
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_setextheader
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_markup
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_markup_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_reference
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_table
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block OPTIONAL
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS block_table_continue
      IMPORTING
        !line          TYPE ty_line
        !block         TYPE ty_block
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS paragraph
      IMPORTING
        !line          TYPE ty_line
      RETURNING
        VALUE(r_block) TYPE ty_block.

    METHODS line
      IMPORTING
        !element      TYPE ty_element4
      RETURNING
        VALUE(markup) TYPE string.

    METHODS inline_code
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_emailtag
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_emphasis
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_escapesequence
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_image
      IMPORTING
        VALUE(excerpt)  TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_link
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_markup
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_specialcharacter
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_strikethrough
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_url
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    METHODS inline_urltag
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.

    ">>> apm
    METHODS inline_highlight
      IMPORTING
        !excerpt        TYPE ty_excerpt
      RETURNING
        VALUE(r_inline) TYPE ty_inline.
    "<<< apm

    METHODS unmarked_text
      IMPORTING
        !text         TYPE string
      RETURNING
        VALUE(r_text) TYPE string.

    METHODS element
      IMPORTING
        !element      TYPE any
      RETURNING
        VALUE(markup) TYPE string.

    METHODS elements
      IMPORTING
        !elements     TYPE STANDARD TABLE
      RETURNING
        VALUE(markup) TYPE string.

    METHODS li
      IMPORTING
        !lines        TYPE STANDARD TABLE
      RETURNING
        VALUE(markup) TYPE string.

    METHODS filter_unsafe_url_in_attribute
      IMPORTING
        !element         TYPE ty_element
        !attribute       TYPE string
      RETURNING
        VALUE(r_element) TYPE ty_element.

    METHODS sanitise_element
      IMPORTING
        !element         TYPE ty_element
      RETURNING
        VALUE(r_element) TYPE ty_element.

    ">>> apm
    METHODS _adjust_link
      IMPORTING
        !root           TYPE string
        !source         TYPE string
      RETURNING
        VALUE(r_source) TYPE string.

    METHODS _adjust_a_href
      IMPORTING
        !source         TYPE string
      RETURNING
        VALUE(r_source) TYPE string.

    METHODS _adjust_img_src
      IMPORTING
        !source         TYPE string
      RETURNING
        VALUE(r_source) TYPE string.

    METHODS _adjust_markup
      IMPORTING
        !source         TYPE string
      RETURNING
        VALUE(r_source) TYPE string.

    METHODS syntax_highlighter
      IMPORTING
        !element      TYPE any
      RETURNING
        VALUE(markup) TYPE string.
    "<<< apm
ENDCLASS.



CLASS zcl_markdown IMPLEMENTATION.


  METHOD block_code.
    IF block IS NOT INITIAL AND
       block-type IS INITIAL AND
       block-interrupted IS INITIAL.
      RETURN.
    ENDIF.

    IF line-indent >= 4.
      r_block-element-name = 'pre'.
      r_block-element-handler = 'element'.
      r_block-element-text-name = 'code'.
      r_block-element-text-text = line-body+4.
    ENDIF.
  ENDMETHOD.                    "block_code


  METHOD block_code_complete.
    r_block = block.
    r_block-element-text-text = r_block-element-text-text.
  ENDMETHOD.                    "block_code_complete


  METHOD block_code_continue.
    DATA: lv_text TYPE string.

    IF line-indent >= 4.
      r_block = block.

      IF block-interrupted IS NOT INITIAL.
        CONCATENATE r_block-element-text-text %_newline
          INTO r_block-element-text-text RESPECTING BLANKS.
        CLEAR r_block-interrupted.
      ENDIF.

      lv_text = line-body+4.
      CONCATENATE r_block-element-text-text %_newline lv_text
        INTO r_block-element-text-text RESPECTING BLANKS.
    ENDIF.
  ENDMETHOD.                    "block_code_continue


  METHOD block_comment.
    CHECK markup_escaped IS INITIAL.

    IF strlen( line-text ) >= 3 AND
       line-text+3(1) = '-' AND
       line-text+2(1) = '-' AND
       line-text+1(1) = '!'.
      r_block-markup = line-body.

      FIND REGEX '-->$' IN line-text.
      IF sy-subrc = 0.
        r_block-closed = abap_true.
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "block_Comment


  METHOD block_comment_continue.
    CHECK block-closed IS INITIAL.
    r_block = block.

    CONCATENATE r_block-markup %_newline line-body INTO r_block-markup.

    FIND REGEX '-->\s*$' IN line-text.  " apm
    IF sy-subrc = 0.
      r_block-closed = abap_true.
    ENDIF.
  ENDMETHOD.                    "block_Comment_Continue


  METHOD block_fencedcode.
    DATA:
      lv_regex TYPE string,
      lv_m1    TYPE string.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_block-element-text-attributes.

    lv_regex = '^[' && line-text(1) && ']{3,}[ ]*([^`]+)?[ ]*$'.
    FIND REGEX lv_regex IN line-text SUBMATCHES lv_m1.
    IF sy-subrc = 0.
      IF lv_m1 IS NOT INITIAL.
        APPEND INITIAL LINE TO r_block-element-text-attributes ASSIGNING <attribute>.
        <attribute>-name = 'class'.
        CONCATENATE 'language-' lv_m1 INTO <attribute>-value.
      ENDIF.

      r_block-char = line-text(1).
      r_block-element-name = 'pre'.
      r_block-element-handler = 'element'.
      r_block-element-text-name = 'code'.
      r_block-element-text-handler = 'syntax_highlighter'. " apm
    ENDIF.
  ENDMETHOD.                    "block_Fenced_Code


  METHOD block_fencedcode_complete.
    r_block = block.
    r_block-element-text-text = r_block-element-text-text.
  ENDMETHOD.                    "block_Fenced_Code_Complete


  METHOD block_fencedcode_continue.
    DATA lv_regex TYPE string.

    CHECK block-complete IS INITIAL.
    r_block = block.

    IF r_block-interrupted IS NOT INITIAL.
      CONCATENATE r_block-element-text-text %_newline INTO r_block-element-text-text.
      CLEAR r_block-interrupted.
    ENDIF.

    CONCATENATE '^' block-char '{3,}[ ]*$' INTO lv_regex.
    FIND REGEX lv_regex IN line-text.
    IF sy-subrc = 0.
      r_block-element-text-text = r_block-element-text-text+1.
      r_block-complete = abap_true.
      RETURN.
    ENDIF.

    CONCATENATE
      r_block-element-text-text %_newline line-body
    INTO r_block-element-text-text.
  ENDMETHOD.                    "block_Fenced_Code_Continue


  METHOD block_header.
    DATA:
      lv_level   TYPE i VALUE 1,
      lv_h_level TYPE n,
      lv_pos     TYPE i,
      lv_id      TYPE string.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_block-element-attributes.

    CHECK strlen( line-text ) > 1 AND line-text+1(1) IS NOT INITIAL.

    WHILE lv_level < strlen( line-text ) AND line-text+lv_level(1) = '#'.
      lv_level = lv_level + 1.
    ENDWHILE.

    CHECK lv_level <= 6.

    lv_h_level = lv_level.
    CONCATENATE 'h' lv_h_level INTO r_block-element-name.
    r_block-element-text-text = line-text.
    r_block-element-text-text = trim(
      str  = r_block-element-text-text
      mask = ' #' ).
    CONDENSE r_block-element-text-text.
    r_block-element-handler = 'line'.

    ">>> apm
    FIND REGEX ' \{(#[\w-]*)\}' IN r_block-element-text-text IGNORING CASE
      MATCH OFFSET lv_pos SUBMATCHES lv_id.
    IF sy-subrc = 0.
      " # Heading {#custom-id}
      APPEND INITIAL LINE TO r_block-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'id'.
      <attribute>-value = lv_id.
      r_block-element-text-text = r_block-element-text-text(lv_pos).
    ELSE.
      lv_id = replace(
        val   = to_lower( r_block-element-text-text )
        regex = `[^\w\s\-]`
        with  = ``
        occ   = 0 ).
      lv_id = replace(
        val   = lv_id
        regex = `\s`
        with  = `-`
        occ   = 0 ).
      " If there are HTML tags, no id
      IF lv_id CA '<>'.
        lv_id = '#'.
      ENDIF.
      APPEND INITIAL LINE TO r_block-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'id'.
      <attribute>-value = lv_id.
    ENDIF.
    "<<< apm
  ENDMETHOD.                    "block_Header


  METHOD block_list.
    DATA:
      lv_name       TYPE string,
      lv_pattern    TYPE string,
      lv_regex      TYPE string,
      lv_m1         TYPE string,
      lv_m2         TYPE string,
      lv_list_start TYPE string.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_block-element-attributes.

    IF line-text(1) <= '-'.
      lv_name = 'ul'.
      lv_pattern = '[*+-]'.
    ELSE.
      lv_name = 'ol'.
      lv_pattern = '[0-9]+[.]'.
    ENDIF.

    lv_regex = '^(' && lv_pattern && '[ ]+)(.*)'.
    FIND REGEX lv_regex IN line-text SUBMATCHES lv_m1 lv_m2.
    IF sy-subrc = 0.
      r_block-indent = line-indent.

      ">>> apm
      " We could distinguish between *,+,- lists
      "IF lv_name = 'ul'
      "  r_block-pattern = |[{ lv_m1(1) }]|
      "ELSE
      r_block-pattern = lv_pattern.
      "ENDIF
      "<<< apm

      r_block-element-name = lv_name.
      r_block-element-handler = 'elements'.

      IF r_block-element-name = 'ol'.
        lv_list_start = substring_before(
          val  = line-text
          sub  = '.'
          case = abap_false ).
        IF lv_list_start <> '1'.
          APPEND INITIAL LINE TO r_block-element-attributes ASSIGNING <attribute>.
          <attribute>-name = 'start'.
          <attribute>-value = lv_list_start.
        ENDIF.
      ENDIF.

      r_block-li-name = 'li'.
      r_block-li-handler = 'li'.
      APPEND lv_m2 TO r_block-li-lines.
    ENDIF.
  ENDMETHOD.                    "block_List


  METHOD block_list_complete.
    FIELD-SYMBOLS:
      <li>        LIKE LINE OF r_block-element-texts,
      <last_line> LIKE LINE OF <li>-lines.

    r_block = block.

    APPEND r_block-li TO r_block-element-texts.

    IF r_block-loose IS NOT INITIAL.
      LOOP AT r_block-element-texts ASSIGNING <li>.
        READ TABLE <li>-lines INDEX lines( r_block-li-lines ) ASSIGNING <last_line>.
        IF sy-subrc = 0 AND <last_line> IS NOT INITIAL.
          APPEND INITIAL LINE TO <li>-lines.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.                    "block_List_complete


  METHOD block_list_continue.
    DATA:
      lv_regex TYPE string,
      lv_m1    TYPE string,
      lv_text  TYPE string,
      ls_block TYPE ty_block.

    r_block = block.

    lv_regex = '^' && block-pattern && '(?:[ ]+(.*)|$)'.
    IF block-indent = line-indent.
      FIND REGEX lv_regex IN line-text SUBMATCHES lv_m1.
      IF sy-subrc = 0.
        IF r_block-interrupted IS NOT INITIAL.
          APPEND INITIAL LINE TO r_block-li-lines.
          r_block-loose = abap_true.
          CLEAR r_block-interrupted.
        ENDIF.
        APPEND r_block-li TO r_block-element-texts.

        CLEAR r_block-li.
        r_block-li-name = 'li'.
        r_block-li-handler = 'li'.
        APPEND lv_m1 TO r_block-li-lines.
        RETURN.
      ENDIF.
    ENDIF.

    IF line-text(1) = '['.
      ls_block = block_reference( line ).
      IF ls_block IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    IF r_block-interrupted IS INITIAL.
      lv_text = line-body.
      REPLACE ALL OCCURRENCES OF REGEX '^[ ]{0,4}' IN lv_text WITH ''.
      APPEND lv_text TO r_block-li-lines.
      RETURN.
    ENDIF.

    IF line-indent > 0.
      APPEND INITIAL LINE TO r_block-li-lines.
      lv_text = line-body.
      REPLACE ALL OCCURRENCES OF REGEX '^[ ]{0,4}' IN lv_text WITH ''.
      APPEND lv_text TO r_block-li-lines.
      CLEAR r_block-interrupted.
      RETURN.
    ENDIF.

    CLEAR r_block.
  ENDMETHOD.                    "block_List_Continue


  METHOD block_markup.
    DATA:
      lv_regex             TYPE string,
      lv_m1                TYPE string,
      lv_m2                TYPE string,
      lv_length            TYPE i,
      lv_index             TYPE i,
      lv_remainder         TYPE string,
      lv_remainder_trimmed TYPE string.

    CHECK: markup_escaped IS INITIAL,
           safe_mode IS INITIAL.

    lv_regex = '^<(\w*)(?:[ ]*' && regex_html_attribute && ')*[ ]*(/)?>'.
    FIND FIRST OCCURRENCE OF REGEX lv_regex IN line-text SUBMATCHES lv_m1 lv_m2
      MATCH LENGTH lv_length.
    IF sy-subrc = 0.

      lv_index = text_level_elements->find_val( lv_m1 ).
      CHECK lv_index = 0.

      r_block-name = lv_m1.
      r_block-depth = 0.
      r_block-markup = _adjust_markup( line-text ). " apm

      lv_remainder = line-text+lv_length.
      lv_remainder_trimmed = trim( lv_remainder ).

      lv_index = void_elements->find_val( lv_m1 ).

      IF lv_remainder_trimmed IS INITIAL.
        IF lv_m2 IS NOT INITIAL OR lv_index <> 0.
          r_block-closed = abap_true.
          r_block-void = abap_true.
        ENDIF.
      ELSE.
        IF lv_m2 IS NOT INITIAL OR lv_index <> 0.
          CLEAR r_block.
          RETURN.
        ENDIF.

        CONCATENATE '</' lv_m1 '>[ ]*$' INTO lv_regex.
        FIND FIRST OCCURRENCE OF REGEX lv_regex IN lv_remainder IGNORING CASE.
        IF sy-subrc = 0.
          r_block-closed = abap_true.
        ENDIF.
      ENDIF.

    ENDIF. "regex sy-subrc = 0
  ENDMETHOD.                    "block_Markup


  METHOD block_markup_continue.
    DATA:
      lv_regex TYPE string,
      lv_body  TYPE string.

    CHECK block-closed IS INITIAL.

    r_block = block.

    CONCATENATE '^<' r_block-name '(?:[ ]*' regex_html_attribute ')*[ ]*>' INTO lv_regex.
    FIND REGEX lv_regex IN line-text IGNORING CASE. "open
    IF sy-subrc = 0.
      r_block-depth = r_block-depth + 1.
    ENDIF.

    CONCATENATE '</' r_block-name '>[ ]*$' INTO lv_regex.
    FIND REGEX lv_regex IN line-text IGNORING CASE. "close
    IF sy-subrc = 0.
      IF r_block-depth > 0.
        r_block-depth = r_block-depth - 1.
      ELSE.
        r_block-closed = abap_true.
      ENDIF.
    ENDIF.

    IF r_block-interrupted IS NOT INITIAL.
      CONCATENATE r_block-markup %_newline INTO r_block-markup.
      CLEAR r_block-interrupted.
    ENDIF.

    ">>> apm
    lv_body = _adjust_markup( line-body ).
    CONCATENATE r_block-markup %_newline lv_body INTO r_block-markup.
    "<<< apm
  ENDMETHOD.                    "block_Markup_Continue


  METHOD block_quote.
    DATA lv_m1 TYPE string.

    FIND REGEX '^>[ ]?(.*)' IN line-text SUBMATCHES lv_m1.
    IF sy-subrc = 0.
      SHIFT lv_m1 LEFT DELETING LEADING space.
      r_block-element-name = 'blockquote'.
      r_block-element-handler = '_lines'.
      " >>> apm
      IF lcl_alerts=>get( lv_m1 ) IS NOT INITIAL.
        APPEND INITIAL LINE TO r_block-element-attributes ASSIGNING FIELD-SYMBOL(<attribute>).
        <attribute>-name  = 'class'.
        <attribute>-value = lcl_alerts=>get( lv_m1 )-class.
        lv_m1 = lcl_alerts=>get( lv_m1 )-tag.
      ENDIF.
      " <<< apm
      APPEND lv_m1 TO r_block-element-lines.
    ENDIF.
  ENDMETHOD.                    "block_Quote


  METHOD block_quote_complete.
    r_block = block.
  ENDMETHOD.


  METHOD block_quote_continue.
    DATA lv_m1 TYPE string.

    IF line-text(1) = '>'.
      r_block = block.
      FIND REGEX '^>[ ]?(.*)' IN line-text SUBMATCHES lv_m1.
      IF sy-subrc = 0.
        " >>> apm
        IF lcl_alerts=>get( lv_m1 ) IS NOT INITIAL.
          CLEAR r_block.
          RETURN.
        ENDIF.
        " <<< apm
        SHIFT lv_m1 LEFT DELETING LEADING space.
        IF r_block-interrupted IS NOT INITIAL.
          APPEND INITIAL LINE TO r_block-element-lines.
          CLEAR r_block-interrupted.
        ENDIF.

        APPEND lv_m1 TO r_block-element-lines.
        RETURN.
      ENDIF.
    ENDIF.

    IF block-interrupted IS INITIAL.
      r_block = block.
      APPEND line-text TO r_block-element-lines.
    ENDIF.
  ENDMETHOD.                    "block_Quote_Continue


  METHOD block_reference.
    DATA:
      lv_m1       TYPE string,
      lv_m2       TYPE string,
      lv_m3       TYPE string,
      lv_m4       TYPE string,
      lv_id       TYPE string,
      lo_ref_map  TYPE REF TO lcl_hashmap,
      lo_ref_item TYPE REF TO lcl_hashmap,
      lo_ref_val  TYPE REF TO lcl_string.

    FIND REGEX '^\[(.+)\]:[ ]*<?(\S+)>?([ ]+["''(](.+)["'')])?[ ]*$'
      IN line-text SUBMATCHES lv_m1 lv_m2 lv_m3 lv_m4.
    IF sy-subrc = 0.
      lv_id = lv_m1.
      TRANSLATE lv_id TO LOWER CASE.

      lo_ref_map ?= definition_data->get( 'Reference' ).
      lo_ref_item ?= lo_ref_map->get( lv_id ).

      lo_ref_val ?= lo_ref_item->get( 'url' ).
      lo_ref_val->data = lv_m2.
      IF lv_m3 IS NOT INITIAL.
        lo_ref_val ?= lo_ref_item->get( 'title' ).
        lo_ref_val->data = lv_m4.
      ENDIF.

      r_block-hidden = abap_true.
    ENDIF.
  ENDMETHOD.                    "block_Reference


  METHOD block_rule.
    DATA lv_regex TYPE string.

    CONCATENATE '^([' line-text(1) '])([ ]*\1){2,}[ ]*$' INTO lv_regex.
    FIND REGEX lv_regex IN line-text.
    IF sy-subrc = 0.
      r_block-element-name = 'hr'.
    ENDIF.
  ENDMETHOD.                    "block_Rule


  METHOD block_setextheader.
    CHECK block IS NOT INITIAL AND block-type IS INITIAL AND
          block-interrupted IS INITIAL.

    IF line-text CO line-text(1).
      r_block = block.
      IF line-text(1) = '='.
        r_block-element-name = 'h1'.
      ELSE.
        r_block-element-name = 'h2'.
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "block_SetextHeader


  METHOD block_table.
    DATA:
      lv_divider         TYPE string,
      lt_divider_cells   TYPE TABLE OF string,
      lv_len             TYPE i,
      lv_header          TYPE string,
      lt_header_cells    TYPE TABLE OF string,
      lv_index           TYPE i,
      lt_header_elements TYPE ty_t_element2.

    FIELD-SYMBOLS:
      <header_cell>    LIKE LINE OF lt_header_cells,
      <header_element> LIKE LINE OF lt_header_elements,
      <attribute>      LIKE LINE OF <header_element>-attributes,
      <divider_cell>   LIKE LINE OF lt_divider_cells,
      <alignment>      LIKE LINE OF r_block-alignments,
      <element_text1>  LIKE LINE OF r_block-element-texts,
      <element_text2>  LIKE LINE OF <element_text1>-texts.

    CHECK NOT ( block IS INITIAL OR
                block-type IS NOT INITIAL OR
                block-interrupted IS NOT INITIAL ).

    FIND '|' IN block-element-text-text.
    IF sy-subrc = 0 AND line-text CO ' -:|'.
      r_block = block.

      lv_divider = trim( line-text ).
      lv_divider = trim(
        str  = lv_divider
        mask = '|' ).

      " >>> apm
      " Replace escaped \|
      lv_divider = replace(
        val  = lv_divider
        sub  = '\|'
        with = '%bar%'
        occ  = 0 ).
      " <<< apm
      SPLIT lv_divider AT '|' INTO TABLE lt_divider_cells.
      LOOP AT lt_divider_cells ASSIGNING <divider_cell>.
        <divider_cell> = trim( <divider_cell> ).
        <divider_cell> = replace(
         val  = <divider_cell>
         sub  = '%bar%'
         with = '|'
         occ  = 0 ). " apm
        CHECK <divider_cell> IS NOT INITIAL.
        APPEND INITIAL LINE TO r_block-alignments ASSIGNING <alignment>.

        IF <divider_cell>(1) = ':'.
          <alignment> = 'left'.
        ENDIF.

        lv_len = strlen( <divider_cell> ) - 1.
        IF <divider_cell>+lv_len(1) = ':'.
          IF <alignment> = 'left'.
            <alignment> = 'center'.
          ELSE.
            <alignment> = 'right'.
          ENDIF.
        ENDIF.
      ENDLOOP. "lt_divider_cells

      "# ~

      lv_header = trim( r_block-element-text-text ).
      lv_header = trim(
        str  = lv_header
        mask = '|' ).

      " >>> apm
      " Replace escaped \|
      lv_header = replace(
        val  = lv_header
        sub  = '\|'
        with = '%bar%'
        occ  = 0 ).
      " <<< apm
      SPLIT lv_header AT '|' INTO TABLE lt_header_cells.
      LOOP AT lt_header_cells ASSIGNING <header_cell>.
        lv_index = sy-tabix.
        <header_cell> = trim( <header_cell> ).
        <header_cell> = replace(
         val  = <header_cell>
         sub  = '%bar%'
         with = '|'
         occ  = 0 ). " apm

        APPEND INITIAL LINE TO lt_header_elements ASSIGNING <header_element>.
        <header_element>-name = 'th'.
        <header_element>-text = <header_cell>.
        <header_element>-handler = 'line'.

        READ TABLE r_block-alignments ASSIGNING <alignment> INDEX lv_index.
        IF sy-subrc = 0 AND <alignment> IS NOT INITIAL.
          APPEND INITIAL LINE TO <header_element>-attributes ASSIGNING <attribute>.
          <attribute>-name = 'style'.
          CONCATENATE 'text-align: ' <alignment> ';'
            INTO <attribute>-value RESPECTING BLANKS.
        ENDIF.

      ENDLOOP.

      "# ~

      r_block-identified = abap_true.
      r_block-element-name = 'table'.
      r_block-element-handler = 'elements'.

      APPEND INITIAL LINE TO r_block-element-texts ASSIGNING <element_text1>.
      <element_text1>-name = 'thead'.
      <element_text1>-handler = 'elements'.
      APPEND INITIAL LINE TO <element_text1>-texts ASSIGNING <element_text2>.
      <element_text2>-name = 'tr'.
      <element_text2>-handler = 'elements'.
      <element_text2>-texts = lt_header_elements.

      APPEND INITIAL LINE TO r_block-element-texts ASSIGNING <element_text1>.
      <element_text1>-name = 'tbody'.
      <element_text1>-handler = 'elements'.
    ENDIF. "sy-subrc = 0 and line-text na ' -:|'.
  ENDMETHOD.                    "block_Table


  METHOD block_table_continue.
    DATA:
      lv_row     TYPE string,
      lt_matches TYPE match_result_tab,
      lv_tabix   TYPE i,
      lv_index   TYPE i,
      lv_count   TYPE i,
      lv_cell    TYPE string.

    FIELD-SYMBOLS:
      <match>     LIKE LINE OF lt_matches,
      <match2>    LIKE LINE OF lt_matches,
      <text1>     LIKE LINE OF r_block-element-texts,
      <text2>     LIKE LINE OF <text1>-texts,
      <text3>     LIKE LINE OF <text2>-texts,
      <alignment> LIKE LINE OF r_block-alignments,
      <attribute> LIKE LINE OF <text3>-attributes.

    CHECK block-interrupted IS INITIAL.

    IF line-text CS '|'.
      r_block = block.

      lv_row = trim( line-text ).
      lv_row = trim(
        str  = lv_row
        mask = '|' ).

      READ TABLE r_block-element-texts ASSIGNING <text1> INDEX 2.
      CHECK sy-subrc = 0.

      APPEND INITIAL LINE TO <text1>-texts ASSIGNING <text2>.
      <text2>-name = 'tr'.
      <text2>-handler = 'elements'.

      " >>> apm
      " Replace escaped \|
      lv_row = replace(
        val  = lv_row
        sub  = '\|'
        with = '%bar%'
        occ  = 0 ).
      " REGEX '(?:(\\[|])|[^|`]|`[^`]+`|`)+' is too greedy
      FIND ALL OCCURRENCES OF REGEX '(?:(\\[|])|[^|])+'
        IN lv_row RESULTS lt_matches.
      " <<< apm
      LOOP AT lt_matches ASSIGNING <match>.
        lv_index = sy-tabix.
        lv_cell = lv_row+<match>-offset(<match>-length).
        lv_cell = trim( lv_cell ).

        lv_cell = replace(
          val  = lv_cell
          sub  = '%bar%'
          with = '|'
          occ  = 0 ). " apm

        APPEND INITIAL LINE TO <text2>-texts ASSIGNING <text3>.
        <text3>-name = 'td'.
        <text3>-handler = 'line'.
        <text3>-text = lv_cell.

        READ TABLE r_block-alignments ASSIGNING <alignment> INDEX lv_index.
        IF sy-subrc = 0 AND <alignment> IS NOT INITIAL.
          APPEND INITIAL LINE TO <text3>-attributes ASSIGNING <attribute>.
          <attribute>-name = 'style'.
          CONCATENATE 'text-align: ' <alignment> ';'
            INTO <attribute>-value RESPECTING BLANKS.
        ENDIF.
      ENDLOOP. "lt_matches
    ENDIF. "line-text cs '|'
  ENDMETHOD.                    "block_Table_Continue


  METHOD chop.
    DATA lv_regex TYPE string.

    r_str = str.
    REPLACE ALL OCCURRENCES OF REGEX '([\.\?\*\+\|])' IN mask WITH '\\$1'.
    CONCATENATE '[' mask ']*\Z' INTO lv_regex.
    REPLACE ALL OCCURRENCES OF REGEX lv_regex IN r_str WITH ''.
  ENDMETHOD.                    "trim


  METHOD constructor.
    " Constuctor method
    " Initializes the instance constants
    DATA:
      lo_sa       TYPE REF TO lcl_string_array,
      lo_string   TYPE REF TO lcl_string,
      lo_objdescr TYPE REF TO cl_abap_objectdescr.

    FIELD-SYMBOLS <method> LIKE LINE OF lo_objdescr->methods.

    ">>> apm
    config-root_href = root_href.
    config-root_img  = root_img.
    config-path      = path.
    config-sapevent  = sapevent.

    CREATE OBJECT config-path_util.
    "<<< apm

    "#
    "# Lines
    "#
    CREATE OBJECT block_types
      EXPORTING
        value_type = 'lcl_string_array'.

    lo_sa ?= block_types->new( '#' ).
    lo_sa->append( 'Header' ).
    lo_sa ?= block_types->new( '*' ).
    lo_sa->append( 'Rule' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '+' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '-' ).
    lo_sa->append( 'SetextHeader' ).
    lo_sa->append( 'Table' ).
    lo_sa->append( 'Rule' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '0' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '1' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '2' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '3' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '4' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '5' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '6' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '7' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '8' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( '9' ).
    lo_sa->append( 'List' ).
    lo_sa ?= block_types->new( ':' ).
    lo_sa->append( 'Table' ).
    lo_sa ?= block_types->new( '<' ).
    lo_sa->append( 'Comment' ).
    lo_sa->append( 'Markup' ).
    lo_sa ?= block_types->new( '=' ).
    lo_sa->append( 'SetextHeader' ).
    lo_sa ?= block_types->new( '>' ).
    lo_sa->append( 'Quote' ).
    lo_sa ?= block_types->new( '[' ).
    lo_sa->append( 'Reference' ).
    lo_sa ?= block_types->new( '_' ).
    lo_sa->append( 'Rule' ).
    lo_sa ?= block_types->new( '`' ).
    lo_sa->append( 'FencedCode' ).
    lo_sa ?= block_types->new( '|' ).
    lo_sa->append( 'Table' ).
    lo_sa ?= block_types->new( '~' ).
    lo_sa->append( 'FencedCode' ).

    CREATE OBJECT unmarked_block_types.
    unmarked_block_types->append( 'Code' ).

    "#
    "# Inline Elements
    "#
    CREATE OBJECT inline_types
      EXPORTING
        value_type = 'lcl_string_array'.

    lo_sa ?= inline_types->new( '"' ).
    lo_sa->append( 'SpecialCharacter' ).
    lo_sa ?= inline_types->new( '!' ).
    lo_sa->append( 'Image' ).
    lo_sa ?= inline_types->new( '&' ).
    lo_sa->append( 'SpecialCharacter' ).
    lo_sa ?= inline_types->new( '*' ).
    lo_sa->append( 'Emphasis' ).
    lo_sa ?= inline_types->new( ':' ).
    lo_sa->append( 'Url' ).
    lo_sa ?= inline_types->new( '<' ).
    lo_sa->append( 'UrlTag' ).
    lo_sa->append( 'EmailTag' ).
    lo_sa->append( 'Markup' ).
    lo_sa->append( 'SpecialCharacter' ).
    lo_sa ?= inline_types->new( '>' ).
    lo_sa->append( 'SpecialCharacter' ).
    lo_sa ?= inline_types->new( '[' ).
    lo_sa->append( 'Link' ).
    lo_sa ?= inline_types->new( '_' ).
    lo_sa->append( 'Emphasis' ).
    lo_sa ?= inline_types->new( '`' ).
    lo_sa->append( 'Code' ).
    ">>> apm
    lo_sa ?= inline_types->new( '~' ).
    lo_sa->append( 'Strikethrough' ).
    lo_sa->append( 'Emphasis' ). "subscript
    lo_sa ?= inline_types->new( '^' ).
    lo_sa->append( 'Emphasis' ). "superscript
    lo_sa ?= inline_types->new( '=' ).
    lo_sa->append( 'Highlight' ).
    "<<< apm
    lo_sa ?= inline_types->new( '\' ).
    lo_sa->append( 'EscapeSequence' ).
    "#
    "# Read-Only
    "#
    CREATE OBJECT special_characters.

    lo_sa = special_characters.
    lo_sa->append( '\' ).
    lo_sa->append( '`' ).
    lo_sa->append( '*' ).
    lo_sa->append( '_' ).
    lo_sa->append( '{' ).
    lo_sa->append( '}' ).
    lo_sa->append( '[' ).
    lo_sa->append( ']' ).
    lo_sa->append( '(' ).
    lo_sa->append( ')' ).
    lo_sa->append( '>' ).
    lo_sa->append( '#' ).
    lo_sa->append( '+' ).
    lo_sa->append( '-' ).
    lo_sa->append( '.' ).
    lo_sa->append( '!' ).
    lo_sa->append( '|' ).

    CREATE OBJECT strong_regex.

    lo_string ?= strong_regex->new( '*' ).
    lo_string->data = '(^[*][*]((?:\\[*]|[^*]|[*][^*]*[*])+)[*][*](?![*]))'.
    lo_string ?= strong_regex->new( '_' ).
    lo_string->data = '(^__((?:\\_|[^_]|_[^_]*_)+)__(?!_))'.

    CREATE OBJECT em_regex.

    lo_string ?= em_regex->new( '*' ).
    lo_string->data = '(^[*]((?:\\[*]|[^*]|[*][*][^*]+[*][*])+)[*](?![*]))'.
    lo_string ?= em_regex->new( '_' ).
    lo_string->data = '(^_((?:\\_|[^_]|__[^_]*__)+)_(?!_)\b)'.
    lo_string ?= em_regex->new( '^' ).
    lo_string->data = '(^[\^]((?:\\[\^]|[^\^]|[\^][\^][^\^]+[\^][\^])+)[\^](?![\^]))'.
    lo_string ?= em_regex->new( '~' ).
    lo_string->data = '(^~((?:\\~|[^~]|~~[^~]*~~)+)~(?!~)\b)'.
    regex_html_attribute = '[a-zA-Z_:][\w:.-]*(?:\s*=\s*(?:[^"''=<>`\s]+|"[^"]*"|''[^'']*''))?'.

    CREATE OBJECT void_elements.

    lo_sa = void_elements.
    lo_sa->append( 'area' ).
    lo_sa->append( 'base' ).
    lo_sa->append( 'br' ).
    lo_sa->append( 'col' ).
    lo_sa->append( 'command' ).
    lo_sa->append( 'embed' ).
    lo_sa->append( 'hr' ).
    lo_sa->append( 'img' ).
    lo_sa->append( 'input' ).
    lo_sa->append( 'link' ).
    lo_sa->append( 'meta' ).
    lo_sa->append( 'param' ).
    lo_sa->append( 'source' ).

    CREATE OBJECT text_level_elements.

    lo_sa = text_level_elements.
    lo_sa->append( 'a' ).
    lo_sa->append( 'b' ).
    lo_sa->append( 'i' ).
    lo_sa->append( 'q' ).
    lo_sa->append( 's' ).
    lo_sa->append( 'u' ).
    lo_sa->append( 'br' ).
    lo_sa->append( 'em' ).
    lo_sa->append( 'rp' ).
    lo_sa->append( 'rt' ).
    lo_sa->append( 'tt' ).
    lo_sa->append( 'xm' ).
    lo_sa->append( 'bdo' ).
    lo_sa->append( 'big' ).
    lo_sa->append( 'del' ).
    lo_sa->append( 'ins' ).
    lo_sa->append( 'sub' ).
    lo_sa->append( 'sup' ).
    lo_sa->append( 'var' ).
    lo_sa->append( 'wbr' ).
    lo_sa->append( 'abbr' ).
    lo_sa->append( 'cite' ).
    lo_sa->append( 'code' ).
    lo_sa->append( 'font' ).
    lo_sa->append( 'mark' ).
    lo_sa->append( 'nobr' ).
    lo_sa->append( 'ruby' ).
    lo_sa->append( 'span' ).
    lo_sa->append( 'time' ).
    lo_sa->append( 'blink' ).
    lo_sa->append( 'small' ).
    lo_sa->append( 'nextid' ).
    lo_sa->append( 'spacer' ).
    lo_sa->append( 'strike' ).
    lo_sa->append( 'strong' ).
    lo_sa->append( 'acronym' ).
    lo_sa->append( 'listing' ).
    lo_sa->append( 'marquee' ).
    lo_sa->append( 'basefont' ).

    CREATE OBJECT safe_links_whitelist.

    lo_sa = safe_links_whitelist.
    lo_sa->append( 'http://' ).
    lo_sa->append( 'https://' ).
    lo_sa->append( 'sapevent:' ). " apm
    lo_sa->append( 'ftp://' ).
    lo_sa->append( 'ftps://' ).
    lo_sa->append( 'mailto:' ).
    lo_sa->append( 'data:image/png;base64,' ).
    lo_sa->append( 'data:image/gif;base64,' ).
    lo_sa->append( 'data:image/jpeg;base64,' ).
    lo_sa->append( 'irc:' ).
    lo_sa->append( 'ircs:' ).
    lo_sa->append( 'git:' ).
    lo_sa->append( 'ssh:' ).
    lo_sa->append( 'news:' ).
    lo_sa->append( 'steam:' ).

    "// Method names
    lo_objdescr ?= cl_abap_objectdescr=>describe_by_object_ref( me ).
    LOOP AT lo_objdescr->methods ASSIGNING <method>.
      APPEND <method>-name TO methods.
    ENDLOOP.
  ENDMETHOD.                    "constructor


  METHOD element.
    DATA:
      ls_element     TYPE ty_element,
      lv_method_name TYPE string,
      lv_content     TYPE string.

    FIELD-SYMBOLS:
      <text>       LIKE ls_element-text,
      <attribute>  LIKE LINE OF ls_element-attributes,
      <content>    LIKE <text>-text,
      <attributes> LIKE <text>-attributes.

    magic_move(
      EXPORTING
        from = element
      CHANGING
        to   = ls_element ).

    ">>> apm
    " Always sanitise
    " IF safe_mode IS NOT INITIAL
    ls_element = sanitise_element( ls_element ).
    " ENDIF
    "<<< apm

    ASSIGN COMPONENT 'TEXT' OF STRUCTURE ls_element TO <text>.
    ASSERT sy-subrc = 0.

    markup = |<{ ls_element-name }|.

    IF ls_element-attributes IS NOT INITIAL.
      LOOP AT ls_element-attributes ASSIGNING <attribute>.
        markup = |{ markup } { <attribute>-name }="{ _escape( <attribute>-value ) }"|.
      ENDLOOP.
    ENDIF.

    IF <text> IS NOT INITIAL OR ls_element-texts IS NOT INITIAL OR ls_element-lines IS NOT INITIAL.
      markup = |{ markup }>|.

      ">>> apm
      IF ls_element-handler = 'syntax_highlighter'.
        ASSIGN COMPONENT 'ATTRIBUTES' OF STRUCTURE <text> TO <attributes>.
        ASSERT sy-subrc = 0.
        <attributes> = ls_element-attributes.
      ENDIF.
      "<<< apm

      IF ls_element-handler IS NOT INITIAL.
        lv_method_name = ls_element-handler.
        TRANSLATE lv_method_name TO UPPER CASE.

        IF ls_element-texts IS NOT INITIAL. "// for array of elements
          CALL METHOD (lv_method_name)
            EXPORTING
              elements = ls_element-texts
            RECEIVING
              markup   = lv_content.
        ELSEIF ls_element-lines IS NOT INITIAL. "// for array of lines
          CALL METHOD (lv_method_name)
            EXPORTING
              lines  = ls_element-lines
            RECEIVING
              markup = lv_content.
        ELSE. "// for simple text
          CALL METHOD (lv_method_name)
            EXPORTING
              element = <text>
            RECEIVING
              markup  = lv_content.
        ENDIF.
      ELSE.
        IF ls_element-lines IS NOT INITIAL.
          CONCATENATE LINES OF ls_element-lines INTO lv_content SEPARATED BY %_newline.
        ELSE.
          ASSIGN COMPONENT 'TEXT' OF STRUCTURE <text> TO <content>.
          ASSERT sy-subrc = 0.
          lv_content = <content>.
          lv_content = _escape(
            text         = lv_content
            allow_quotes = abap_true ).
        ENDIF.

      ENDIF.
      markup = |{ markup }{ lv_content }</{ ls_element-name }>|.
    ELSE.
      markup = |{ markup } />|.
    ENDIF.
  ENDMETHOD.                    "element


  METHOD elements.
    DATA lt_markup TYPE TABLE OF string.

    FIELD-SYMBOLS:
      <element> TYPE any,
      <markup>  TYPE string.

    LOOP AT elements ASSIGNING <element>.
      APPEND INITIAL LINE TO lt_markup ASSIGNING <markup>.
      <markup> = element( <element> ).
    ENDLOOP.

    CONCATENATE LINES OF lt_markup INTO markup SEPARATED BY %_newline.
    CONCATENATE %_newline markup %_newline INTO markup.
  ENDMETHOD.                    "elements


  METHOD filter_unsafe_url_in_attribute.
    FIELD-SYMBOLS:
      <attribute> LIKE LINE OF r_element-attributes,
      <scheme>    LIKE LINE OF safe_links_whitelist->data.

    r_element = element.

    READ TABLE r_element-attributes WITH KEY name = attribute ASSIGNING <attribute>.
    CHECK sy-subrc = 0.

    ">>> apm
    IF attribute = 'href'.
      <attribute>-value = _adjust_a_href( <attribute>-value ).
    ELSEIF attribute = 'src'.
      <attribute>-value = _adjust_img_src( <attribute>-value ).
    ENDIF.
    "<<< apm

    " Check for allowed protocols
    LOOP AT safe_links_whitelist->data ASSIGNING <scheme>.
      IF string_at_start(
        haystack = <attribute>-value
        needle   = <scheme> ) = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

    " Effectively disable URL
    REPLACE FIRST OCCURRENCE OF ':' IN <attribute>-value WITH '%3A'.

  ENDMETHOD.


  METHOD htmlspecialchars.
    output = input.
    REPLACE ALL OCCURRENCES OF '&' IN output WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN output WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN output WITH '&gt;'.

    IF ent_noquotes IS INITIAL.
      REPLACE ALL OCCURRENCES OF '"' IN output WITH '&quot;'.
      IF ent_quotes IS NOT INITIAL.
        IF ent_html401 IS NOT INITIAL.
          REPLACE ALL OCCURRENCES OF '''' IN output WITH '&#039;'.
        ELSE.
          REPLACE ALL OCCURRENCES OF '''' IN output WITH '&apos;'.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "htmlspecialchars


  METHOD inline_code.
    DATA:
      lv_marker      TYPE c,
      lv_marker_comb TYPE string,
      lv_m0          TYPE string,
      lv_m1          TYPE string,
      lv_text        TYPE string.

    lv_marker = excerpt-text(1).

    "// Deal with the different repetitions (from 5 markers to 1)
    lv_marker_comb = '&&&&&'.
    REPLACE ALL OCCURRENCES OF '&' IN lv_marker_comb WITH lv_marker.
    WHILE lv_marker_comb IS NOT INITIAL.
      match_marked_string(
        EXPORTING
          marker    = lv_marker_comb
          subject   = excerpt-text
        IMPORTING
          m0        = lv_m0
          m1        = lv_m1
        EXCEPTIONS
          not_found = 4 ).
      IF sy-subrc = 0.
        lv_text = lv_m1.
        CONDENSE lv_text.
        lv_text = lv_text.
        REPLACE ALL OCCURRENCES OF REGEX '[ ]*\n' IN lv_text WITH ' '.

        r_inline-extent = strlen( lv_m0 ).
        r_inline-element-name = 'code'.
        r_inline-element-text-text = lv_text.
        EXIT.
      ENDIF.
      SHIFT lv_marker_comb LEFT.
    ENDWHILE.
  ENDMETHOD.                    "inline_code


  METHOD inline_emailtag.
    DATA:
      lv_hostname_label    TYPE string,
      lv_common_mark_email TYPE string,
      lv_regex             TYPE string,
      lv_m0                TYPE string,
      lv_m1                TYPE string,
      lv_m2                TYPE string,
      lv_url               TYPE string.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_inline-element-attributes.

    CHECK excerpt-text CS '>'.

    lv_hostname_label = '[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'.
    lv_common_mark_email = '[a-zA-Z0-9.!#$%&\''*+\/=?^_`{|}~-]+@'
      && lv_hostname_label && '(?:\.' && lv_hostname_label && ')*'.
    lv_regex = '(^<((mailto:)?' && lv_common_mark_email && ')>)'.

    FIND REGEX lv_regex IN excerpt-text IGNORING CASE
      SUBMATCHES lv_m0 lv_m1 lv_m2.
    IF sy-subrc = 0.
      lv_url = lv_m1.
      IF lv_m2 IS INITIAL.
        CONCATENATE 'mailto:' lv_url INTO lv_url.
      ENDIF.

      r_inline-extent = strlen( lv_m0 ).
      r_inline-element-name = 'a'.
      r_inline-element-text-text = lv_m1.

      APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'href'.
      <attribute>-value = lv_url.
    ENDIF.
  ENDMETHOD.                    "inline_EmailTag


  METHOD inline_emphasis.
    DATA:
      lv_marker      TYPE c,
      lv_emphasis    TYPE string,
      lv_m0          TYPE string,
      lv_m1          TYPE string,
      lo_regex       TYPE REF TO lcl_string,
      lv_regex_delim TYPE string,
      lv_offset      TYPE i.

    CHECK excerpt-text IS NOT INITIAL.

    lv_marker = excerpt-text(1).

    lo_regex ?= strong_regex->get( lv_marker ).
    IF strlen( excerpt-text ) > 1 AND excerpt-text+1(1) = lv_marker AND
       lo_regex->data IS NOT INITIAL.
      FIND REGEX lo_regex->data IN excerpt-text SUBMATCHES lv_m0 lv_m1.
      IF sy-subrc = 0.
        lv_emphasis = 'strong'.

        "// get the (ungreedy) end marker
        lv_regex_delim = '[^&][&]{2}(?![&])'.
        REPLACE ALL OCCURRENCES OF '&' IN lv_regex_delim WITH lv_marker.
        FIND REGEX lv_regex_delim IN lv_m1 MATCH OFFSET lv_offset.
        IF sy-subrc = 0.
          lv_offset = lv_offset + 1.
          lv_m1 = lv_m1(lv_offset).
          lv_offset = strlen( lv_m1 ) + 4.
          lv_m0 = lv_m0(lv_offset).
        ENDIF.
      ENDIF.
    ENDIF.

    lo_regex ?= em_regex->get( lv_marker ).
    IF lv_emphasis IS INITIAL AND lo_regex->data IS NOT INITIAL.
      FIND REGEX lo_regex->data IN excerpt-text SUBMATCHES lv_m0 lv_m1.
      IF sy-subrc = 0.
        ">>> apm
        CASE lv_marker.
          WHEN '~'.
            IF lv_m0+1(1) = ` `.
              CLEAR lv_emphasis.
            ELSE.
              lv_emphasis = 'sub'.
            ENDIF.
          WHEN '^'.
            IF lv_m0+1(1) = ` `.
              CLEAR lv_emphasis.
            ELSE.
              lv_emphasis = 'sup'.
            ENDIF.
          WHEN OTHERS.
            lv_emphasis = 'em'.
        ENDCASE.
        "<<< apm
      ENDIF.
    ENDIF.

    CHECK lv_emphasis IS NOT INITIAL.

    r_inline-extent = strlen( lv_m0 ).
    r_inline-element-name = lv_emphasis.
    r_inline-element-handler = 'line'.
    r_inline-element-text-text = lv_m1.
  ENDMETHOD.                    "inline_Emphasis


  METHOD inline_escapesequence.
    DATA lv_ch TYPE c.

    CHECK strlen( excerpt-text ) > 1.
    lv_ch = excerpt-text+1(1).
    IF special_characters->find_val( lv_ch ) > 0.
      r_inline-markup = excerpt-text+1(1).
      r_inline-extent = 2.
    ENDIF.
  ENDMETHOD.                    "inline_EscapeSequence


  METHOD inline_highlight.
    DATA:
      lv_m0 TYPE string,
      lv_m1 TYPE string.

    CHECK strlen( excerpt-text ) > 1 AND
          excerpt-text+1(1) = '='.

    FIND REGEX '(^==(?=\S)([^(?:==)]+)(?=\S)==)' IN excerpt-text
      SUBMATCHES lv_m0 lv_m1.
    IF sy-subrc = 0.
      r_inline-extent = strlen( lv_m0 ).
      r_inline-element-name = 'mark'.
      r_inline-element-text-text = lv_m1.
      r_inline-element-handler = 'line'.
    ENDIF.
  ENDMETHOD.


  METHOD inline_image.
    DATA ls_link LIKE r_inline.

    FIELD-SYMBOLS:
      <attribute>      LIKE LINE OF r_inline-element-attributes,
      <attribute_from> LIKE LINE OF ls_link-element-attributes.

    CHECK strlen( excerpt-text ) > 1 AND
          excerpt-text+1(1) = '['.
    excerpt-text = excerpt-text+1.

    ls_link = inline_link( excerpt ).
    CHECK ls_link IS NOT INITIAL.

    r_inline-extent = ls_link-extent + 1.
    r_inline-element-name = 'img'.

    APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
    <attribute>-name = 'src'.
    READ TABLE ls_link-element-attributes ASSIGNING <attribute_from>
      WITH KEY name = 'href'.
    IF sy-subrc = 0.
      <attribute>-value = _adjust_img_src( <attribute_from>-value ). " apm
      DELETE ls_link-element-attributes WHERE name = 'href'.
    ENDIF.

    APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
    <attribute>-name = 'alt'.
    <attribute>-value = ls_link-element-text-text.

    APPEND LINES OF ls_link-element-attributes TO r_inline-element-attributes.
  ENDMETHOD.                    "inline_Image


  METHOD inline_link.
    CONSTANTS lc_regex_template TYPE string VALUE '\[((?:[^\]\[]|(?R))*)\]'.

    DATA:
      lv_len        TYPE i,
      lv_regex      TYPE string,
      lv_remainder  TYPE string,
      lv_m0         TYPE string,
      lv_m1         TYPE string,
      lv_m2         TYPE string,
      lv_definition TYPE string,
      lo_ref_map    TYPE REF TO lcl_hashmap,
      lo_def_map    TYPE REF TO lcl_hashmap,
      lo_def_val    TYPE REF TO lcl_string,
      lv_exists     TYPE abap_bool.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_inline-element-attributes.

    r_inline-element-name = 'a'.
    r_inline-element-handler = 'line'.

    lv_remainder = excerpt-text.

    lv_regex = |({ lc_regex_template })|.
    DO 5 TIMES. "// regex recursion
      REPLACE '(?R)' IN lv_regex WITH lc_regex_template.
    ENDDO.
    REPLACE '(?R)' IN lv_regex WITH '$'.

    FIND REGEX lv_regex IN lv_remainder SUBMATCHES lv_m0 lv_m1.
    IF sy-subrc = 0.
      r_inline-element-text-text = lv_m1.
      r_inline-extent = strlen( lv_m0 ).
      lv_remainder = lv_remainder+r_inline-extent.
    ELSE.
      CLEAR r_inline.
      RETURN.
    ENDIF.

*^[(]\s*((?:[^ ()]+|[(][^ )]+[)])+)(?:[ ]+("[^"]*"|''[^'']*''))?\s*[)]
*^[(]\s*((?:[^ ()]|[(][^ )]+[)])+)(?:[ ]+("[^"]*"|''[^'']*''))?\s*[)]
*^[(]((?:[^ ()]|[(][^ )]+[)])+)(?:[ ]+("[^"]*"|''[^'']*''))?[)]

    "FIND REGEX '(^[(]\s*((?:[^ ()]|[(][^ )]+[)])+)(?:[ ]+("[^"]*"|''[^\'']*''))?\s*[)])'
    FIND REGEX '(^[(]\s*((?:[^ ()]|[(][^ )]+[)])+)(?:[ ]+("[^"]*"|''[^\'']*''|\([^\)]*\)))?\s*[)])' " apm
      IN lv_remainder SUBMATCHES lv_m0 lv_m1 lv_m2.
    IF sy-subrc = 0.
      APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'href'.
      <attribute>-value = lv_m1.
      IF lv_m2 IS NOT INITIAL.
        APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
        <attribute>-name = 'title'.
        lv_len = strlen( lv_m2 ) - 2.
        <attribute>-value = lv_m2+1(lv_len).
      ENDIF.

      lv_len = strlen( lv_m0 ).
      r_inline-extent = r_inline-extent + lv_len.

    ELSE.
      FIND REGEX '(^\s*\[([^\]]*)\])' IN lv_remainder SUBMATCHES lv_m0 lv_m1.
      IF sy-subrc = 0.
        IF lv_m1 IS NOT INITIAL.
          lv_definition = lv_m1.
        ELSE.
          lv_definition = r_inline-element-text-text.
        ENDIF.
        lv_len = strlen( lv_m0 ).
        r_inline-extent = r_inline-extent + lv_len.
      ELSE.
        lv_definition = r_inline-element-text-text.
      ENDIF.

      TRANSLATE lv_definition TO LOWER CASE.
      lo_ref_map ?= definition_data->get( 'Reference' ).
      lv_exists = lo_ref_map->exists( lv_definition ).
      IF lv_exists IS INITIAL.
        CLEAR r_inline.
        RETURN.
      ENDIF.

      lo_def_map ?= lo_ref_map->get( lv_definition ).

      lo_def_val ?= lo_def_map->get( 'url' ).
      APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'href'.
      <attribute>-value = _adjust_a_href( lo_def_val->data ). " apm

      lv_exists = lo_def_map->exists( 'title' ).
      IF lv_exists IS NOT INITIAL.
        lo_def_val ?= lo_def_map->get( 'title' ).
        APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
        <attribute>-name = 'title'.
        <attribute>-value = lo_def_val->data.
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "inline_Link


  METHOD inline_markup.
    DATA:
      lv_m0    TYPE string,
      lv_regex TYPE string.

    CHECK markup_escaped IS INITIAL AND
          safe_mode IS INITIAL AND
          excerpt-text CS '>' AND
          strlen( excerpt-text ) > 1.

    FIND REGEX '(^<\/\w*[ ]*>)' IN excerpt-text SUBMATCHES lv_m0.
    IF sy-subrc <> 0.
      FIND REGEX '(^<!---?[^>-](?:-?[^-])*-->)' IN excerpt-text SUBMATCHES lv_m0.
      IF sy-subrc <> 0.
        lv_regex
         = '(^<\w*(?:[ ]*' && regex_html_attribute && ')*[ ]*\/?>)'.
        FIND REGEX lv_regex IN excerpt-text SUBMATCHES lv_m0.
      ENDIF.
    ENDIF.

    IF lv_m0 IS NOT INITIAL.
      r_inline-extent = strlen( lv_m0 ).
      r_inline-markup = _adjust_markup( lv_m0 ). " apm
    ENDIF.
  ENDMETHOD.                    "inline_Markup


  METHOD inline_specialcharacter.
    DATA lv_special TYPE string.

    CHECK excerpt-text IS NOT INITIAL.

    IF excerpt-text(1) = '&'.
      FIND REGEX '^&#?\w+;' IN excerpt-text.
      IF sy-subrc <> 0.
        r_inline-markup = '&amp;'.
        r_inline-extent = 1.
        RETURN.
      ENDIF.
    ENDIF.

    CASE excerpt-text(1).
      WHEN '>'.
        lv_special = 'gt'.
      WHEN '<'.
        lv_special = 'lt'.
      WHEN '"'.
        lv_special = 'quot'.
    ENDCASE.
    IF lv_special IS NOT INITIAL.
      CONCATENATE '&' lv_special ';' INTO r_inline-markup.
      r_inline-extent = 1.
    ENDIF.
  ENDMETHOD.                    "inline_SpecialCharacter


  METHOD inline_strikethrough.
    DATA:
      lv_m0 TYPE string,
      lv_m1 TYPE string.

    CHECK strlen( excerpt-text ) > 1 AND
          excerpt-text+1(1) = '~'.

    FIND REGEX '(^~~(?=\S)([^(?:~~)]+)(?=\S)~~)' IN excerpt-text
      SUBMATCHES lv_m0 lv_m1.
    IF sy-subrc = 0.
      r_inline-extent = strlen( lv_m0 ).
      r_inline-element-name = 'del'.
      r_inline-element-text-text = lv_m1.
      r_inline-element-handler = 'line'.
    ENDIF.
  ENDMETHOD.                    "inline_Strikethrough


  METHOD inline_url.
    DATA:
      lv_m0     TYPE string,
      lv_offset TYPE i.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_inline-element-attributes.

    CHECK urls_linked IS NOT INITIAL AND
          strlen( excerpt-text ) > 2 AND
          excerpt-text+2(1) = '/'.

    FIND REGEX '(\bhttps?:[\/]{2}[^\s<]+\b\/*)' IN excerpt-context
      IGNORING CASE SUBMATCHES lv_m0 MATCH OFFSET lv_offset.
    IF sy-subrc = 0.
      r_inline-extent = strlen( lv_m0 ).
      r_inline-position = lv_offset + 1. "// set to +1 so 0 is not initial
      r_inline-element-name = 'a'.
      r_inline-element-text-text = lv_m0.

      APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'href'.
      <attribute>-value = lv_m0.
    ENDIF.
  ENDMETHOD.                    "inline_Url


  METHOD inline_urltag.
    DATA:
      lv_m0  TYPE string,
      lv_m1  TYPE string,
      lv_url TYPE string.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_inline-element-attributes.

    CHECK excerpt-text CS '>'.

    FIND REGEX '(^<(\w+:\/{2}[^ >]+)>)' IN excerpt-text SUBMATCHES lv_m0 lv_m1.
    IF sy-subrc = 0.
      lv_url = lv_m1.
      r_inline-extent = strlen( lv_m0 ).
      r_inline-element-name = 'a'.
      r_inline-element-text-text = lv_url.

      APPEND INITIAL LINE TO r_inline-element-attributes ASSIGNING <attribute>.
      <attribute>-name = 'href'.
      <attribute>-value = lv_url.
    ENDIF.
  ENDMETHOD.                    "inline_UrlTag


  METHOD li.
    DATA:
      lv_trimmed_markup TYPE string,
      lv_fdpos          TYPE i,
      lv_pos_to         TYPE i.

    markup = _lines( lines ).
    lv_trimmed_markup = trim( markup ).

    READ TABLE lines TRANSPORTING NO FIELDS WITH KEY table_line = ''.
    IF sy-subrc <> 0 AND strlen( lv_trimmed_markup ) >= 3 AND lv_trimmed_markup(3) = '<p>'.
      markup = lv_trimmed_markup+3.
      FIND '</p>' IN markup MATCH OFFSET lv_fdpos.
      lv_pos_to = lv_fdpos + 4.
      CONCATENATE markup(lv_fdpos) markup+lv_pos_to INTO markup.
    ENDIF.

    ">>> apm
    " Task lists
    IF markup CP '[ ]*'.
      markup = |<input type="checkbox" disabled="disabled">{ markup+3 }|.
    ELSEIF markup CP '[X]*'.
      markup = |<input type="checkbox" disabled="disabled" checked="checked">{ markup+3 }|.
    ENDIF.
    "<<< apm
  ENDMETHOD.                    "li


  METHOD line.
    DATA:
      lv_text            TYPE string,
      lv_unmarked_text   TYPE string,
      lv_marker_position TYPE i,
      lv_pos             TYPE i,
      ls_excerpt         TYPE ty_excerpt,
      ls_inline          TYPE ty_inline,
      lv_marker          TYPE c,
      lo_inline_types_sa TYPE REF TO lcl_string_array,
      lv_method_name     TYPE string,
      lv_markup_part     TYPE string,
      lv_continue_loop   TYPE abap_bool.

    FIELD-SYMBOLS <inline_type> LIKE LINE OF lo_inline_types_sa->data.

    "# lv_text contains the unexamined text
    "# ls_excerpt-text is based on the first occurrence of a marker
    lv_text = element-text.

    WHILE lv_text IS NOT INITIAL.
      IF lv_text NA inline_marker_list.
        EXIT.
      ENDIF.
      ls_excerpt-text = lv_text+sy-fdpos.
      lv_marker = ls_excerpt-text(1).

      FIND lv_marker IN lv_text MATCH OFFSET lv_marker_position.

      ls_excerpt-context = lv_text.

      lo_inline_types_sa ?= inline_types->get( lv_marker ).
      CLEAR lv_continue_loop.
      LOOP AT lo_inline_types_sa->data ASSIGNING <inline_type>.
        CONCATENATE 'inline_' <inline_type> INTO lv_method_name.
        TRANSLATE lv_method_name TO UPPER CASE.
        CALL METHOD (lv_method_name)
          EXPORTING
            excerpt  = ls_excerpt
          RECEIVING
            r_inline = ls_inline.

        "# makes sure that the inline belongs to "our" marker
        CHECK ls_inline IS NOT INITIAL.
        CHECK ls_inline-position <= lv_marker_position.

        "# sets a default inline position
        IF ls_inline-position IS INITIAL.
          ls_inline-position = lv_marker_position.
        ELSE.
          ls_inline-position = ls_inline-position - 1.
        ENDIF.

        "# the text that comes before the inline
        IF ls_inline-position <= strlen( lv_text ).
          lv_unmarked_text = lv_text(ls_inline-position).
        ELSE.
          lv_unmarked_text = lv_text.
        ENDIF.

        "# compile the unmarked text
        lv_markup_part = unmarked_text( lv_unmarked_text ).
        CONCATENATE markup lv_markup_part INTO markup.

        "# compile the inline
        IF ls_inline-markup IS NOT INITIAL.
          CONCATENATE markup ls_inline-markup INTO markup.
        ELSE.
          lv_markup_part = element( ls_inline-element ).
          CONCATENATE markup lv_markup_part INTO markup.
        ENDIF.

        "# remove the examined text
        lv_pos = ls_inline-position + ls_inline-extent.
        IF lv_pos <= strlen( lv_text ).
          lv_text = lv_text+lv_pos.
        ELSE.
          CLEAR lv_text.
        ENDIF.

        lv_continue_loop = abap_true.
        EXIT.
      ENDLOOP. "inline_types->data
      CHECK lv_continue_loop IS INITIAL.

      "# the marker does not belong to an inline
      lv_marker_position = lv_marker_position + 1.
      IF lv_marker_position <= strlen( lv_text ).
        lv_unmarked_text = lv_text(lv_marker_position).
      ELSE.
        lv_unmarked_text = lv_text.
      ENDIF.
      lv_markup_part = unmarked_text( lv_unmarked_text ).
      CONCATENATE markup lv_markup_part INTO markup.
      IF lv_marker_position <= strlen( lv_text ).
        lv_text = lv_text+lv_marker_position.
      ELSE.
        CLEAR lv_text.
      ENDIF.
    ENDWHILE.

    lv_markup_part = unmarked_text( lv_text ).
    CONCATENATE markup lv_markup_part INTO markup.
  ENDMETHOD.                    "line


  METHOD magic_move.
    "!
    " Magic move-corresponding
    " Recursively handles any kind of structures
    "!
    DATA:
      lo_td_from TYPE REF TO cl_abap_typedescr,
      lo_td_to   TYPE REF TO cl_abap_typedescr,
      lo_sd_from TYPE REF TO cl_abap_structdescr,
      lo_sd_to   TYPE REF TO cl_abap_structdescr.

    FIELD-SYMBOLS:
      <tab_from>  TYPE table,
      <tab_to>    TYPE table,
      <any_from>  TYPE any,
      <any_to>    TYPE any,
      <comp_from> LIKE LINE OF lo_sd_from->components,
      <comp_to>   LIKE LINE OF lo_sd_to->components.

    lo_td_from = cl_abap_typedescr=>describe_by_data( from ).
    lo_td_to   = cl_abap_typedescr=>describe_by_data( to ).
    IF lo_td_from->absolute_name = lo_td_to->absolute_name.
      to = from.
      RETURN.
    ENDIF.

    "// Scenario 1 => simple to simple
    IF lo_td_from->kind = lo_td_to->kind AND
       lo_td_from->kind = cl_abap_typedescr=>kind_elem.
      to = from.

      "// Scenario 2 => struct to struct
    ELSEIF lo_td_from->kind = lo_td_to->kind AND
           lo_td_from->kind = cl_abap_typedescr=>kind_struct.
      lo_sd_from ?= lo_td_from.
      lo_sd_to ?= lo_td_to.
      LOOP AT lo_sd_from->components ASSIGNING <comp_from>.
        READ TABLE lo_sd_to->components ASSIGNING <comp_to>
          WITH KEY name = <comp_from>-name.
        CHECK sy-subrc = 0.
        IF <comp_to>-type_kind = cl_abap_typedescr=>typekind_table.
          ASSIGN COMPONENT <comp_to>-name OF STRUCTURE from TO <tab_from>.
          ASSERT sy-subrc = 0.
          ASSIGN COMPONENT <comp_to>-name OF STRUCTURE to TO <tab_to>.
          ASSERT sy-subrc = 0.
          LOOP AT <tab_from> ASSIGNING <any_from>.
            APPEND INITIAL LINE TO <tab_to> ASSIGNING <any_to>.

            magic_move(
              EXPORTING
                from = <any_from>
                name = <comp_to>-name
              CHANGING
                to   = <any_to> ).
          ENDLOOP.
        ELSE.
          ASSIGN COMPONENT <comp_to>-name OF STRUCTURE from TO <any_from>.
          ASSERT sy-subrc = 0.
          ASSIGN COMPONENT <comp_to>-name OF STRUCTURE to TO <any_to>.
          ASSERT sy-subrc = 0.

          magic_move(
            EXPORTING
              from = <any_from>
              name = <comp_to>-name
            CHANGING
              to   = <any_to> ).
        ENDIF.
      ENDLOOP.

      "// Scenario 3 => simple to struct
    ELSEIF lo_td_from->kind = cl_abap_typedescr=>kind_elem AND
           lo_td_to->kind = cl_abap_typedescr=>kind_struct AND
           name IS NOT INITIAL.
      lo_sd_to ?= lo_td_to.
      READ TABLE lo_sd_to->components ASSIGNING <comp_to>
        WITH KEY name = name.
      IF sy-subrc = 0 AND
         <comp_to>-type_kind <> cl_abap_typedescr=>typekind_table.
        ASSIGN COMPONENT <comp_to>-name OF STRUCTURE to TO <any_to>.
        ASSERT sy-subrc = 0.

        magic_move(
          EXPORTING
            from = from
            name = <comp_to>-name
          CHANGING
            to   = <any_to> ).
      ENDIF.

      "// Scenario 4 => struct to simple
    ELSEIF lo_td_from->kind = cl_abap_typedescr=>kind_struct AND
           lo_td_to->kind = cl_abap_typedescr=>kind_elem AND
           name IS NOT INITIAL.
      lo_sd_from ?= lo_td_from.
      READ TABLE lo_sd_from->components ASSIGNING <comp_from>
        WITH KEY name = name.
      IF sy-subrc = 0 AND
         <comp_from>-type_kind <> cl_abap_typedescr=>typekind_table.
        ASSIGN COMPONENT <comp_from>-name OF STRUCTURE to TO <any_from>.
        ASSERT sy-subrc = 0.

        magic_move(
          EXPORTING
            from = <any_from>
            name = <comp_from>-name
          CHANGING
            to   = to ).
      ENDIF.
    ENDIF.
  ENDMETHOD.                    "magic_move


  METHOD match_marked_string.
    "!
    " Workaround for an ungreedy regex match
    " Specific for regex matches with a delimiting marker
    "!
    CONSTANTS:
      lc_regex       TYPE string VALUE '(^{&X}[ ]*(.+)[ ]*{&X}(?!{&1}))',
      lc_regex_delim TYPE string VALUE '[^{&1}]{&X}(?!{&1})'.

    DATA:
      lv_marker_ptn    TYPE string,
      lv_submarker_ptn TYPE string,
      lv_regex         TYPE string,
      lv_regex_delim   TYPE string,
      lv_offset        TYPE i.

    lv_marker_ptn = marker.
    REPLACE ALL OCCURRENCES OF REGEX '([*?!+])' IN lv_marker_ptn WITH '[$1]'.
    lv_submarker_ptn = marker(1).
    REPLACE ALL OCCURRENCES OF REGEX '([*?!+])' IN lv_submarker_ptn WITH '[$1]'.

    lv_regex = lc_regex.
    REPLACE ALL OCCURRENCES OF '{&1}' IN lv_regex WITH lv_submarker_ptn.
    REPLACE ALL OCCURRENCES OF '{&X}' IN lv_regex WITH lv_marker_ptn.

    lv_regex_delim = lc_regex_delim.
    REPLACE ALL OCCURRENCES OF '{&1}' IN lv_regex_delim WITH lv_submarker_ptn.
    REPLACE ALL OCCURRENCES OF '{&X}' IN lv_regex_delim WITH lv_marker_ptn.

    FIND REGEX lv_regex IN subject SUBMATCHES m0 m1.
    IF sy-subrc = 0.
      FIND REGEX lv_regex_delim IN m1 MATCH OFFSET lv_offset.
      IF sy-subrc = 0.
        lv_offset = lv_offset + 1.
        m1 = m1(lv_offset).
        lv_offset = strlen( m1 ) + ( strlen( marker ) * 2 ).
        m0 = m0(lv_offset).
      ENDIF.
    ELSE.
      RAISE not_found.
    ENDIF.
  ENDMETHOD.


  METHOD paragraph.
    r_block-element-name = 'p'.
    r_block-element-text-text = line-text.
    r_block-element-handler = 'line'.
  ENDMETHOD.                    "paragraph


  METHOD sanitise_element.
    CONSTANTS lc_good_attribute TYPE string VALUE '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'.

    FIELD-SYMBOLS <attribute> LIKE LINE OF r_element-attributes.

    r_element = element.

    CASE r_element-name.
      WHEN 'a'.
        r_element = filter_unsafe_url_in_attribute(
          element   = r_element
          attribute = 'href' ).
      WHEN 'img'.
        r_element = filter_unsafe_url_in_attribute(
          element   = r_element
          attribute = 'src' ).
    ENDCASE.

    LOOP AT r_element-attributes ASSIGNING <attribute>.
      "# filter out badly parsed attribute
      FIND REGEX lc_good_attribute IN <attribute>-name.
      IF sy-subrc <> 0.
        DELETE TABLE r_element-attributes FROM <attribute>.
        CONTINUE.
      ENDIF.
      "# dump onevent attribute
      IF string_at_start(
        haystack = <attribute>-name
        needle   = 'on' ) = abap_true.
        DELETE TABLE r_element-attributes FROM <attribute>.
        CONTINUE.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_breaks_enabled.
    breaks_enabled = breaks_enabled.
    this = me.
  ENDMETHOD.                    "set_breaks_enabled


  METHOD set_markup_escaped.
    markup_escaped = markup_escaped.
    this = me.
  ENDMETHOD.                    "set_markup_escaped


  METHOD set_safe_mode.
    safe_mode = iv_safe_mode.
    this = me.
  ENDMETHOD.


  METHOD set_urls_linked.
    urls_linked = urls_linked.
    this = me.
  ENDMETHOD.                    "set_urls_linked


  METHOD string_at_start.
    DATA lv_len TYPE i.

    lv_len = strlen( needle ).

    IF lv_len > strlen( haystack ).
      result = abap_false.
    ELSE.
      result = boolc( to_lower( haystack+0(lv_len) ) = needle ).
    ENDIF.
  ENDMETHOD.


  METHOD styles.

    result = |.markdown\n|
      && |\{ background-color: #f2f2f2; padding: 15px; \}\n|
      && |.markdown .logo\n|
      && |\{ width: 36px; height: 22px; margin-top: -4px; \}\n|
      && |.markdown .header,\n|
      && |.markdown .content\n|
      && |\{ background-color: #ffffff; border: 1px solid #d8dee4; display: block; \}\n|
      && |.markdown .header\n|
      && |\{ font-size: larger; margin-bottom: 15px; padding: 15px; \}\n|
      && |.markdown .content\n|
      && |\{ padding: 25px; \}\n|
      && |.markdown .html\n|
      && |\{ max-width: 1024px; margin: 0 auto; padding: 25px; \}\n|
      " Markdown View
      && |.markdown .source\n|
      && |\{ font-family: Consolas,Courier,monospace; font-size: 12pt; padding: 25px;\n|
      && |  max-width: 1024px; margin: 0 auto; \}\n|
      && |.markdown .source table\n|
      && |\{ border: 1px solid #d8dee4; \}\n|
      && |.markdown .source td\n|
      && |\{ border-top: 0px; border-bottom: 0px; padding-top: 0; padding-bottom: 0;\n|
      && |  line-height: 20px; vertical-align: top; \}\n|
      " Syntax Highlight
      && |.markdown .syntax-hl .heading\n|
      && |\{ color: blue; \}\n|
      && |.markdown .syntax-hl .link\n|
      && |\{ color: purple; \}\n|
      && |.markdown .syntax-hl .url\n|
      && |\{ color: green; \}\n|
      && |.markdown .syntax-hl .html\n|
      && |\{ padding: 0; \}\n|
      && |.markdown .syntax-hl .bold\n|
      && |\{ font-weight: bold; \}\n|
      " HTML Tags
      && |.markdown h1,\n|
      && |.markdown h2\n|
      && |\{ border-bottom: 1px solid #d8dee4; box-sizing: border-box; \}\n|
      && |.markdown img\n|
      && |\{ border: 0; box-sizing: border-box; max-width: 100%; vertical-align: middle; \}\n|
      && |.markdown table\n|
      && |\{ border: 1px solid #ddd; border-radius: 3px; \}\n|
      && |.markdown th,\n|
      && |\{ color: #4078c0; background-color: #edf2f9; border-bottom-color: #ddd; \}\n|
      && |.markdown th,\n|
      && |.markdown td\n|
      && |\{ border: 1px solid #ddd; padding: 6px 13px; \}\n|
      && |.markdown tr:first-child td\n|
      && |\{ border-top: 0; \}\n|
      && |.markdown hr\n|
      && |\{ background-color: #eee; margin: 24px 0; overflow: hidden; padding: 0; \}\n|
      && |.markdown mark\n|
      && |\{ background-color: #fff8e0; border-radius: 6px; margin: 0; padding: .2em .4em; \}\n|
      && |.markdown blockquote\n|
      && |\{ background-color: #eee; border-left: 3px solid #303d36; border-radius: 6px;\n|
      && |  margin: 0 0 16px; padding: 1px 1em; \}\n|
      " GitHub Alerts
      && |.markdown blockquote.alert-note\n|
      && |\{ border-left: 3px solid #4493f8; \}\n|
      && |.markdown blockquote.alert-tip\n|
      && |\{ border-left: 3px solid #3fb950; \}\n|
      && |.markdown blockquote.alert-important\n|
      && |\{ border-left: 3px solid #ab7df8; \}\n|
      && |.markdown blockquote.alert-warning\n|
      && |\{ border-left: 3px solid #d29922; \}\n|
      && |.markdown blockquote.alert-caution\n|
      && |\{ border-left: 3px solid #f85149; \}\n|
      " Code blocks
      && |.markdown pre\n|
      && |\{ background-color: #eee; border-radius: 6px; display: block;\n|
      && |  margin-bottom: 16px; margin-top: 0; overflow: auto; overflow-wrap: normal;\n|
      && |  padding: 16px; word-break: normal; box-sizing: border-box;\n|
      && |  font-family: Consolas, Courier, monospace; font-size: 14px; \}\n|
      && |.markdown p code\n|
      && |\{ background-color: #eee; border-radius: 6px; margin: 0; padding: .2em .4em;\n|
      && |  font-family: Consolas, Courier, monospace; font-size: 14px; \}\n|
      && |.markdown pre code\n|
      && |\{ background-color: transparent; border-style: initial;\n|
      && |  border-width: 0; box-sizing: border-box; display: inline; margin: 0;\n|
      && |  overflow: visible; word-break: normal; overflow-wrap: normal;\n|
      && |  padding: 0; white-space: pre;\n|
      && |  font-family: Consolas, Courier, monospace; font-size: 14px; \}\n|
      && |kbd \{\n|
      && |  border: 1px solid rgba(61, 68, 77, .7);\n|
      && |  border-radius: 6px;\n|
      && |  box-shadow: inset 0 -1px 0 var(--borderColor-neutral-muted, var(--color-neutral-muted));\n|
      && |  display: inline-block;\n|
      && |  font-family: Consolas, Courier, monospace;\n|
      && |  font-kerning: auto;\n|
      && |  font-optical-sizing: auto;\n|
      && |  font-size: 11px;\n|
      && |  font-size-adjust: none;\n|
      && |  font-variant: normal;\n|
      && |  font-variant-emoji: normal;\n|
      && |  font-weight: 400;\n|
      && |  line-height: 10px;\n|
      && |  padding: 4px;\n|
      && |  vertical-align: middle;\}\n|.

  ENDMETHOD.


  METHOD syntax_highlighter.
    ">>> apm
    DATA:
      lv_language TYPE string,
      ls_element  TYPE ty_element.

    FIELD-SYMBOLS:
      <attribute> LIKE LINE OF ls_element-attributes.

    magic_move(
      EXPORTING
        from = element
      CHANGING
        to   = ls_element ).

    READ TABLE ls_element-attributes ASSIGNING <attribute> WITH TABLE KEY name = 'class'.
    IF sy-subrc = 0 AND <attribute>-value CP 'language-*'.
      lv_language = <attribute>-value+9(*).

      markup = zcl_markdown_syn=>process(
        iv_source   = ls_element-text-text
        iv_language = lv_language ).
    ELSE.
      IF ls_element-lines IS NOT INITIAL.
        CONCATENATE LINES OF ls_element-lines INTO markup SEPARATED BY %_newline.
      ELSE.
        markup = ls_element-text-text.
        markup = _escape(
          text         = markup
          allow_quotes = abap_true ).
      ENDIF.
    ENDIF.
    "<<< apm
  ENDMETHOD.


  METHOD text.
    " Parses the markdown text and returns the markup

    DATA lt_lines TYPE TABLE OF string.

    "# make sure no definitions are set
    CREATE OBJECT definition_data
      EXPORTING
        value_type = 'lcl_hashmap:lcl_hashmap'.

    "# standardize line breaks
    REPLACE ALL OCCURRENCES OF REGEX '\r?\n' IN text WITH %_newline.

    "# remove surrounding line breaks
    text = trim(
      str  = text
      mask = '\n' ).

    "# split text into lines
    SPLIT text AT %_newline INTO TABLE lt_lines.

    "# iterate through lines to identify blocks
    markup = _lines( lt_lines ).

    "# trim line breaks
    markup = trim(
      str  = markup
      mask = '\n' ).

    " >>> apm
    DO 5 TIMES.
      CASE sy-index.
        WHEN 1.
          DATA(alert) = lcl_alerts=>get( '[!NOTE]' ).
        WHEN 2.
          alert = lcl_alerts=>get( '[!TIP]' ).
        WHEN 3.
          alert = lcl_alerts=>get( '[!IMPORTANT]' ).
        WHEN 4.
          alert = lcl_alerts=>get( '[!WARNING]' ).
        WHEN 5.
          alert = lcl_alerts=>get( '[!CAUTION]' ).
      ENDCASE.

      DATA(alert_html) = |<span style="color:{ alert-color };display:flex;align-items:center;">|
        && |{ alert-icon }&nbsp;&nbsp;|
        && |<strong>{ alert-text }</strong></span></p><p>|.

      markup = replace(
        val  = markup
        sub  = alert-tag
        with = alert_html
        occ  = 0 ).
    ENDDO.
    " <<< apm

  ENDMETHOD.                    "text


  METHOD trim.
    DATA lv_regex TYPE string.

    r_str = str.
    REPLACE ALL OCCURRENCES OF REGEX '([\.\?\*\+\|])' IN mask WITH '\\$1'.
    CONCATENATE '(\A[' mask ']*)|([' mask ']*\Z)' INTO lv_regex.
    REPLACE ALL OCCURRENCES OF REGEX lv_regex IN r_str WITH ''.
  ENDMETHOD.                    "trim


  METHOD unmarked_text.
    DATA lv_break TYPE string.

    CONCATENATE '<br />' %_newline INTO lv_break.
    r_text = text.

    IF breaks_enabled IS NOT INITIAL.
      REPLACE ALL OCCURRENCES OF REGEX '[ ]*\n' IN r_text WITH lv_break.
    ELSE.
      REPLACE ALL OCCURRENCES OF REGEX '(?:[ ][ ]+|[ ]*\\)\n' IN r_text WITH lv_break.
      REPLACE ALL OCCURRENCES OF REGEX ' \n' IN r_text WITH %_newline.
    ENDIF.
  ENDMETHOD.                    "unmarked_text


  METHOD _adjust_a_href.
    ">>> apm
    r_source = _adjust_link(
      root   = config-root_href
      source = source ).

    " Open external links in new browser window
    IF config-sapevent = abap_true AND r_source CP 'http*'.
      r_source = 'sapevent:url?url=' && r_source.
    ENDIF.
    "<<< apm
  ENDMETHOD.


  METHOD _adjust_img_src.
    ">>> apm
    r_source = _adjust_link(
      root   = config-root_img
      source = source ).
    "<<< apm
  ENDMETHOD.


  METHOD _adjust_link.
    ">>> apm
    r_source = source.

    CHECK root IS NOT INITIAL
      AND source IS NOT INITIAL
      AND source NP 'http*'
      AND source(1) <> '#'.

    IF r_source CP '/*'.
      r_source = source.
    ELSEIF r_source CP './*'.
      r_source = config-path && source+2.
    ELSE.
      r_source = config-path && source.
    ENDIF.

    r_source = root && config-path_util->normalize( r_source ).
    "<<< apm
  ENDMETHOD.


  METHOD _adjust_markup.
    ">>> apm
    DATA:
      lt_matches TYPE match_result_tab,
      lv_href    TYPE string,
      lv_url     TYPE string.

    FIELD-SYMBOLS:
      <ls_match>    LIKE LINE OF lt_matches,
      <ls_submatch> LIKE LINE OF <ls_match>-submatches.

    r_source = source.

    FIND ALL OCCURRENCES OF REGEX 'href\s*=\s*"([^"]*)"' IN r_source RESULTS lt_matches.

    SORT lt_matches DESCENDING BY line DESCENDING offset.

    LOOP AT lt_matches ASSIGNING <ls_match>.
      READ TABLE <ls_match>-submatches ASSIGNING <ls_submatch> INDEX 1.
      ASSERT sy-subrc = 0.

      lv_href = r_source+<ls_submatch>-offset(<ls_submatch>-length).
      lv_url = _adjust_a_href( lv_href ).
      REPLACE lv_href IN r_source WITH lv_url.
    ENDLOOP.

    CLEAR lt_matches.

    FIND ALL OCCURRENCES OF REGEX 'src\s*=\s*"([^"]*)"' IN r_source RESULTS lt_matches.

    SORT lt_matches DESCENDING BY line DESCENDING offset.

    LOOP AT lt_matches ASSIGNING <ls_match>.
      READ TABLE <ls_match>-submatches ASSIGNING <ls_submatch> INDEX 1.
      ASSERT sy-subrc = 0.

      lv_href = r_source+<ls_submatch>-offset(<ls_submatch>-length).
      lv_url = _adjust_img_src( lv_href ).
      REPLACE lv_href IN r_source WITH lv_url.
    ENDLOOP.
    "<<< apm
  ENDMETHOD.


  METHOD _escape.
    output = htmlspecialchars(
      input        = text
      ent_html401  = abap_true
      ent_noquotes = allow_quotes
      ent_quotes   = boolc( allow_quotes IS INITIAL ) ).
  ENDMETHOD.


  METHOD _lines.
    DATA:
      ls_current_block         TYPE ty_block,
      lv_line                  TYPE string,
      lv_chopped_line          TYPE string,
      lt_parts                 TYPE TABLE OF string,
      lv_shortage              TYPE i,
      lv_spaces                TYPE string,
      lv_indent                TYPE i,
      lv_text                  TYPE string,
      lv_continue_to_next_line TYPE abap_bool,
      ls_line                  TYPE ty_line,
      lv_method_name           TYPE string,
      ls_block                 TYPE ty_block,
      lv_marker                TYPE string,
      lo_block_types           TYPE REF TO lcl_string_array,
      lo_sa                    TYPE REF TO lcl_string_array,
      lt_blocks                TYPE TABLE OF ty_block,
      lv_block_markup          TYPE string.

    FIELD-SYMBOLS:
      <block>           LIKE LINE OF lt_blocks,
      <block_type_name> TYPE string,
      <block_type>      TYPE lcl_hashmap=>ty_item,
      <part>            LIKE LINE OF lt_parts.

    LOOP AT lines INTO lv_line.

      lv_chopped_line = lv_line.
      REPLACE REGEX '\s+$' IN lv_chopped_line WITH ''.
      IF strlen( lv_chopped_line ) = 0.
        ls_current_block-interrupted = abap_true.
        CONTINUE.
      ENDIF.

      IF lv_line CS %_horizontal_tab.
        SPLIT lv_line AT %_horizontal_tab INTO TABLE lt_parts.
        LOOP AT lt_parts ASSIGNING <part>.
          AT FIRST.
            lv_line = <part>.
            CONTINUE.
          ENDAT.
          lv_shortage = 4 - ( strlen( lv_line ) MOD 4 ).
          CLEAR lv_spaces.
          DO lv_shortage TIMES.
            CONCATENATE lv_spaces space INTO lv_spaces RESPECTING BLANKS.
          ENDDO.
          CONCATENATE lv_line lv_spaces <part> INTO lv_line RESPECTING BLANKS.
        ENDLOOP. "lt_parts
      ENDIF.

      CLEAR lv_spaces.
      FIND REGEX '^(\s+)' IN lv_line SUBMATCHES lv_spaces.
      lv_indent = strlen( lv_spaces ).
      IF lv_indent > 0.
        lv_text = lv_line+lv_indent.
      ELSE.
        lv_text = lv_line.
      ENDIF.

      "# ~

      CLEAR ls_line.
      ls_line-body = lv_line.
      ls_line-indent = lv_indent.
      ls_line-text = lv_text.

      "# ~

      IF ls_current_block-continuable IS NOT INITIAL.
        CLEAR ls_block.
        CONCATENATE 'block_' ls_current_block-type '_continue' INTO lv_method_name.
        TRANSLATE lv_method_name TO UPPER CASE.
        CALL METHOD (lv_method_name)
          EXPORTING
            line    = ls_line
            block   = ls_current_block
          RECEIVING
            r_block = ls_block.
        IF ls_block IS NOT INITIAL.
          ls_current_block = ls_block.
          CONTINUE.
        ELSE.
          CONCATENATE 'block_' ls_current_block-type '_complete' INTO lv_method_name.
          TRANSLATE lv_method_name TO UPPER CASE.
          READ TABLE methods TRANSPORTING NO FIELDS WITH KEY table_line = lv_method_name.
          IF sy-subrc = 0.
            CALL METHOD (lv_method_name)
              EXPORTING
                block   = ls_current_block
              RECEIVING
                r_block = ls_current_block.
          ENDIF.
        ENDIF. "ls_block is not initial.
        CLEAR ls_current_block-continuable.
      ENDIF. "ls_current_block-continuable is not initial.

      "# ~

      lv_marker = lv_text(1).

      "# ~

      CREATE OBJECT lo_block_types.
      lo_block_types->copy( unmarked_block_types ).

      READ TABLE block_types->data ASSIGNING <block_type>
        WITH KEY key = lv_marker.
      IF sy-subrc = 0.
        lo_sa ?= <block_type>-value.
        lo_block_types->append_array( lo_sa ).
      ENDIF.

      "#
      "# ~

      LOOP AT lo_block_types->data ASSIGNING <block_type_name>.
        CLEAR ls_block.
        CONCATENATE 'block_' <block_type_name> INTO lv_method_name.
        TRANSLATE lv_method_name TO UPPER CASE.
        CALL METHOD (lv_method_name)
          EXPORTING
            line    = ls_line
            block   = ls_current_block
          RECEIVING
            r_block = ls_block.

        IF ls_block IS NOT INITIAL.
          ls_block-type = <block_type_name>.

          IF ls_block-identified IS INITIAL.
            APPEND ls_current_block TO lt_blocks.
            ls_block-identified = abap_true.
          ENDIF.

          CONCATENATE 'block_' <block_type_name> '_continue' INTO lv_method_name.
          TRANSLATE lv_method_name TO UPPER CASE.
          READ TABLE methods TRANSPORTING NO FIELDS WITH KEY table_line = lv_method_name.
          IF sy-subrc = 0.
            ls_block-continuable = abap_true.
          ENDIF.

          ls_current_block = ls_block.
          lv_continue_to_next_line = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP. "lo_block_types->data

      IF lv_continue_to_next_line IS NOT INITIAL.
        CLEAR lv_continue_to_next_line.
        CONTINUE.
      ENDIF.

      "# ~

      IF ls_current_block IS NOT INITIAL AND
         ls_current_block-type IS INITIAL AND
         ls_current_block-interrupted IS INITIAL.
        CONCATENATE ls_current_block-element-text-text %_newline lv_text
         INTO ls_current_block-element-text-text.
      ELSE.
        APPEND ls_current_block TO lt_blocks.

        ls_current_block = paragraph( ls_line ).

        ls_current_block-identified = abap_true.
      ENDIF.

    ENDLOOP. "lines

    "# ~

    IF ls_current_block-continuable IS NOT INITIAL.
      CONCATENATE 'block_' ls_current_block-type '_complete' INTO lv_method_name.
      TRANSLATE lv_method_name TO UPPER CASE.
      READ TABLE methods TRANSPORTING NO FIELDS WITH KEY table_line = lv_method_name.
      IF sy-subrc = 0.
        CALL METHOD (lv_method_name)
          EXPORTING
            block   = ls_current_block
          RECEIVING
            r_block = ls_current_block.
      ENDIF.
    ENDIF.

    APPEND ls_current_block TO lt_blocks.
    DELETE lt_blocks INDEX 1.

    "# ~

    LOOP AT lt_blocks ASSIGNING <block>.
      CHECK <block>-hidden IS INITIAL.

      IF <block>-markup IS NOT INITIAL.
        lv_block_markup = <block>-markup.
      ELSE.
        lv_block_markup = element( <block>-element ).
      ENDIF.
      CONCATENATE markup %_newline lv_block_markup INTO markup RESPECTING BLANKS.
    ENDLOOP.

    CONCATENATE markup %_newline INTO markup RESPECTING BLANKS.
  ENDMETHOD.                    "lines
ENDCLASS.
