# preprod
a custom old-school preprocessor for nim

## MOTIVATION
> *"If you want more effective programmers, you will discover that they should not waste their time debugging, they should not introduce the bugs to starth with."*
- Edger Dijkstra, The Humble Programmer, 1972

## CHARACTERISTICS

* 16 builtin commands separated into 5 different groups (called features)
* independient feature set enablement
* custom defines and branching logic support
* external file inclusions
* deferred command execution support
* comments support
* custom callbacks for preview and translate passes
* overridable error formatter
* and more

## BUILTIN COMMANDS

### STANDARD feature
* FEATURE command: enables/disables a feature (command group)
* NOOP command: no operation
* STOP command: stops execution with a custom message
* DEFER command: defers the execution of the command specified

### INCLUDES feature
* INCLUDE command: includes an external file into the preprocessed contents

### COMMENTS feature
* COMMENT command: customizes the character used to comment ('#' by default)

### CONSOLES feature
* INFO command: emit text to stdout when previewing
* DEBUG command: emits text to stderr when previewing
* PRINT command: emit text to stdout when translating
* ERROR command: emit text to stderr when translating

### BRANCHES feature
* IFDEF command: open a branch if something is defined
* IFNDEF command: open a branch if something is not defined
* ELSE command: toggles the branch
* ENDIF command: ends the branch
* DEF command: adds a conditional define
* UNDEF command: deletes a conditional define

## AVAILABLE OPTIONS

*allowLeftWhitespace*: enables/disables the acceptance of whitespace before a command (true by default)

*linePrefix*: customizes the line prefix (".$" by default)

*initialCommentPrefix*: sets the initial comment prefix ("#" by default)

*initialEnabledFeatures*: customizes the initial enabled features (all by default)

*initialConditionalDefines*: sets the initial conditional defines (none by default)

*customPrefix*: sets the prefix for custom commands ("." by default)

*keepBlankLines*: establishes if produced blank lines are kept in the output (true by default)

*initialLineAppendix*: sets the initial line appendix (EOL by default)

## USAGE

```nim
    var opt = newPreprodOptions()
    opt.initialConditionalDefines = @["x"]
    let p = newPreprodPreprocessor(@[
      ".$ IFDEF x",
      "x!",
      ".$ ELSE",
      "no x!",
      ".$ ENDIF"
    ], opt)
    let r = p.run()
    if r.ok:
      echo r.output # "x!"
```

## RELATED

You may also want to check my other nimlang projects:

* [`xam`](https://github.com/j-a-s-d/xam), my multipurpose productivity library for nim
* [`rodster`](https://github.com/j-a-s-d/rodster), my application framework for nim
* [`webrod`](https://github.com/j-a-s-d/webrod), my http server for nim

## HISTORY

* 13-05-22 *[1.1.1]*
  - added newPreprodOptions to exports
  - general improvements
* 12-05-22 *[1.1.0]*
  - added overridable error formatter to allow message customization
  - added PreprodFormatter, PreprodError and PREPROD_ERROR_FORMATS to exports
  - updated xam dependency to 1.8.0
* 09-02-22 *[1.0.2]*
  - added registerFeature, hasFeature, enableFeature and isFeatureEnabled to exports
  - added constructors overloads
* 08-02-22 *[1.0.1]*
  - added hasConditionalDefine, addConditionalDefine, removeConditionalDefine to exports
  - updated xam dependency to 1.7.0
* 28-12-21 *[1.0.0]*
  - first public release
* 08-12-21 *[0.0.1]*
  - started coding
