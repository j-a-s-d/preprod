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

## USAGE

```nim
    var opt = PREPROD_DEFAULT_OPTIONS
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

* 28-12-21 *[1.0.0]*
	- first public release
* 08-12-21 *[0.0.1]*
	- started coding
