# preprod / LINES #
#-----------------#

import
  xam,
  header

func makePreprodLine(origin: string, number: int, text: string): PreprodLine =
  (
    number: number,
    length: text.len,
    raw: text,
    origin: origin & STRINGS_COLON & $number
  )

proc composePreprodLines*(source: string, text: StringSeq): PreprodLines =
  var x: int = 0
  text.each line:
    inc x
    result.add(makePreprodLine(source, x, line))

proc readPreprodLines*(source: string, file: File): PreprodLines =
  var x: int = 0
  var line = newStringOfCap(80)
  while file.readLine(line):
    inc x
    result.add(makePreprodLine(source, x, line))

func renumberPreprodLine(line: PreprodLine, number: int): PreprodLine =
  (
    number: number,
    length: line.length,
    raw: line.raw,
    origin: line.origin
  )

func includePreprodLines*(original: PreprodLines, inclusion: PreprodLines, atLine: int, replaceLineWithInclusion: bool = true): PreprodLines =
  original.each oline:
    if oline.number == atLine:
      inclusion.each iline:
        result.add(renumberPreprodLine(iline, result.len + 1))
      if replaceLineWithInclusion:
        continue
    result.add(renumberPreprodLine(oline, result.len + 1))
