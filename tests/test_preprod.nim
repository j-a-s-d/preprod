# preprod by Javier Santo Domingo (j-a-s-d@coderesearchlabs.com)

import
  unittest,
  strutils,
  xam, preprod

suite "test preprod":

  let COMMENTS1 = @[
    ".$ NOOP # this is a comment after a command",
    ".# this is a preprocessor comment line",
    ".$ COMMENT CHAR %",
    ".% now this is a preprocessor comment line"
  ]

  let BRANCHES1 = @[
    ".$ IFDEF x",
    "x!",
    ".$ ELSE",
    "no x!",
    ".$ ENDIF"
  ]

  let BRANCHES2 = @[
    ".$ DEF x",
    ".$ IFDEF x",
    "x!",
    ".$ ELSE",
    "no x!",
    ".$ ENDIF",
    ".$ UNDEF x",
    ".$ IFNDEF x",
    "no x!",
    ".$ ELSE",
    "x!",
    ".$ ENDIF"
  ]

  test "test assigned":
    #
    check(assigned(newPreprodPreprocessor("")))
    #
    check(assigned(newPreprodPreprocessor(@[""])))

  test "test empty inlined":
    #
    let ipr = newPreprodPreprocessor(@[""])
    let irr = ipr.run()
    check(ipr.state.executions == 0)
    check(irr.ok)
    check(not hasText(irr.output))

  test "test STANDARD NOOP command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ NOOP"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 2)
    check(rr0.ok)
    check(not hasText(rr0.output))
    #
    let pr1 = newPreprodPreprocessor(@[".$ NOOP invalid"])
    let rr1 = pr1.run()
    check(pr1.state.executions == 0)
    check(not rr1.ok)
    check(hasText(rr1.output))

  test "test inexistent file":
    #
    let pr = newPreprodPreprocessor("")
    let rr = pr.run()
    check(pr.state.executions == 0)
    check(not rr.ok)
    check(hasText(rr.output))

  test "test existent file with NOOP inside":
    #
    let pr = newPreprodPreprocessor("noop_file.preprod")
    let rr = pr.run()
    check(pr.state.executions == 2)
    check(rr.ok)
    check(not hasText(rr.output))

  test "test STANDARD FEATURE command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ FEATURE INCLUDES off"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 1)
    check(rr0.ok)
    check(not hasText(rr0.output))
    #
    let pr1 = newPreprodPreprocessor(@[".$ FEATURE STANDARD off"])
    let rr1 = pr1.run()
    check(pr1.state.executions == 1)
    check(not rr1.ok)
    check(rr1.output == "(<inline>:1) the STANDARD feature commands can not be disabled")
    #
    let pr2 = newPreprodPreprocessor(@[".$ FEATURE INCLUDES false"])
    let rr2 = pr2.run()
    check(pr2.state.executions == 1)
    check(not rr2.ok)
    check(rr2.output == "(<inline>:1) only on/off values are valid")
    #
    let pr3 = newPreprodPreprocessor(@[".$ FEATURE INCLUDES"])
    let rr3 = pr3.run()
    check(pr3.state.executions == 0)
    check(not rr3.ok)
    check(rr3.output == "(<inline>:1) arguments expected: 2")

  test "test STANDARD STOP command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ STOP"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 0)
    check(not rr0.ok)
    check(rr0.output == "(<inline>:1) no arguments supplied")
    #
    let pr1 = newPreprodPreprocessor(@[".$ STOP custom user message", ".$ NOOP"])
    let rr1 = pr1.run()
    check(pr1.state.executions == 1)
    check(not rr1.ok)
    check(rr1.output == "(<inline>:1) custom user message")

  test "test STANDARD DEFER command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ DEFER"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 0)
    check(not rr0.ok)
    check(rr0.output == "(<inline>:1) no arguments supplied")
    #
    let pr1 = newPreprodPreprocessor(@[".$ DEFER STOP custom user message", ".$ NOOP"])
    let rr1 = pr1.run()
    check(pr1.state.executions == 4)
    check(not rr1.ok)
    check(rr1.output == "(<inline>:1) custom user message")

  test "test INCLUDES INCLUDE command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ INCLUDE"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 0)
    check(not rr0.ok)
    check(rr0.output == "(<inline>:1) arguments expected: 1")
    #
    let pr1 = newPreprodPreprocessor(@[".$ INCLUDE inexistent.file"])
    let rr1 = pr1.run()
    check(pr1.state.executions == 1)
    check(not rr1.ok)
    check(rr1.output == "(<inline>:1) the included file 'inexistent.file' does not exist")
    #
    let pr2 = newPreprodPreprocessor(@[".$ INCLUDE stop_file.preprod", ".$ NOOP"])
    let rr2 = pr2.run()
    check(pr2.state.executions == 2)
    check(not rr2.ok)
    check(rr2.output == "(stop_file.preprod:1) stop call from included file")

  test "test COMMENTS COMMENT command":
    #
    let pr0 = newPreprodPreprocessor(COMMENTS1)
    let rr0 = pr0.run()
    check(pr0.state.executions == 4)
    check(rr0.ok)
    check(not hasText(rr0.output))
    #
    let pr1 = newPreprodPreprocessor(@[".$ COMMENT"])
    let rr1 = pr1.run()
    check(pr1.state.executions == 0)
    check(not rr1.ok)
    check(rr1.output == "(<inline>:1) no arguments supplied")
    #
    let pr2 = newPreprodPreprocessor(@[".$ COMMENT CHAR"])
    let rr2 = pr2.run()
    check(pr2.state.executions == 1)
    check(not rr2.ok)
    check(rr2.output == "(<inline>:1) no comment prefix supplied")

  test "test CONSOLES INFO command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ INFO emit text to stdout when previewing"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 2)
    check(rr0.ok)
    check(not hasText(rr0.output))

  test "test CONSOLES DEBUG command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ DEBUG emit text to stderr when previewing"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 2)
    check(rr0.ok)
    check(not hasText(rr0.output))

  test "test CONSOLES PRINT command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ PRINT emit text to stdout when translating"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 2)
    check(rr0.ok)
    check(not hasText(rr0.output))

  test "test CONSOLES ERROR command":
    #
    let pr0 = newPreprodPreprocessor(@[".$ ERROR emit text to stderr when translating"])
    let rr0 = pr0.run()
    check(pr0.state.executions == 2)
    check(rr0.ok)
    check(not hasText(rr0.output))

  test "test BRANCHES IFDEF/IFNDEF/ELSE/ENDIF/DEF/UNDEF commands":
    #
    let pr0 = newPreprodPreprocessor(BRANCHES1)
    let rr0 = pr0.run()
    check(pr0.state.executions == 6)
    check(rr0.ok)
    check(rr0.output.strip() == "no x!")
    #
    let pr1 = newPreprodPreprocessor(BRANCHES2)
    let rr1 = pr1.run()
    check(pr1.state.executions == 16)
    check(rr1.ok)
    check(rr1.output == STRINGS_EOL & STRINGS_EOL & "x!" & STRINGS_EOL & STRINGS_EOL & "no x!" & STRINGS_EOL & STRINGS_EOL)

  test "test output options":
    #
    var opt = PREPROD_DEFAULT_OPTIONS
    opt.keepBlankLines = false
    let pr0 = newPreprodPreprocessor(BRANCHES2, options = opt)
    let rr0 = pr0.run()
    check(pr0.state.executions == 16)
    check(rr0.ok)
    check(rr0.output == "x!" & STRINGS_EOL & "no x!" & STRINGS_EOL)
    #
    opt.initialLineAppendix = "~~"
    let pr1 = newPreprodPreprocessor(BRANCHES2, options = opt)
    let rr1 = pr1.run()
    check(pr1.state.executions == 16)
    check(rr1.ok)
    check(rr1.output == "x!~~no x!~~")

  test "test input options":
    var opt = PREPROD_DEFAULT_OPTIONS
    #
    opt.initialConditionalDefines = @["x"]
    let p = newPreprodPreprocessor(BRANCHES1, options = opt)
    let r = p.run()
    check(p.state.executions == 6)
    check(r.ok)
    check(r.output.strip() == "x!")
    #
    opt.allowLeftWhitespace = false
    let pr = newPreprodPreprocessor(@["        .$ NOOP # this line is not recognized as a valid preprocessor line"], options = opt)
    let rr = pr.run()
    check(pr.state.executions == 0)
    check(rr.ok)
    check(rr.output == "        .$ NOOP # this line is not recognized as a valid preprocessor line" & STRINGS_EOL)
    #
    opt.initialCommentPrefix = "!"
    let pr0 = newPreprodPreprocessor(@[".$ ! blah blah blah"], options = opt)
    let rr0 = pr0.run()
    check(pr0.state.executions == 0)
    check(rr0.ok)
    check(rr0.output == STRINGS_EOL)
    #
    opt.linePrefix = "~|~"
    let pr1 = newPreprodPreprocessor(@["~|~ NOOP"], options = opt)
    let rr1 = pr1.run()
    check(pr1.state.executions == 2)
    check(rr1.ok)
    check(rr1.output == STRINGS_EOL)
    #
    opt.customPrefix = "_"
    let pr2 = newPreprodPreprocessor(@["_unknownCustomCommand"], options = opt)
    let rr2 = pr2.run()
    check(pr2.state.executions == 0)
    check(not rr2.ok)
    check(rr2.output == "(<inline>:1) command 'unknownCustomCommand' is unknown")
    #
    opt.initialEnabledFeatures.remove("COMMENTS")
    let pr3 = newPreprodPreprocessor(@["~|~ COMMENT CHAR %"], options = opt)
    let rr3 = pr3.run()
    check(pr3.state.executions == 0)
    check(not rr3.ok)
    check(rr3.output == "(<inline>:1) command 'COMMENT' belongs to a disabled feature")
