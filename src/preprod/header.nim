# preprod / HEADER #
#------------------#

import
  strtabs,
  xam

use strutils,replace

# LINES

type
  PreprodLine* = tuple
    number: int
    length: int
    raw: string
    origin: string

  PreprodLines* = seq[PreprodLine]

# RESULT

type
  PreprodResult* = tuple
    ok: bool
    output: string

template GOOD*(content: string): PreprodResult = (ok: true, output: content)
template BAD*(error: string): PreprodResult = (ok: false, output: error)
template OK*(): PreprodResult = GOOD(STRINGS_EMPTY)

# FEATURES

const
  FEATURES_STANDARD* = "STANDARD" # standard commands
  FEATURES_INCLUDES* = "INCLUDES" # files inclusion
  FEATURES_BRANCHES* = "BRANCHES" # comments configuration
  FEATURES_COMMENTS* = "COMMENTS" # consoles outputs
  FEATURES_CONSOLES* = "CONSOLES" # logical branching
  FEATURES_ON* = "on"
  FEATURES_OFF* = "off"

type
  PreprodFeature = tuple
    enabled: bool
    name: string
    commands: StringSeq

  PreprodFeatures = seq[PreprodFeature]

# INCLUSIONS

type
  PreprodInclusion = tuple
    at: int
    lines: PreprodLines

  PreprodInclusions = seq[PreprodInclusion]

# BRANCHES

type
  PreprodBranch* = tuple
    process: bool # tells if it is currently processing commands (it depends on the condition evaluation result)
    last: string # this is the origin of the text line of the IF* command

  PreprodBranches = stack[PreprodBranch]

const
  DUMMY_BRANCH*: PreprodBranch = (process: false, last: STRINGS_EMPTY)

# PHASE

type
  PreprodPhase* = enum
    upInvalid = -1
    upUnprocessed = 0
    upPrefetchInclusions = 1
    upPreviewContent = 2
    upTranslateContent = 3
    upProcessDeferred = 4
    upProcessed = 5

# ERRORS

type
  PreprodError* {.pure.} = enum
    peUnknownError = 0
    peUnclosedBranch = 1
    peInexistentFile = 2
    peInexistentInclude = 3
    peUnexpectedCommand = 4
    peNoPrefix = 5
    pePrefixLength = 6
    peUndeferrableCommand = 7
    peMandatoryStandard = 8
    peBooleanOnly = 9
    peUnknownFeature = 10
    peArgumentsCount = 11
    peNoArguments = 12
    peDisabledCommand = 13
    peUnknownCommand = 14

const
  PREPROD_ARGUMENT* = "$1" # compatible with Rodster format on purpose

let
  PREPROD_ERROR_FORMATS* = (
    UNKNOWN_ERROR: PREPROD_ARGUMENT,
    UNCLOSED_BRANCH: "this branch was not closed",
    INEXISTENT_FILE: "the file '" & PREPROD_ARGUMENT & "' does not exist",
    INEXISTENT_INCLUDE: "the included file '" & PREPROD_ARGUMENT & "' does not exist",
    UNEXPECTED_COMMAND: "unexpected '" & PREPROD_ARGUMENT & "' command",
    NO_PREFIX: "no comment prefix supplied",
    PREFIX_LENGTH: "the comment prefix must be only one character long",
    UNDEFERRABLE_COMMAND: "can not defer a '" & PREPROD_ARGUMENT & "' command",
    MANDATORY_STANDARD: "the STANDARD feature commands can not be disabled",
    BOOLEAN_ONLY: "only on/off values are valid",
    UNKNOWN_FEATURE: "feature '" & PREPROD_ARGUMENT & "' is unknown",
    ARGUMENTS_COUNT: "arguments expected: " & PREPROD_ARGUMENT,
    NO_ARGUMENTS: "no arguments supplied",
    DISABLED_COMMAND: "command '" & PREPROD_ARGUMENT & "' belongs to a disabled feature",
    UNKNOWN_COMMAND: "command '" & PREPROD_ARGUMENT & "' is unknown"
  )

# FORMATTER

type
  PreprodFormatter* = DoubleArgsProc[PreprodError, string, string]

let
  DEFAULT_FORMATTER*: PreprodFormatter = proc (code: PreprodError, argument: string = STRINGS_EMPTY): string =
    template replacePreprodArgument(error: string): string = error.replace(PREPROD_ARGUMENT, argument)
    replacePreprodArgument case code:
      of peUnknownError: PREPROD_ERROR_FORMATS.UNKNOWN_ERROR
      of peUnclosedBranch: PREPROD_ERROR_FORMATS.UNCLOSED_BRANCH
      of peInexistentFile: PREPROD_ERROR_FORMATS.INEXISTENT_FILE
      of peInexistentInclude: PREPROD_ERROR_FORMATS.INEXISTENT_INCLUDE
      of peUnexpectedCommand: PREPROD_ERROR_FORMATS.UNEXPECTED_COMMAND
      of peNoPrefix: PREPROD_ERROR_FORMATS.NO_PREFIX
      of pePrefixLength: PREPROD_ERROR_FORMATS.PREFIX_LENGTH
      of peUndeferrableCommand: PREPROD_ERROR_FORMATS.UNDEFERRABLE_COMMAND
      of peMandatoryStandard: PREPROD_ERROR_FORMATS.MANDATORY_STANDARD
      of peBooleanOnly: PREPROD_ERROR_FORMATS.BOOLEAN_ONLY
      of peUnknownFeature: PREPROD_ERROR_FORMATS.UNKNOWN_FEATURE
      of peArgumentsCount: PREPROD_ERROR_FORMATS.ARGUMENTS_COUNT
      of peNoArguments: PREPROD_ERROR_FORMATS.NO_ARGUMENTS
      of peDisabledCommand: PREPROD_ERROR_FORMATS.DISABLED_COMMAND
      of peUnknownCommand: PREPROD_ERROR_FORMATS.UNKNOWN_COMMAND

# TAG

type
  PreprodTag* = object of RootObj

# STATE

type
  PreprodState* = tuple
    phase: PreprodPhase
    content: PreprodLines
    line: PreprodLine
    executions: int
    defines: StringSeq
    features: PreprodFeatures
    properties: StringTableRef
    inclusions: PreprodInclusions
    branches: PreprodBranches
    formatter: PreprodFormatter
    tag: ptr PreprodTag

# COMMANDS

const
  COMMAND_FEATURE* = "FEATURE"
  COMMAND_NOOP* = "NOOP"
  COMMAND_STOP* = "STOP"
  COMMAND_DEFER* = "DEFER"
  COMMAND_INCLUDE* = "INCLUDE"
  COMMAND_COMMENT* = "COMMENT"
  COMMAND_INFO* = "INFO"
  COMMAND_PRINT* = "PRINT"
  COMMAND_DEBUG* = "DEBUG"
  COMMAND_ERROR* = "ERROR"
  COMMAND_IFDEF* = "IFDEF"
  COMMAND_IFNDEF* = "IFNDEF"
  COMMAND_ELSE* = "ELSE"
  COMMAND_ENDIF* = "ENDIF"
  COMMAND_DEF* = "DEF"
  COMMAND_UNDEF* = "UNDEF"

type
  PreprodCallback* = proc (state: var PreprodState, cparameters: StringSeq): PreprodResult

  PreprodArguments* {.pure.} = enum
    uaAny = -2
    uaNonZero = -1
    uaNone = 0
    uaOne = 1
    uaTwo = 2
    uaThree = 3
    uaFour = 4
    uaFive = 5
    uaSix = 6
    uaSeven = 7
    uaEight = 8
    uaNine = 9

  PreprodCommand* = tuple
    feature: string
    name: string
    arguments: PreprodArguments
    callback: PreprodCallback

  PreprodCommands* = seq[PreprodCommand]

# PROPERTIES

const
  PREPROD_LINE_APPENDIX_KEY* = "LINE.APPENDIX"
  PREPROD_COMMENT_PREFIX_KEY* = "COMMENT.PREFIX"

# OPTIONS

type
  PreprodOptions* = tuple
    # input
    allowLeftWhitespace: bool
    linePrefix: string
    initialCommentPrefix: string
    initialEnabledFeatures: StringSeq
    initialConditionalDefines: StringSeq
    customPrefix: string
    # output
    keepBlankLines: bool
    initialLineAppendix: string

const
  INLINED_CONTENT* = "<inline>"
  DEFAULT_LINE_PREFIX* = STRINGS_PERIOD
  DEFAULT_COMMENT_PREFIX* = STRINGS_NUMERAL
  DEFAULT_COMMAND_PREFIX* = STRINGS_DOLLAR
  PREPROD_DEFAULT_OPTIONS*: PreprodOptions = (
    allowLeftWhitespace: true,
    linePrefix: DEFAULT_LINE_PREFIX & DEFAULT_COMMAND_PREFIX, # ".$", this is for builtin commands
    initialCommentPrefix: DEFAULT_COMMENT_PREFIX, # "#", could be changed at runtime via a builtin command
    initialEnabledFeatures: @[
      FEATURES_STANDARD, FEATURES_INCLUDES, FEATURES_COMMENTS, FEATURES_CONSOLES, FEATURES_BRANCHES
    ],
    initialConditionalDefines: @[],
    customPrefix: DEFAULT_LINE_PREFIX, # ".", this is for custom commands
    # OUTPUT
    keepBlankLines: true,
    initialLineAppendix: STRINGS_EOL
  )

let
  newPreprodOptions* = func (): PreprodOptions = PREPROD_DEFAULT_OPTIONS

# PREVIEWER

type
  PreprodPreviewer* = DoubleArgsProc[var PreprodState, PreprodResult, PreprodResult]

let
  DEFAULT_PREVIEWER*: PreprodPreviewer = proc (state: var PreprodState, r: PreprodResult): PreprodResult = r

# TRANSLATOR

type
  PreprodTranslator* = DoubleArgsProc[var PreprodState, PreprodResult, PreprodResult]

let
  DEFAULT_TRANSLATOR*: PreprodTranslator = proc (state: var PreprodState, r: PreprodResult): PreprodResult = r

# PREPROCESSOR

type
  PreprodPreprocessor* = ref object
    # input
    inline*: bool
    input*: StringSeq
    # commands
    custom*: PreprodCommands
    commands*: PreprodCommands
    # callbacks
    translator*: PreprodTranslator
    previewer*: PreprodPreviewer
    # options and state
    options*: PreprodOptions
    state*: PreprodState

const
  PREPROD_BUFFER_SIZE* = 8 * SIZES_KILOBYTE
