# preprod / COMMANDS #
#--------------------#

import
  os, strutils,
  xam,
  header, lines, state

func makeCommand*(feature: string, name: string, arguments: PreprodArguments, callback: PreprodCallback): PreprodCommand =
  (feature: feature, name: name, arguments: arguments, callback: callback)

func getFeatureCommandNames*(cmds: PreprodCommands, feature: string): StringSeq =
  cmds.each prc:
    if prc.feature == feature:
      result.add(prc.name)

func getCommand*(cmds: PreprodCommands, name: string): PreprodCommand =
  cmds.each prc:
    if prc.name == name:
      return prc

func omitCommand*(cmd: string, uphase: PreprodPhase): bool =
  let isFeature = cmd == COMMAND_FEATURE
  let isInclude = cmd == COMMAND_INCLUDE
  let isDefer = cmd == COMMAND_DEFER
  (uphase == upPrefetchInclusions and not isInclude and not isFeature) or
    (uphase != upPrefetchInclusions and (isInclude or isFeature)) or
    (uphase == upProcessDeferred and not isDefer) or
    (uphase != upProcessDeferred and isDefer)

func stripComments(up: StringSeq, cc: string): StringSeq =
  result = up
  var x = -1
  up.each ui:
    x += 1
    if ui.startsWith(cc):
      result = result[0..x-1]
      break

proc removeComments*(state: var PreprodState, text: string): string =
  if not state.isFeatureEnabled(FEATURES_COMMENTS):
    return text
  stripComments(text.strip().split(STRINGS_SPACE), state.getPropertyValue(PREPROD_COMMENT_PREFIX_KEY)).join(STRINGS_SPACE)

proc executeCommand*(command: string, parameters: StringSeq, state: var PreprodState, cmds: PreprodCommands): PreprodResult =
  let isCommentable = state.isFeatureEnabled(FEATURES_COMMENTS)
  let cp = state.getPropertyValue(PREPROD_COMMENT_PREFIX_KEY)
  let prc = cmds.getCommand(command)
  if not hasContent(prc.name):
    if isCommentable and command.startsWith(cp):
      return OK
    BAD(state.formatError(peUnknownCommand, command))
  elif not state.isFeatureEnabled(prc.feature):
    BAD(state.formatError(peDisabledCommand, command))
  else:
    let params = if isCommentable: stripComments(parameters, cp) else: parameters
    if prc.arguments != uaAny:
      if prc.arguments == uaNonZero:
        if params.len == 0:
          return BAD(state.formatError(peNoArguments))
      else:
        let amount = ord(prc.arguments)
        if params.len != amount:
          return BAD(state.formatError(peArgumentsCount, $amount))
    if not state.isCurrentlyProcessable and prc.feature != FEATURES_BRANCHES:
      return OK
    inc(state.executions)
    prc.callback(state, params)

proc setupPreprodCommands*(): PreprodCommands =
  var cmds: PreprodCommands
  # STANDARD
  cmds.add(makeCommand(FEATURES_STANDARD, COMMAND_FEATURE, uaTwo, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if not state.hasFeature(params[0]):
      return BAD(state.formatError(peUnknownFeature))
    if params[1] != FEATURES_ON and params[1] != FEATURES_OFF:
      return BAD(state.formatError(peBooleanOnly))
    let isOn = params[1] == FEATURES_ON
    if params[0] == FEATURES_STANDARD and not isOn:
      return BAD(state.formatError(peMandatoryStandard))
    state.enableFeature(params[0], isOn)
    OK
  ))
  cmds.add(makeCommand(FEATURES_STANDARD, COMMAND_NOOP, uaNone, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    OK
  ))
  cmds.add(makeCommand(FEATURES_STANDARD, COMMAND_STOP, uaNonZero, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    return BAD(params.join(STRINGS_SPACE))
  ))
  cmds.add(makeCommand(FEATURES_STANDARD, COMMAND_DEFER, uaNonZero, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    let prc = params[0]
    if prc == COMMAND_INCLUDE or prc == COMMAND_DEFER:
      return BAD(state.formatError(peUndeferrableCommand, prc))
    return executeCommand(prc, params[1..^1], state, cmds)
  ))
  # INCLUDES
  cmds.add(makeCommand(FEATURES_INCLUDES, COMMAND_INCLUDE, uaOne, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    let fn = params[0]
    if not fileExists(fn):
      return BAD(state.formatError(peInexistentInclude, fn))
    var finc = open(fn, bufSize=8000)
    defer: close(finc)
    state.scheduleForInclusion(readPreprodLines(fn, finc))
    OK
  ))
  # COMMENTS
  cmds.add(makeCommand(FEATURES_COMMENTS, COMMAND_COMMENT, uaNonZero, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    case params[0]:
    of "CHAR":
      if params.len == 1:
        return BAD(state.formatError(peNoPrefix))
      if params[1].len > 1:
        return BAD(state.formatError(pePrefixLength))
      state.setPropertyValue(PREPROD_COMMENT_PREFIX_KEY, params[1])
    else:
      echo params
    OK
  ))
  # CONSOLES
  cmds.add(makeCommand(FEATURES_CONSOLES, COMMAND_INFO, uaAny, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if state.isPreviewing():
      writeLine(stdout, params.join(STRINGS_SPACE))
    OK
  ))
  cmds.add(makeCommand(FEATURES_CONSOLES, COMMAND_DEBUG, uaAny, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if state.isPreviewing():
      writeLine(stderr, params.join(STRINGS_SPACE))
    OK
  ))
  cmds.add(makeCommand(FEATURES_CONSOLES, COMMAND_PRINT, uaAny, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if state.isTranslating():
      writeLine(stdout, params.join(STRINGS_SPACE))
    OK
  ))
  cmds.add(makeCommand(FEATURES_CONSOLES, COMMAND_ERROR, uaAny, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if state.isTranslating():
      writeLine(stderr, params.join(STRINGS_SPACE))
    OK
  ))
  # BRANCHES
  cmds.add(makeCommand(FEATURES_BRANCHES, COMMAND_IFDEF, uaOne, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    state.enterBranch(state.hasConditionalDefine(params[0]))
    OK
  ))
  cmds.add(makeCommand(FEATURES_BRANCHES, COMMAND_IFNDEF, uaOne, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    state.enterBranch(not state.hasConditionalDefine(params[0]))
    OK
  ))
  cmds.add(makeCommand(FEATURES_BRANCHES, COMMAND_ELSE, uaNone, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if not state.inBranch():
      return BAD(state.formatError(peUnexpectedCommand, COMMAND_ELSE))
    state.toggleBranchProcessing()
    OK
  ))
  cmds.add(makeCommand(FEATURES_BRANCHES, COMMAND_ENDIF, uaNone, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if not state.inBranch():
      return BAD(state.formatError(peUnexpectedCommand, COMMAND_ENDIF))
    state.leaveBranch()
    OK
  ))
  cmds.add(makeCommand(FEATURES_BRANCHES, COMMAND_DEF, uaOne, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if state.isCurrentlyProcessable:
      state.addConditionalDefine(params[0])
    OK
  ))
  cmds.add(makeCommand(FEATURES_BRANCHES, COMMAND_UNDEF, uaOne, proc (state: var PreprodState, params: StringSeq): PreprodResult =
    if state.isCurrentlyProcessable:
      state.removeConditionalDefine(params[0])
    OK
  ))
  return cmds
