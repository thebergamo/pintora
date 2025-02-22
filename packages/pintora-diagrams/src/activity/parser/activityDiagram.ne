@preprocessor typescript
@lexer lexer
@builtin "whitespace.ne"
@include "../../util/parser-grammars/config.ne"
@include "../../util/parser-grammars/comment.ne"

@{%
import * as moo from '@hikerpig/moo'
// import { tv, textToCaseInsensitiveRegex, VALID_TEXT_REGEXP, COMMENT_LINE_REGEXP } from '../../util/parser-shared'
import {
  tv,
  textToCaseInsensitiveRegex,
  VALID_TEXT_REGEXP,
  COMMENT_LINE_REGEXP,
  CONFIG_DIRECTIVE,
  QUOTED_WORD_REGEXP,
  configLexerMainState,
  configLexerConfigClauseState,
  L_PAREN_REGEXP,
  R_PAREN_REGEXP,
} from '../../util/parser-shared'
import type { ApplyPart } from '../db'

const COMMON_TOKEN_RULES = {
  VALID_TEXT: { match: VALID_TEXT_REGEXP, fallback: true },
}

let lexer = moo.states({
  main: {
    NEWLINE: { match: /\n/, lineBreaks: true },
    SPACE: { match: / /, lineBreaks: false },
    QUOTED_WORD: QUOTED_WORD_REGEXP,
    SEMICOLON: /;/,
    COLON: /:/,
    L_PAREN: L_PAREN_REGEXP,
    R_PAREN: R_PAREN_REGEXP,
    L_BRACKET: { match: /\{/ },
    R_BRACKET: { match: /\}/ },
    START_NOTE: textToCaseInsensitiveRegex('@note'),
    END_NOTE: textToCaseInsensitiveRegex('@end_note'),
    COMMENT_LINE: COMMENT_LINE_REGEXP,
    ...configLexerMainState,
    VALID_TEXT: { match: VALID_TEXT_REGEXP, fallback: true },
  },
  configClause: {
    ...configLexerConfigClauseState,
    ...COMMON_TOKEN_RULES,
  },
})

let yy

export function setYY(v) {
  yy = v
}

function extractChildren(o) {
  return Array.isArray(o) ? o[0]: o
}
%}

start -> __ start {% (d) => d[1] %}
	| "activityDiagram" document __:? {%
      function(d) {
        return d[1]
      }
    %}

document -> null
  | document line {%
    (d) => {
        // console.log('[doc line]', d[1])
        const r = d[0].concat(d[1])
        return r
      }
    %}

line ->
	  %SPACE:* statement {% (d) => {
      // console.log('[line]', JSON.stringify(d[1], null, 2))
      return d[1]
    } %}
	| %NEWLINE

statement ->
    action
  | ("start"|"stop"|"end"|"detach"|"kill") %NEWLINE {%
      function(d) {
        const keyword = tv(d[0][0])
        return {
          type: 'keyword',
          label: keyword,
        }
      }
    %}
  | group
  | conditionSentence
  | whileSentence
  | switchSentence
  | forkSentence
  | noteStatement
  | arrowLabelStatement
  | paramClause _ %NEWLINE
  | configClause _ %NEWLINE
  | comment _ %NEWLINE

conditionSentence ->
    "if" %SPACE:+ wordsInParens %SPACE:+ "then" (%SPACE:+ wordsInParens):? %SPACE:* %NEWLINE line:* elseClause:? _ "endif" _ %NEWLINE {%
      function(d) {
        // console.log('[conditions]', d[2])
        const thenLabel = (d[5] ? d[5][1]: null) || ''
        const elseResult = d[9]
        return {
          type: 'condition',
          message: d[2],
          then: { label: thenLabel, children: d[8].map(o => Array.isArray(o) ? o[0]: o) },
          else: elseResult,
        }
      }
    %}

elseClause ->
    %SPACE:* "else" __ wordsInParens:? %SPACE:* %NEWLINE line:* {%
      function(d) {
        return { label: d[3], children: d[6].map(o => Array.isArray(o) ? o[0]: o) }
      }
    %}

whileSentence ->
    "while" __ wordsInParens (%SPACE:+ "is" __ wordsInParens):? _ %NEWLINE line:* %SPACE:* "endwhile" (%SPACE:+ wordsInParens):? %NEWLINE {%
      function(d) {
        // console.log('[whileSentence]', d[6])
        const confirmLabel = d[3] ? d[3][3]: undefined
        const denyLabel = d[9] ? d[9][1]: undefined
        return {
          type: 'while',
          message: d[2],
          confirmLabel,
          denyLabel,
          children: d[6].map(o => Array.isArray(o) ? o[0]: o),
        }
      }
    %}

switchSentence ->
    "switch" __ wordsInParens %SPACE:* %NEWLINE (%SPACE:* caseClause):* %SPACE:* "endswitch" %SPACE:* %NEWLINE {%
      function(d) {
        const message = d[2]
        const children = d[5].map(o => o[1])
        // console.log('switch', message)
        return { type: 'switch', message, children }
      }
    %}

caseClause ->
    "case" __ wordsInParens %SPACE:* %NEWLINE line:* {%
      function(d) {
        const confirmLabel = d[2].trim()
        const children = d[5].map(o => Array.isArray(o) ? o[0]: o)
        return { type: 'case', confirmLabel, children }
      }
    %}

forkSentence ->
    "fork" %SPACE:* %NEWLINE (__ statement):+ (_ forkAgainClause):* _ ("endfork"|"endmerge") %NEWLINE {%
      function(d) {
        const firstActions = d[3].map(a => extractChildren(a[1]))
        const forkAgains = d[4].map(a => a[1])
        const branches = [{ type: 'forkBranch', children: firstActions }, ...forkAgains]
        const endWord = tv(d[6][0])
        const shouldMerge = endWord  === 'endmerge'
        return { type: 'fork', shouldMerge, branches }
      }
    %}

forkAgainClause ->
    "forkagain" %SPACE:* %NEWLINE (__ statement):+ {%
      function(d) {
        const statements = d[3].map(a => extractChildren(a[1]))
        return { type: 'forkBranch', children: statements }
      }
    %}

wordsInParens ->
    %L_PAREN words %R_PAREN {% (d) => d[1] %}

words ->
    (%VALID_TEXT | %SPACE):+ {%
      function(d) {
        return d[0].map(o => tv(o[0])).join('')
      }
    %}

action ->
    %COLON multilineText %SEMICOLON _ %NEWLINE {%
      function(d) {
        return { type: 'addAction', action: { actionType: 'normal', message: d[1] } }
      }
    %}

multilineText ->
    (%VALID_TEXT|%SPACE|%NEWLINE):* {%
      function(d) {
        // console.log('[multiline text]', d)
        const v = d[0].map(l => {
          return l.map(o => tv(o))
        }).join('')
        return v
      }
    %}

groupType ->
    "group"
  | "partition"

group ->
    groupType __ (color %SPACE):? (%QUOTED_WORD | %VALID_TEXT) __ %L_BRACKET (__ statement):+ %SPACE:* %R_BRACKET %SPACE:* %NEWLINE {%
      function(d) {
        const groupType = tv(d[0][0])
        const background = d[2] ? (d[2][0]): null
        const titleToken = d[3][0]
        const title = titleToken.type === 'QUOTED_WORD' ? tv(titleToken).replace(/"(.*)"/, '$1') : tv(titleToken)
        const label = (title || groupType).trim()
        const name = (title || `${groupType}_${Date.now()}`).trim()
        const children = d[6].map(l => l[1][0]).filter(o => o)
        children.forEach(child => child.parent = name)
        return { type: 'group', name, groupType, label, background, children, } as ApplyPart
      }
    %}

placement ->
	  "left"  {% (d) => "left" %}
	| "right" {% (d) => "right" %}

multilineNoteText ->
    (%VALID_TEXT|%SPACE|%NEWLINE):* %END_NOTE {%
      function(d) {
        const v = d[0].map(l => {
          return l.map(o => tv(o))
        }).join('')
        let text = v
        if (v[v.length - 1] === '\n') {
          text = v.slice(0, v.length - 1)
        }
        return text
      }
    %}

noteStatement ->
	  ("note"|%START_NOTE) %SPACE:* placement %COLON words %NEWLINE {%
      function(d) {
        const text = d[4].trim()
        // console.log('[note one]\n', text)
        return { type: 'note', placement: d[2], text } as ApplyPart
      }
    %}
	| ("note"|%START_NOTE) %SPACE:* placement %SPACE:* %NEWLINE multilineNoteText %NEWLINE {%
      function(d) {
        // console.log('[note multi]\n', d[5])
        const text = d[5]
        return { type: 'note', placement: d[2], text } as ApplyPart
      }
    %}

arrowLabelStatement ->
    "->" __ words %SEMICOLON _ %NEWLINE {%
      function(d) {
        return { type: 'arrowLabel', text: d[2] } as ApplyPart
      }
    %}
