# preprod / PREPROCESSOR #
#------------------------#

import
  os, strutils, sequtils,
  xam,
  header, lines, state, commands

proc processCommand(line: string, state: var PreprodState, cmds: PreprodCommands): PreprodResult =
  let us = line.strip().split(STRINGS_SPACE).filter(x => x != STRINGS_EMPTY)
  if us.len > 0 and not omitCommand(us[0], state.phase):
    return executeCommand(us[0], us[1..^1], state, cmds)
  OK

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
  while ppp.state.nextPhase():
    if ppp.state.phase != upProcessDeferred:
      ppp.state.restoreProperties(original)
    ppp.state.content.each line:
      ppp.state.line = line
      let z = ppp.processLine(linePrefixLen, customPrefixLen)
      if not z.ok:
        return BAD(parenthesize(line.origin) & STRINGS_SPACE & z.output)
      let r = if ppp.state.phase == upPreviewContent:
        ppp.previewer(ppp.state, z)
      elif ppp.state.phase == upTranslateContent:
        ppp.translator(ppp.state, z)
      else:
        z # upProcessDeferred
      if not r.ok:
        return BAD(parenthesize(line.origin) & STRINGS_SPACE & r.output)
      if ppp.state.phase == upTranslateContent and ppp.state.isCurrentlyProcessable:
        if hasContent(r.output) or ppp.options.keepBlankLines:
          result.output &= r.output & ppp.state.getPropertyValue(PREPROD_LINE_APPENDIX_KEY)
    if ppp.state.inBranch():
      return BAD(parenthesize(ppp.state.getLastBranchLocation()) & STRINGS_SPACE & "this branch was not closed")
    if ppp.state.phase == upPrefetchInclusions and ppp.state.hasInclusionsToMerge():
      ppp.state.mergeInclusionsIntoContent()
  result.output = cleanUp(result.output.cleanUp())

proc loadContent(ppp: PreprodPreprocessor): PreprodResult =
  if ppp.inline:
    ppp.state.setContent(composePreprodLines(INLINED_CONTENT, ppp.input))
  else:
    let input = ppp.input[0]
    if not fileExists(input):
      return BAD("the file " & apostrophe(input) & " does not exist")
    var finput = open(input, bufSize=8000)
    defer: close(finput)
    ppp.state.setContent(readPreprodLines(input, finput))
  OK

proc run*(ppp: PreprodPreprocessor): PreprodResult =
  result = ppp.loadContent()
  if result.ok:
    ppp.state.setPropertyValue(PREPROD_LINE_APPENDIX_KEY, ppp.options.initialLineAppendix)
    ppp.state.setPropertyValue(PREPROD_COMMENT_PREFIX_KEY, ppp.options.initialCommentPrefix)
    ppp.options.initialEnabledFeatures.each feature:
      ppp.state.registerFeature(feature, ppp.commands.getFeatureCommandNames(feature))
    ppp.options.initialConditionalDefines.each define:
      ppp.state.addConditionalDefine(define)
    return ppp.loopPhases()

proc newPreprodPreprocessor*(input: StringSeq, defines: StringSeq = @[], options: PreprodOptions = PREPROD_DEFAULT_OPTIONS, custom: PreprodCommands = @[], translator: PreprodTranslator = DEFAULT_Translator, previewer: PreprodPreviewer = DEFAULT_PREVIEWER): PreprodPreprocessor =
  result = new PreprodPreprocessor
  result.inline = true
  result.input = input
  result.custom = custom
  result.commands = setupPreprodCommands()
  result.translator = translator
  result.previewer = previewer
  result.options = options
  result.state = setupPreprodState(defines)

proc newPreprodPreprocessor*(input: string, defines: StringSeq = @[], options: PreprodOptions = PREPROD_DEFAULT_OPTIONS, custom: PreprodCommands = @[], translator: PreprodTranslator = DEFAULT_Translator, previewer: PreprodPreviewer = DEFAULT_PREVIEWER): PreprodPreprocessor =
  result = new PreprodPreprocessor
  result.inline = false
  result.input = newStringSeq(input)
  result.custom = custom
  result.commands = setupPreprodCommands()
  result.translator = translator
  result.previewer = previewer
  result.options = options
  result.state = setupPreprodState(defines)
