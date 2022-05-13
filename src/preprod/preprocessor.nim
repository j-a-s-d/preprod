# preprod / PREPROCESSOR #
#------------------------#

import
  xam,
  header, lines, state, commands

use sequtils,filter
use strutils,replace
use strutils,split
use strutils,strip
use strutils,startsWith

proc processCommand(line: string, state: var PreprodState, cmds: PreprodCommands): PreprodResult =
  result = OK
  let us = line.strip().split(STRINGS_SPACE).filter(x => x != STRINGS_EMPTY)
  if hasContent(us) and not omitCommand(us[0], state.phase):
    return executeCommand(us[0], us[1..^1], state, cmds)

proc processLine(ppp: PreprodPreprocessor, linePrefixLen: int, customPrefixLen: int): PreprodResult =
  let s = ppp.state.line.raw
  let l = if ppp.options.allowLeftWhitespace: s.strip() else: s
  if l.startsWith(ppp.options.linePrefix):
    processCommand(dropLeft(l, linePrefixLen), ppp.state, ppp.commands)
  elif l.startsWith(ppp.options.customPrefix):
    processCommand(dropLeft(l, customPrefixLen), ppp.state, ppp.custom)
  else:
    GOOD(s)

func cleanUp(output: string): string {.inline.} =
  # NOTE: this strips double blank lines eventually present
  # in code due to defensive precautions in code generation,
  # is only intended for an enhanced redability of the output,
  # and has nothing to do with the 'keepBlankLines' options flag.
  output.replace(STRINGS_EOL & STRINGS_EOL & STRINGS_EOL, STRINGS_EOL & STRINGS_EOL)

proc loopPhases(ppp: PreprodPreprocessor): PreprodResult =
  result = OK
  ppp.state.executions = 0
  let linePrefixLen = ppp.options.linePrefix.len
  let customPrefixLen = ppp.options.customPrefix.len
  let original = ppp.state.backupProperties()
  template makeError(location: string, code: PreprodError, argument: string = STRINGS_EMPTY): string =
    spaced(parenthesize(location), ppp.state.formatError(code, argument))
  while ppp.state.nextPhase():
    if ppp.state.phase != upProcessDeferred:
      ppp.state.restoreProperties(original)
    ppp.state.content.each line:
      ppp.state.line = line
      let z = ppp.processLine(linePrefixLen, customPrefixLen)
      if not z.ok:
        return BAD(makeError(line.origin, peUnknownError, z.output))
      let r = if ppp.state.phase == upPreviewContent:
        ppp.previewer(ppp.state, z)
      elif ppp.state.phase == upTranslateContent:
        ppp.translator(ppp.state, z)
      else:
        z # upProcessDeferred
      if not r.ok:
        return BAD(makeError(line.origin, peUnknownError, r.output))
      if ppp.state.phase == upTranslateContent and ppp.state.isCurrentlyProcessable:
        if hasContent(r.output) or ppp.options.keepBlankLines:
          result.output &= r.output & ppp.state.getPropertyValue(PREPROD_LINE_APPENDIX_KEY)
    if ppp.state.inBranch():
      return BAD(makeError(ppp.state.getLastBranchLocation(), peUnclosedBranch))
    if ppp.state.phase == upPrefetchInclusions and ppp.state.hasInclusionsToMerge():
      ppp.state.mergeInclusionsIntoContent()
  result.output = cleanUp(result.output.cleanUp())

proc loadContent(ppp: PreprodPreprocessor, bufferSize: int): PreprodResult =
  result = OK
  if ppp.inline:
    ppp.state.setContent(composePreprodLines(INLINED_CONTENT, ppp.input))
  else:
    let input = ppp.input[0]
    if filesDontExist(input):
      return BAD(ppp.state.formatError(peInexistentFile, input))
    else:
      var finput = open(input, bufSize = bufferSize)
      defer: close(finput)
      ppp.state.setContent(readPreprodLines(input, finput))

proc run*(ppp: PreprodPreprocessor): PreprodResult =
  result = ppp.loadContent(PREPROD_BUFFER_SIZE)
  if result.ok:
    ppp.state.setPropertyValue(PREPROD_LINE_APPENDIX_KEY, ppp.options.initialLineAppendix)
    ppp.state.setPropertyValue(PREPROD_COMMENT_PREFIX_KEY, ppp.options.initialCommentPrefix)
    ppp.options.initialEnabledFeatures.each feature:
      ppp.state.registerFeature(feature, ppp.commands.getFeatureCommandNames(feature))
    ppp.options.initialConditionalDefines.each define:
      ppp.state.addConditionalDefine(define)
    return ppp.loopPhases()

template initialize(ppp: var PreprodPreprocessor, defines: StringSeq, options: PreprodOptions, custom: PreprodCommands, translator: PreprodTranslator, previewer: PreprodPreviewer, formatter: PreprodFormatter): PreprodPreprocessor =
  ppp.custom = custom
  ppp.commands = setupPreprodCommands()
  ppp.translator = translator
  ppp.previewer = previewer
  ppp.options = options
  ppp.state = setupPreprodState(defines, formatter)
  ppp

proc newPreprodPreprocessor*(input: StringSeq, defines: StringSeq = newStringSeq(), options: PreprodOptions = PREPROD_DEFAULT_OPTIONS, custom: PreprodCommands = @[], translator: PreprodTranslator = DEFAULT_TRANSLATOR, previewer: PreprodPreviewer = DEFAULT_PREVIEWER, formatter: PreprodFormatter = DEFAULT_FORMATTER): PreprodPreprocessor =
  var ppp = new PreprodPreprocessor
  ppp.inline = true
  ppp.input = input
  ppp.initialize(defines, options, custom, translator, previewer, formatter)

proc newPreprodPreprocessor*(input: string, defines: StringSeq = newStringSeq(), options: PreprodOptions = PREPROD_DEFAULT_OPTIONS, custom: PreprodCommands = @[], translator: PreprodTranslator = DEFAULT_TRANSLATOR, previewer: PreprodPreviewer = DEFAULT_PREVIEWER, formatter: PreprodFormatter = DEFAULT_FORMATTER): PreprodPreprocessor =
  var ppp = new PreprodPreprocessor
  ppp.inline = false
  ppp.input = newStringSeq(input)
  ppp.initialize(defines, options, custom, translator, previewer, formatter)
