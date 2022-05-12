# preprod / STATE #
#-----------------#

import
  strtabs,
  xam,
  header, lines

use strutils,split

func backupProperties*(state: PreprodState): StringTableRef =
  result = newStringTable()
  for k, v in state.properties:
    result[k] = v

func restoreProperties*(state: var PreprodState, original: StringTableRef) =
  clear(state.properties, modeCaseSensitive)
  for k, v in original:
    state.properties[k] = v

func nextPhase*(state: var PreprodState): bool =
  case state.phase:
  of upInvalid:
    return false
  of upUnprocessed:
    state.phase = upPrefetchInclusions
    return true
  of upPrefetchInclusions:
    state.phase = upPreviewContent
    return true
  of upPreviewContent:
    state.phase = upTranslateContent
    return true
  of upTranslateContent:
    state.phase = upProcessDeferred
    return true
  of upProcessDeferred:
    state.phase = upProcessed
    return false
  of upProcessed:
    return false

func setContent*(state: var PreprodState, lines: PreprodLines) =
  state.content = lines
  state.phase = upUnprocessed

func addConditionalDefine*(state: var PreprodState, define: string) =
  state.defines.add(define)

func removeConditionalDefine*(state: var PreprodState, define: string) =
  state.defines.remove(define)

func hasConditionalDefine*(state: PreprodState, define: string): bool =
  state.defines.find(define) > -1

func mergeInclusionsIntoContent*(state: var PreprodState) =
  var tmp = state.content
  state.inclusions.each inclusion:
    tmp = includePreprodLines(tmp, inclusion.lines, inclusion.at)
  state.inclusions.clear()
  state.setContent(tmp)

func hasInclusionsToMerge*(state: PreprodState): bool =
  state.inclusions.len > 0

func scheduleForInclusion*(state: var PreprodState, lines: PreprodLines) =
  state.inclusions.add((at: state.line.number, lines: lines))

func removePropertyValue*(state: var PreprodState, key: string) =
  state.properties.del(key)

func getPropertyValue*(state: PreprodState, key: string): string =
  state.properties[key]

func setPropertyValue*(state: var PreprodState, key: string, value: string) =
  state.properties[key] = value

func hasPropertyValue*(state: PreprodState, key: string): bool =
  state.properties.hasKey(key)

func appendPropertyValueAsSequence*(state: var PreprodState, key: string, value: string) =
  state.setPropertyValue(key, if state.hasPropertyValue(key):
    state.getPropertyValue(key) & STRINGS_EOL & value
  else:
    value
  )

func retrievePropertyValueAsSequence*(state: PreprodState, key: string): StringSeq =
  state.getPropertyValue(key).split(STRINGS_EOL)

func isFeatureEnabled*(state: PreprodState, name: string): bool =
  state.features.each uf:
    if uf.name == name:
      return uf.enabled

func enableFeature*(state: var PreprodState, name: string, value: bool) =
  state.features.meach uf:
    if uf.name == name:
      uf.enabled = value
      break

func hasFeature*(state: PreprodState, name: string): bool =
  result = false
  state.features.each uf:
    if uf.name == name:
      return true

func registerFeature*(state: var PreprodState, name: string, commands: StringSeq, enabled: bool = true) =
  state.features.add((enabled: enabled, name: name, commands: commands))

func enterBranch*(state: var PreprodState, process: bool) =
  var branch: PreprodBranch
  branch.last = state.line.origin
  branch.process = process
  state.branches.push(branch)

func toggleBranchProcessing*(state: var PreprodState) =
  if state.branches.len > 0:
    var branch: PreprodBranch = state.branches.pop()
    branch.process = not branch.process
    state.branches.push(branch)

func leaveBranch*(state: var PreprodState) =
  if state.branches.len > 0:
    discard state.branches.pop()

func inBranch*(state: PreprodState): bool =
  state.branches.len > 0

func isBranchProcessing*(state: var PreprodState): bool =
  state.branches.peek(DUMMY_BRANCH).process

func getLastBranchLocation*(state: var PreprodState): string =
  state.branches.peek(DUMMY_BRANCH).last

func isCurrentlyProcessable*(state: var PreprodState): bool =
  not (state.inBranch() and not state.isBranchProcessing())

func isPreviewing*(state: PreprodState): bool =
  state.phase == upPreviewContent

func isTranslating*(state: PreprodState): bool =
  state.phase == upTranslateContent

func formatError*(state: PreprodState, code: PreprodError, argument: string = STRINGS_EMPTY): string =
  state.formatter(code, argument)

func setupPreprodState*(defines: StringSeq = newStringSeq(), formatter: PreprodFormatter = DEFAULT_FORMATTER): PreprodState =
  result.phase = upInvalid
  result.executions = 0
  result.properties = newStringTable()
  result.defines = defines
  result.formatter = formatter
  result.tag = nil
