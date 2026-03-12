#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Name: test.sh
#   Description: a test suite for YAml parser in pure baSH
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

. ./ya.sh

check_data() {
  local i res=0 BB
  for i in "${!expected[@]}"; do
    [[ "${expected["$i"]}" == "${parsed["$i"]}" ]] || {
      BB+=" $i "
      yashLogError ""
      printf "                                  expected[$i]=%q\n                                    parsed[$i]=%q\n" "${expected[$i]}" "${parsed[$i]}"
      res=1
    }
  done
  for i in "${!parsed[@]}"; do
    [[ "$BB" != *"$i"* ]] && [[ "${parsed["$i"]}" != "${expected["$i"]}" ]] && {
      yashLogError ""
      printf "                                  expected[$i]=%q\n                                    parsed[$i]=%q\n" "${expected[$i]}" "${parsed[$i]}"
      res=1
    }
  done
  return $res
}

unset expected
declare -A expected
overall_result=0
test_number=0
check() {
  local res=0
  local tmp=`mktemp`
  local tmp2=`mktemp`
  unset parsed
  declare -g -A parsed
  let test_number++
  yash_parse parsed "$yaml_data" >$tmp 2>&1 || res=1
  [[ $res -eq 0 ]] && check_data >$tmp2 2>&1 || res=1
  [[ $res -eq ${1:-0} ]] && {
    [[ -n "$TEST_DEBUG" ]] && {
      yashLog "test $test_number${2:+": $2"}" "BEGIN"
      cat $tmp2
      cat $tmp
      declare -p expected parsed
    }
    yashLog "test $test_number${2:+": $2"}" "PASS "
  } || {
    yashLog "test $test_number${2:+": $2"}" "BEGIN"
    cat $tmp2
    cat $tmp
    declare -p expected parsed
    yashLog "test $test_number${2:+": $2"}" "FAIL "
    let overall_result++
  }
  rm -f $tmp $tmp2
}

yaml_data='- g: a
b:
   - i
'
check 1 "wrong format"


yaml_data='- >
  a   1
  b
-
  c: x
  x: y
- c: x
  x: y
-
 e
 f
-
 - e
 - f
- g:
  - a
  - h
  - i
'
check 1


yaml_data='- >
  a   1
  b
-
  c: x
  x: y
- c: x
  x: y
-
 e
 f
-
 - e
 - f
-
  - a
  - h
  - i
'
declare -A expected=(
[0]='a   1 b
'
[1.c]="x"
[1.x]="y"
[2.c]="x"
[2.x]="y"
[3]="e f"
[4.0]="e"
[4.1]="f"
[5.0]="a"
[5.1]="h"
[5.2]="i"
)
check


yaml_data="
framework: beakerlib
tag:
- FedoraCI
- CI-Tier-1
- NoRHEL4
- NoRHEL5
- NoRHEL6
- SP-TBU
- TIPfail
- TIPfail_Security
- Tier1
- Tier1security
tags:
- generic
component:
- usbguard
contact:
- Dalibor Pospíšil <dapospis@redhat.com>
description: ''
recommend:
- usbguard
require:
- library(ControlFlow/Cleanup)
- library(ControlFlow/ConditionalPhases)
- beakerlib
summary: tries out valid and invalid config file keywords
test: ./runtest.sh
duration: 10m
environment:
    CONDITIONAL_PHASES_BL: 'only|both'
extra-nitrate: TC#0560519
extra-summary: CONDITIONAL_PHASES_BL=only|both /CoreOS/usbguard/Sanity/config-sanity
extra-task: /CoreOS/usbguard/Sanity/config-sanity
relevancy: |
    arch = s390x: False
    distro < rhel-7.6: False
path: /usbguard/Sanity/config-sanity
manual: false
enabled: true
result: respect
tier: null
name: /usbguard/Sanity/config-sanity/base
"
declare -A expected=(
[framework]="beakerlib"
[tag.0]="FedoraCI"
[tag.1]="CI-Tier-1"
[tag.2]="NoRHEL4"
[tag.3]="NoRHEL5"
[tag.4]="NoRHEL6"
[tag.5]="SP-TBU"
[tag.6]="TIPfail"
[tag.7]="TIPfail_Security"
[tag.8]="Tier1"
[tag.9]="Tier1security"
[tags.0]="generic"
[component.0]="usbguard"
[contact.0]="Dalibor Pospíšil <dapospis@redhat.com>"
[description]=""
[recommend.0]="usbguard"
[require.0]="library(ControlFlow/Cleanup)"
[require.1]="library(ControlFlow/ConditionalPhases)"
[require.2]="beakerlib"
[summary]="tries out valid and invalid config file keywords"
[test]="./runtest.sh"
[duration]="10m"
[environment.CONDITIONAL_PHASES_BL]="only|both"
[extra-nitrate]="TC#0560519"
[extra-summary]="CONDITIONAL_PHASES_BL=only|both /CoreOS/usbguard/Sanity/config-sanity"
[extra-task]="/CoreOS/usbguard/Sanity/config-sanity"
[relevancy]="arch = s390x: False
distro < rhel-7.6: False
"
[path]="/usbguard/Sanity/config-sanity"
[manual]="false"
[enabled]="true"
[result]="respect"
[tier]="null"
[name]="/usbguard/Sanity/config-sanity/base"
)
check 0 "real live example 1"


yaml_data='a:
- b
- c'
declare -A expected=(
[a.0]='b'
[a.1]="c"
)
check


yaml_data='
---
- |
  asdfa
  dsf
-
'
declare -A expected=(
[0]='asdfa
dsf
'
[1]='null'
)
check

yaml_data='
- |
  asd
  fa

  dsf

   afd


- >
  asd
  fa

  dsf

   afd


'
declare -A expected=(
[0]='asd
fa

dsf

 afd
'
[1]='asd fa
dsf

 afd
'
)
check 0 "|, >"

yaml_data='
- |-
  asd
  fa

  dsf

   afd


- >-
  asd
  fa

  dsf

   afd


'
declare -A expected=(
[0]='asd
fa

dsf

 afd'
[1]='asd fa
dsf

 afd'
)
check 0 "|-, >-"


yaml_data='
- |+
  asd
  fa

  dsf

   afd


- >+
  asd
  fa

  dsf

   afd


-'
declare -A expected=(
[0]='asd
fa

dsf

 afd


'
[1]='asd fa
dsf

 afd


'
[2]=null
)
check 0 "|+, >+"


yaml_data='
- [a, b, ab, [c, d]]
'
declare -A expected=(
[0.0]='a'
[0.1]='b'
[0.2]='ab'
[0.3.0]='c'
[0.3.1]='d'
)
check 0 "json list"


yaml_data='
- {a: 1, b: 2, ab: 3, e: {c: 4, d: 5}}
'
declare -A expected=(
[0.a]='1'
[0.b]='2'
[0.ab]='3'
[0.e.c]='4'
[0.e.d]='5'
)
check 0 "json dict"


yaml_data='
- [a, b, ab, {c: 4, d: 5}]
- {a: [b, c]}
'
declare -A expected=(
[0.0]='a'
[0.1]='b'
[0.2]='ab'
[0.3.c]='4'
[0.3.d]='5'
[1.a.0]='b'
[1.a.1]='c'
)
check 0 "combined json structure"


yaml_data="
\"a\": \"b c\"
'd': 'e f'
g: afsd \"sdf\" dfs
"
declare -A expected=(
[a]='b c'
[d]='e f'
[g]='afsd "sdf" dfs'
)
check 0 "quotes removal"


yaml_data="framework: beakerlib
tag:
- FedoraCI
- CI-Tier-1
tags:
- generic
component:
- usbguard
contact:
- Dalibor Pospíšil <dapospis@redhat.com>
description: ''
recommend:
- usbguard
require:
- library(ControlFlow/Cleanup)
- library(ControlFlow/ConditionalPhases)
- beakerlib
summary: tries out valid and invalid config file keywords
test: ./runtest.sh
duration: 5m
environment:
    CONDITIONAL_PHASES_WL: only|both
extra-nitrate: TC#0608867
extra-summary: CONDITIONAL_PHASES_WL='only|both' /CoreOS/usbguard/Sanity/config-sanity
relevancy: |
    arch = s390x: False
    distro < rhel-7.6: False
path: /usbguard/Sanity/config-sanity
manual: false
enabled: true
result: respect
tier: null
name: /usbguard/Sanity/config-sanity/rule_options
"
declare -A expected=(
[framework]=beakerlib
[tag.0]=FedoraCI
[tag.1]='CI-Tier-1'
[tags.0]=generic
[component.0]=usbguard
[contact.0]='Dalibor Pospíšil <dapospis@redhat.com>'
[description]=''
[recommend.0]=usbguard
[require.0]='library(ControlFlow/Cleanup)'
[require.1]='library(ControlFlow/ConditionalPhases)'
[require.2]='beakerlib'
[summary]='tries out valid and invalid config file keywords'
[test]='./runtest.sh'
[duration]=5m
[environment.CONDITIONAL_PHASES_WL]='only|both'
[extra-nitrate]='TC#0608867'
[extra-summary]="CONDITIONAL_PHASES_WL='only|both' /CoreOS/usbguard/Sanity/config-sanity"
[relevancy]="arch = s390x: False
distro < rhel-7.6: False
"
[path]='/usbguard/Sanity/config-sanity'
[manual]=false
[enabled]=true
[result]=respect
[tier]=null
[name]='/usbguard/Sanity/config-sanity/rule_options'
)
check 0 "real live example 2"


yaml_data="- { a : b, ' a ': c }
"
declare -A expected=(
[0.a]='b'
['0. a ']='c'
)
check 0 "dict key spaces stripping"


yaml_data="- []
"
declare -A expected=(

)
check 0 "empty list"


yaml_data="
require:
- url: https://github.com/RedHat-SP-Security/tests.git
  name: /fapolicyd/Library/common
"
declare -A expected=(
[require.0.url]='https://github.com/RedHat-SP-Security/tests.git'
[require.0.name]='/fapolicyd/Library/common'
)
check 0 "fmf id reference"


yaml_data="
require:
-
  url: https://github.com/RedHat-SP-Security/tests.git
  name: /fapolicyd/Library/common
-
  library(ControlFlow/Cleanup)
"
declare -A expected=(
[require.0.url]='https://github.com/RedHat-SP-Security/tests.git'
[require.0.name]='/fapolicyd/Library/common'
[require.1]='library(ControlFlow/Cleanup)'
)
check 0 "wrapped list items"


yaml_data="
-
  -a
"
declare -A expected=(
[0]='-a'
)
check 0 "wrong list item"


yaml_data="
-
  a:b
"
declare -A expected=(
[0]='a:b'
)
check 0 "wrong dict item"


yaml_data="
description: 'Bug summary: Rebase FAPOLICYD to the latest upstream version

    Bugzilla link: https://bugzilla.redhat.com/show_bug.cgi?id=1817413

    '
relevancy: '
    distro < rhel-8: False

    distro < rhel-8.3: False
    '
relevancy2: '

    distro < rhel-8: False


    distro < rhel-8.3: False

    '
"
declare -A expected=(
[description]='Bug summary: Rebase FAPOLICYD to the latest upstream version
Bugzilla link: https://bugzilla.redhat.com/show_bug.cgi?id=1817413
'
[relevancy]=' distro < rhel-8: False
distro < rhel-8.3: False '
[relevancy2]='
distro < rhel-8: False

distro < rhel-8.3: False
'
)
check 0 "quoted string"


yaml_data=$(cat - << 'EOF'
description: "code which should not be actually executed during the proseccing `false`"
EOF
)
declare -A expected=(
[description]="code which should not be actually executed during the proseccing \`false\`"
)
check 0 "backticks in the string"


# --- Anchors and aliases ---
yaml_data='
a: &x foo
b: *x
'
declare -A expected=(
[a]='foo'
[b]='foo'
)
check 0 "anchor and value alias (scalar)"

yaml_data='
- &anchor
  k: v
- *anchor
'
declare -A expected=(
[0.k]='v'
[1.k]='v'
)
check 0 "anchor and value alias (structure)"

yaml_data='
a: &k mykey
*k: value
'
declare -A expected=(
[a]='mykey'
[mykey]='value'
)
check 0 "key alias"

yaml_data='
a: &x
  b: *x
'
check 1 "alias cycle"

yaml_data='
a: *nonexistent
'
check 1 "unknown alias (value)"

yaml_data='
*nonexistent: value
'
check 1 "unknown alias (key)"


# --- YAML tags ---
yaml_data='
a: !!null
b: !!null null
'
declare -A expected=(
[a]='null'
[b]='null'
)
check 0 "!!null empty and !!null null"

yaml_data='
a: !!str hello
b: !!int 42
'
declare -A expected=(
[a]='hello'
[b]='42'
)
check 0 "!!str and !!int (tag stripped)"


# --- Preprocessing: document end, directives, comments ---
yaml_data='
key: before
...
ignore: after
'
declare -A expected=(
[key]='before'
)
check 0 "document end ... (content after ignored)"

yaml_data='
%YAML 1.1
key: value
'
declare -A expected=(
[key]='value'
)
check 0 "directive line % removed"

yaml_data='
# comment only
key: value
'
declare -A expected=(
[key]='value'
)
check 0 "comment-only leading line stripped"


# --- Unquote: escapes and single-quote '' ---
yaml_data='
a: "line1\nline2"
b: "tab\there"
c: "quote \" inside"
d: "backslash \\ end"
'
declare -A expected=(
[a]=$'line1\nline2'
[b]=$'tab\there'
[c]='quote " inside'
[d]=$'backslash \\ end'
)
check 0 'double-quoted escapes \\n \\t \\" \\\\'

yaml_data="
a: \"''\"
"
declare -A expected=(
[a]="'"
)
check 0 "single-quoted '' gives single quote"

yaml_data='
a: "unclosed
'
check 1 "unclosed double-quote"

yaml_data='
a: '\''unclosed
'
check 1 "unclosed single-quote"

yaml_data='
a: "closed" extra
'
check 1 "trailing content after closing quote"


# --- Structural error paths: bad indentation ---
yaml_data='
a: |
  good
 bad
'
check 1 "bad indentation in literal block"

yaml_data='
a: >
  good
 bad
'
check 1 "bad indentation in folded block"


# --- Empty / edge inputs ---
yaml_data=''
declare -A expected=(
)
check 0 "empty YAML"

yaml_data='
---
'
declare -A expected=(
)
check 0 "only --- and newlines"


echo _______________________________________________
[[ $overall_result -eq 0 ]] && {
  yashLog "overall result" "PASS "
  exit 0
} || {
  yashLog "overall result" "FAIL "
  exit 1
}
