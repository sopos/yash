#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: ya.sh
#   Description: YAml parser in pure baSH
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   YAml parser in pure baSH
#
#   Copyright © 2020 Dalibor Pospisil <sopos@sopos.eu>
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to
#   deal in the Software without restriction, including without limitation the
#   rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
#   sell copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#   IN THE SOFTWARE.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

: <<'=cut'
=pod

=head1 NAME

BeakerLib - ya.sh - a YAml parser in pure baSH

=head1 DESCRIPTION

This file contains a yaml parser to help to handle yaml metadata.

=head1 FUNCTIONS

=cut

yashLog() {
  printf ":: [ %(%T)T ] :: [ %s ] :: " -1 "${2:-" LOG "}" >&2
  echo -e "$1" >&2
}

yashLogDebug() {
  [[ -n "$DEBUG" ]] && yashLog "${FUNCNAME[1]}(): $1" "DEBUG"
}

yashLogError() {
  yashLog "${FUNCNAME[1]}(): $1" "ERROR"
}

__INTERNAL_yash_get_next() {
  local line IFS=$'\n' buffer_item type_name="$1" item_name="$2" yaml_data_name="$3"
  [[ -z "${!yaml_data_name}" ]] && return 1
  {
    read -r line
    buffer_item="$line"$'\n'
    if [[ "${line:0:1}" == '-' ]]; then
      yashLogDebug "detected list item '$line'"
      eval "$type_name='index'"
      while read -r line; do
        yashLogDebug "processing line '$line'"
        [[ -z "$line" || "${line:0:1}" == " " ]] || {
          yashLogDebug "next item begin detected"
          break
        }
        yashLogDebug "adding to item buffer"
        buffer_item+="$line"$'\n'
      done
      yashLogDebug "adding rest to rest buffer"
      buffer_rest="$line"$'\n'
      while read -r line; do
        buffer_rest+="$line"$'\n'
      done
    else
      yashLogDebug "detected associative array item '$line'"
      eval "$type_name='key'"
      while read -r line; do
        yashLogDebug "processing line '$line'"
        [[ -z "$line" || "${line:0:1}" == "-" || "${line:0:1}" == " " ]] || {
          yashLogDebug "next item begin detected"
          break
        }
        yashLogDebug "adding to item buffer"
        buffer_item+="$line"$'\n'
      done
      yashLogDebug "adding rest to rest buffer"
      buffer_rest="$line"$'\n'
      while read -r line; do
        buffer_rest+="$line"$'\n'
      done
    fi
  } <<< "${!yaml_data_name}"
  eval "${item_name}=\"\${buffer_item::\${#buffer_item}-1}\""
  eval "${yaml_data_name}=\"\${buffer_rest::\${#buffer_rest}-1}\""
}

__INTERNAL_yash_clean() {
  # remove comments, document markers, and directives
  local line IFS=$'\n' buffer non_space out_name="$1" in="$2" seen_doc_end
  while read -r line; do
    [[ "$line" == "---" ]] && {
      buffer=''
      seen_doc_end=''
      non_space=''
      continue
    }
    [[ "$line" == "..." ]] && { seen_doc_end=1; continue; }
    [[ -n "$seen_doc_end" ]] && continue
    [[ "$line" =~ ^[[:space:]]*% ]] && continue
    # remove first empty lines
    [[ -z "$non_space" && "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ [^[:space:]] ]] && non_space=1
    buffer+=$'\n'"$line"
  done <<< "$in"
  eval "$out_name=\"\${buffer:1}\""
}

__INTERNAL_yash_parse_item() {
  local IFS=$'\n' line buffer type_name="$1" key_name="$2" val_name="$3" item="$4" type
  {
    read -r line
    if [[ "${line:0:1}" == "-" ]]; then
      eval "$key_name=''"
      yashLogDebug "detected list item '${!key_name}'"
      type='list'
      buffer=" ${line:1}"$'\n'
    elif [[ "$line" =~ ^[[:space:]]*([^[:space:]][^:]*):(.*) ]]; then
      # strip starting spaces
      eval "$key_name=\"\${BASH_REMATCH[1]}\""
      yashLogDebug "detected associative array item '${!key_name}'"
      type='array'
      buffer="${BASH_REMATCH[2]}"$'\n'
      # strip trailing spaces
      [[ "${!key_name}" =~ (.*[^[:space:]])[[:space:]]*$ ]]
      eval "$key_name=\"\${BASH_REMATCH[1]}\""
    else
      yashLogError "could not parse item '$line'"
      return 1
    fi
    while read -r line; do
      buffer+="${line}"$'\n'
    done
  } <<< "$item"
  eval "$val_name=\"\${buffer::\${#buffer}-1}\""
  yashLogDebug "  with value '${!val_name}'"
  __INTERNAL_yash_sanitize_value "${type_name}" "${val_name}" || return 1
}

__INTERNAL_yash_sanitize_value() {
  local IFS=$'\n' line buffer type_name="$1" val_name="$2" indent space=' ' skip_last buffer2 i item2
  {
    while read -r line; do
      [[ "$line" =~ ^[[:space:]]*$ ]] || break
    done
    # Anchor-only line followed by indented content => structure (e.g. "- &anchor\n  k: v")
    if [[ "$line" =~ ^[[:space:]]*\&([[:alnum:]-]+)[[:space:]]*$ ]]; then
      __INTERNAL_YASH_PENDING_ANCHOR="${BASH_REMATCH[1]}"
      read -r line
      if [[ -n "$line" ]]; then
        yashLogDebug "sub-structure (after anchor)"
        eval "${type_name}=struct"
        [[ "$line" =~ ^([[:space:]]*) ]]
        indent=${#BASH_REMATCH[0]}
        buffer+=$'\n'"${line:$indent}"
        while read -r line; do
          [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
            yashLogError "syntax error - bad indentation"
            return 1
          }
          buffer+=$'\n'"${line:$indent}"
        done
      else
        __INTERNAL_YASH_PENDING_ANCHOR=""
      fi
    elif [[ "$line" =~ ^[[:space:]]*\|([+-]?)[[:space:]]*$ ]]; then
      skip_last="${BASH_REMATCH[1]}"
      yashLogDebug "multiline text"
      eval "${type_name}=text"
      read -r line
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      buffer+=$'\n'"${line:$indent}"
      while read -r line; do
        buffer+=$'\n'"${line:$indent}"
      done
      buffer+=$'\n'
      i=${#buffer}
      let i--
      while [[ $i -ge 0 && "${buffer:$i:1}" == $'\n' ]]; do let i--; done; let i++
      if [[ "$skip_last" == "-" ]]; then
        buffer="${buffer:0:$i}"
      elif [[ "$skip_last" == "" ]]; then
        let i++
        buffer="${buffer:0:$i}"
      fi
    elif [[ "$line" =~ ^[[:space:]]*\>([+-]?)[[:space:]]*$ ]]; then
      skip_last="${BASH_REMATCH[1]}"
      yashLogDebug "wrapped text"
      eval "${type_name}=text"
      read -r line
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      space=' '
      buffer+="${space}${line:$indent}"
      while read -r line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        [[ -z "${line:$indent}" ]] && {
          buffer+=$'\n'
          space=''
          :
        } || {
          [[ "${line:$indent:1}" == " " ]] && buffer+=$'\n'
          buffer+="${space}${line:$indent}"
          space=' '
        }
      done
      buffer+=$'\n'
      i=${#buffer}
      let i--
      while [[ $i -ge 0 && "${buffer:$i:1}" == $'\n' ]]; do let i--; done; let i++
      if [[ "$skip_last" == "-" ]]; then
        buffer="${buffer:0:$i}"
      elif [[ "$skip_last" == "" ]]; then
        let i++
        buffer="${buffer:0:$i}"
      fi
    elif [[ "$line" =~ ^[[:space:]]*(\[|\{) ]]; then
      local json_begin json_end json_prefix
      if [[ "${BASH_REMATCH[1]}" == "[" ]]; then
        yashLogDebug "json list"
        json_begin='[' json_end=']' json_prefix='- '
      else
        yashLogDebug "json dict"
        json_begin='{' json_end='}'
      fi
      eval "${type_name}=struct"
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer+="${line:$indent}"
      while read -r line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        buffer+=$'\n'"${line:$indent}"
      done
      eval "[[ \"\$buffer\" =~ ^[^$json_begin]*\\$json_begin(.*)\\$json_end[^$json_end]*\$ ]]"
      buffer2="${BASH_REMATCH[1]}"
      buffer=''
      item2=''
      while read -r -N 1 line; do
        yashLogDebug "processing element '$line'"
        [[ "$line" == "," ]] && {
          while read -r -N 1 line; do
            [[ "$line" == " " ]] || break
          done
          yashLogDebug "processing element '$line'"
          buffer+=$'\n'"$json_prefix$item2"
          item2=''
        }
        [[ "$line" == '[' || "$line" == '{' ]] && {
          i=1;
          item2+="$line"
          while read -r -N 1 line; do
            yashLogDebug "processing brackets inside '$line'"
            [[ "$line" == '[' || "$line" == '{' ]] && let i++
            [[ "$line" == ']' || "$line" == '}' ]] && let i--
            item2+="$line"
            [[ $i -eq 0 ]] && break
          done
          continue
        }
        item2+="$line"
      done <<< "$buffer2"
      [[ -n "$item2" && ! "$item2" =~ ^[[:space:]]*$ ]] && buffer+=$'\n'"$json_prefix$item2"
    elif [[ "$line" =~ ^[[:space:]]*(\'|\") ]]; then #'
      yashLogDebug "quoted string"
      eval "${type_name}=text"
      space=' '
      while :; do
        [[ "$line" =~ ^[[:space:]]*(.*)$ ]]
        line="${BASH_REMATCH[1]}"
        [[ "$line" =~ ^(.*[^[:space:]]*)[[:space:]]*$ ]]
        [[ -z "${BASH_REMATCH[1]}" ]] && {
          [[ "$space" == " " ]] && space=$'\n' || space+=$'\n'
        } || {
          buffer+="${space}${BASH_REMATCH[1]}"
          space=' '
        }
        read -r line || break
      done
    elif [[ "$line" =~ ^[[:space:]]*-([[:space:]]|$) || "$line" =~ ^[^:]*:([[:space:]]|$) ]]; then
      yashLogDebug "sub-structure"
      eval "${type_name}=struct"
      [[ "$line" =~ ^([[:space:]]*) ]]
      indent=${#BASH_REMATCH[0]}
      [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
        yashLogError "syntax error - bad indentation"
        return 1
      }
      buffer+=$'\n'"${line:$indent}"
      while read -r line; do
        [[ "${line:0:$indent}" =~ ^[[:space:]]*$ ]] || {
          yashLogError "syntax error - bad indentation"
          return 1
        }
        buffer+=$'\n'"${line:$indent}"
      done
    else
      yashLogDebug "simple string"
      eval "${type_name}=text"
      [[ "$line" =~ ^[[:space:]]$ ]] && read -r line
      [[ "$line" =~ ^[[:space:]]*([^[:space:]].*)$ ]]
      line="${BASH_REMATCH[1]}"
      [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]*$ ]]
      buffer+="${space}${BASH_REMATCH[1]}"
      while read -r line; do
        [[ "$line" =~ ^[[:space:]]*(.*)$ ]]
        line="${BASH_REMATCH[1]}"
        [[ "$line" =~ ^(.*[^[:space:]])[[:space:]]*$ ]]
        [[ -n "${BASH_REMATCH[1]}" ]] && \
        buffer+="${space}${BASH_REMATCH[1]}"
      done
    fi
  } <<< "${!val_name}"
  eval "$val_name=\"\${buffer:1}\""
}

# Unquote YAML scalar: strip outer ' or ", and resolve escapes.
# Double-quoted: use printf '%b' to resolve \\ \" \n \r \t \xNN (same as echo -e;
# printf '%b' is used so content starting with -n/-e is not treated as options).
# Single-quoted: '' -> '.
__INTERNAL_yash_unquote() {
  local var_name="$1" s result="" inner="" i=0 c len closed=0
  s="${!var_name}"
  # Trim leading/trailing whitespace so we can detect quoted form reliably.
  [[ "$s" =~ ^[[:space:]]*(.*)[[:space:]]*$ ]] && s="${BASH_REMATCH[1]}"
  len=${#s}
  # Too short for "x" or 'x'; or not quoted at all -> leave as-is.
  [[ $len -lt 2 ]] && return 0
  c="${s:0:1}"
  if [[ "$c" != "'" && "$c" != '"' ]]; then
    return 0
  fi
  if [[ "$c" == '"' ]]; then
    # Double-quoted: extract inner string (so \" does not end the string), then
    # resolve escapes via printf '%b' (like echo -e but safe for -n/-e content).
    i=1
    closed=0
    while [[ $i -lt $len ]]; do
      c="${s:$i:1}"
      if [[ "$c" == "\\" ]]; then
        ((i++))
        if [[ $i -lt $len && "${s:$i:1}" == '"' ]]; then
          # \" => literal " (add quote only so printf %b doesn't double-interpret)
          inner+='"'
          ((i++))
        else
          # other backslash escape: add \ and next char for printf '%b'
          [[ $i -lt $len ]] && inner+="\\${s:$i:1}" && ((i++))
          [[ $i -ge $len ]] && inner+="\\"
        fi
      elif [[ "$c" == "'" && $((i+1)) -lt $len && "${s:$((i+1)):1}" == "'" ]]; then
        # '' in double-quoted => single quote (per test expectation)
        inner+="'"
        ((i+=2))
      elif [[ "$c" == '"' ]]; then
        # Closing double-quote: end of scalar. Trailing content would be invalid.
        ((i++))
        if [[ $i -lt $len && "${s:$i}" =~ [^[:space:]] ]]; then
          yashLogError "unexpected content after closing quote"
          return 1
        fi
        closed=1
        break
      else
        # other characters are added to the inner string.
        inner+="${c}"
        ((i++))
      fi
    done
    # Reached end without closing " (e.g. "hello' or "hello) -> mismatched/unclosed quote.
    [[ $closed -eq 0 ]] && { yashLogError "unclosed double-quote"; return 1; }
    printf -v result '%b' "$inner"
  else
    # Single-quoted: only '' is escape (literal ').
    i=1
    closed=0
    while [[ $i -lt $len ]]; do
      c="${s:$i:1}"
      if [[ "$c" == "'" && $((i+1)) -lt $len && "${s:$((i+1)):1}" == "'" ]]; then
        result+="'"
        ((i++))
      elif [[ "$c" == "'" ]]; then
        # Closing single-quote: end of scalar. Trailing content would be invalid.
        ((i++))
        if [[ $i -lt $len && "${s:$i}" =~ [^[:space:]] ]]; then
          yashLogError "unexpected content after closing quote"
          return 1
        fi
        closed=1
        break
      else
        result+="${c}"
      fi
      ((i++))
    done
    # Reached end without closing ' (e.g. 'hello") -> mismatched/unclosed quote.
    [[ $closed -eq 0 ]] && { yashLogError "unclosed single-quote"; return 1; }
  fi
  # Safe assignment: no eval, so content cannot break or inject.
  printf -v "$var_name" '%s' "$result"
}

# Strip YAML tag (!!word) from scalar and optional following space.
# Normalize !!null: empty or "null" -> "null". Other built-in tags (!!str, !!int, etc.) just stripped.
__INTERNAL_yash_strip_tag() {
  local var_name="$1" s
  s="${!var_name}"
  if [[ "$s" =~ ^[[:space:]]*(!![[:alnum:]-]+)[[:space:]]*(.*)$ ]]; then
    s="${BASH_REMATCH[2]}"
    [[ "$s" =~ ^[[:space:]]*(.*)[[:space:]]*$ ]] && s="${BASH_REMATCH[1]}"
    if [[ "${BASH_REMATCH[1]}" == "!!null" && -z "$s" ]]; then
      s="null"
    fi
    printf -v "$var_name" '%s' "$s"
  fi
}

# Strip YAML anchor &name from start of scalar; sets __INTERNAL_YASH_LAST_ANCHOR if found.
__INTERNAL_yash_strip_anchor() {
  local var_name="$1" s
  s="${!var_name}"
  __INTERNAL_YASH_LAST_ANCHOR=""
  if [[ "$s" =~ ^[[:space:]]*\&([[:alnum:]-]+)([[:space:]]+(.*))?$ ]]; then
    __INTERNAL_YASH_LAST_ANCHOR="${BASH_REMATCH[1]}"
    s="${BASH_REMATCH[3]:-}"
    [[ "$s" =~ ^[[:space:]]*(.*)[[:space:]]*$ ]] && s="${BASH_REMATCH[1]}"
    printf -v "$var_name" '%s' "$s"
  fi
}

# Copy subtree at anchor to current_path in array yaml_name. Detect cycle.
__INTERNAL_yash_resolve_alias() {
  local yaml_name="$1" alias_name="$2" current_path="$3" anchor_path k newkey v safe
  [[ "$__INTERNAL_YASH_EXPANDING" == *"|${alias_name}|"* ]] && { yashLogError "alias cycle detected: $alias_name"; return 1; }
  [[ -z "${__INTERNAL_YASH_ANCHORS[$alias_name]:-}" ]] && { yashLogError "unknown alias: $alias_name"; return 1; }
  anchor_path="${__INTERNAL_YASH_ANCHORS[$alias_name]}"
  __INTERNAL_YASH_EXPANDING+="|${alias_name}|"
  eval 'for k in "${!'"$yaml_name"'[@]}"; do
    [[ "$k" == "'"$anchor_path"'" || "$k" == "'"$anchor_path"'".* ]] || continue
    if [[ "$k" == "'"$anchor_path"'" ]]; then newkey="'"$current_path"'"; else newkey="'"$current_path"'.${k#'"$anchor_path"'.}"; fi
    eval "v=\${'"$yaml_name"'[\"$k\"]}"
    safe=$(printf "%q" "$v")
    eval "'"$yaml_name"'[\"$newkey\"]=$safe"
  done'
  __INTERNAL_YASH_EXPANDING="${__INTERNAL_YASH_EXPANDING/|${alias_name}|/}"
  return 0
}

: <<'=cut'
=pod

=head3 yash_parse

Parse yaml data to the associative array.

    yash_parse VAR_NAME YAML_DATA

=over

=item VAR_NAME

Name of the variable to which the yaml structure will be saved.

Note that the variable needs to be predeclared as an associative array.

=item YAML_DATA

The actual yaml data.

=back

=cut

yash_parse() {
  local yaml_data item key value data_type item_type item_type_prev prefix="$3" index=0 yaml_name="$1" res=0
  # Top-level: init anchors and alias-expansion tracking for this parse.
  if [[ -z "$prefix" ]]; then
    unset __INTERNAL_YASH_ANCHORS
    declare -g -A __INTERNAL_YASH_ANCHORS
    __INTERNAL_YASH_EXPANDING=""
    __INTERNAL_YASH_PENDING_ANCHOR=""
  fi
  __INTERNAL_yash_clean yaml_data "$2"

  yashLogDebug "$yaml_data"
  yashLogDebug "============================="
  yashLogDebug ""

  while __INTERNAL_yash_get_next item_type item yaml_data; do
    [[ -n "$item_type_prev" ]] && {
      [[ "$item_type_prev" == "$item_type" ]] || { yashLogError "invalid input - different item types in one list"; return 1; }
    }
    item_type_prev="$item_type"
    __INTERNAL_yash_parse_item data_type key value "$item" || return 1
    [[ "$item_type" == "index" ]] && key=$((index++))
    __INTERNAL_yash_unquote key || return 1
    __INTERNAL_yash_strip_tag key
    __INTERNAL_yash_strip_anchor key
    # Key is *alias -> use the anchored node's scalar value as the key (key must be scalar).
    if [[ "$key" =~ ^[[:space:]]*\*([[:alnum:]-]+)[[:space:]]*$ ]]; then
      local _alias_key="${BASH_REMATCH[1]}" _anchor_path _ak _av
      _anchor_path="${__INTERNAL_YASH_ANCHORS[$_alias_key]:-}"
      [[ -z "$_anchor_path" ]] && { yashLogError "unknown alias in key: $_alias_key"; return 1; }
      # Resolve key from anchored scalar value (iterate so array access works in bash 4.1)
      key=""
      eval 'for _ak in "${!'"$yaml_name"'[@]}"; do [[ "$_ak" == "'"$_anchor_path"'" ]] && eval "_av=\${'"$yaml_name"'[\"\$_ak\"]}" && key="$_av" && break; done'
      key="${key//$'\n'/}"
      key="${key//$'\r'/}"
      __INTERNAL_YASH_LAST_ANCHOR=""  # do not overwrite anchor when key was an alias
    fi
    [[ -n "$__INTERNAL_YASH_LAST_ANCHOR" ]] && __INTERNAL_YASH_ANCHORS["$__INTERNAL_YASH_LAST_ANCHOR"]="$prefix$key"
    yashLogDebug "$prefix$key ($data_type):"
    yashLogDebug "$value'"
    yashLogDebug "-----------------------------"
    [[ "$data_type" != "struct" ]] && {
      if [[ -z "$value" ]]; then
        # Empty list item => null; empty dict value => empty string
        if [[ "$item_type" == "index" ]]; then
          eval "${yaml_name}[\"\$prefix\$key\"]='null'"
        else
          eval "${yaml_name}[\"\$prefix\$key\"]=\"\""
        fi
      else
        __INTERNAL_yash_unquote value || return 1
        local _had_null_tag=0
        [[ "$value" =~ ^[[:space:]]*!!null ]] || _had_null_tag=1
        __INTERNAL_yash_strip_tag value
        # Only treat empty as null when value was explicitly !!null
        [[ $_had_null_tag -eq 0 && -z "$value" ]] && value='null'
        # Value is *alias -> copy anchored subtree here (with cycle check).
        if [[ "$value" =~ ^[[:space:]]*\*([[:alnum:]-]+)[[:space:]]*$ ]]; then
          __INTERNAL_yash_resolve_alias "$yaml_name" "${BASH_REMATCH[1]}" "$prefix$key" || return 1
        else
          __INTERNAL_yash_strip_anchor value
          [[ -n "$__INTERNAL_YASH_LAST_ANCHOR" ]] && __INTERNAL_YASH_ANCHORS["$__INTERNAL_YASH_LAST_ANCHOR"]="$prefix$key"
          # Use temp for subscript to avoid "bad array subscript" with alias-resolved key (bash 4.1)
          local _dest
          _dest="$prefix$key"
          eval "${yaml_name}[\"$_dest\"]=\"\${value}\""
        fi
      fi
    }
    if [[ "$data_type" == "struct" ]]; then
      # Record anchor if struct came from anchor-only line (set in __INTERNAL_yash_sanitize_value)
      if [[ -n "${__INTERNAL_YASH_PENDING_ANCHOR:-}" ]]; then
        __INTERNAL_YASH_ANCHORS["$__INTERNAL_YASH_PENDING_ANCHOR"]="$prefix$key"
        __INTERNAL_YASH_PENDING_ANCHOR=""
      fi
      yashLogDebug "_____________________________"
      yash_parse "$yaml_name" "$value" "$prefix$key." || return 1
    fi
  done
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# AUTHORS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <sopos@sopos.eu>

=back

=cut
