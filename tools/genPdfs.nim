import std / [strformat, strutils, osproc, os, xmltree, htmlparser, streams]
import parsetoml

type
  POKind = enum
    poNone = "Other"
    po2006 = "PO2006"
    po2014 = "PO2014"

  Degree = enum
    dkBachelor = "bsphysik"
    dkMaster = "msphysik"
    dkAstro = "msastro"
    dkLvAndere = "lvandere"

const Prefix = "../public"

proc toMhbPath(degree: string): string = &"mhb_{degree.toLowerAscii}"

proc determineDegree(data: TomlValueRef, course: string): string =
  # same logic as in hugo, i.e. we take the last one we encounter.
  # In Hugo it's more complicated to change this, since we cannot return early,
  # would need to check if result is assigned.
  for deg in data["Degrees"].getElems:
    for locCourse in data[deg.getStr].getElems:
      if course == locCourse.getStr:
        result = deg.getStr
  result = toMhbPath result

proc toOutpath(name: string, poKind: POKind): string =
  createDir(Prefix & "/pdfs" / $poKind)
  result = Prefix / "pdfs" / $poKind / name.parentDir.extractFilename & ".pdf"

proc toCoursePath(poKind, degree, course: string): string =
  # hugo auto replaces spaces in paths by `-`
  let c = course.replace(" ", "-")
  result = Prefix & "/docs" / poKind & degree / "courses" / c / "index.html"

proc toModulePath(poKind, degree, module: string): string =
  # hugo auto replaces spaces in paths by `-`
  let m = module.replace(" ", "-")
  result = Prefix & "/docs" / poKind & degree / m / "index.html"

proc buildPdf(paths: seq[string], outfile: string) =
  echo "Building PDF for: ", paths
  var xmlData = ""
  for p in paths:
    let tree = loadHtml(p).findAll("article")
    # there's 2 `<article>` tags in each, they are nested
    doAssert tree.len == 2
    # take the outer tag
    xmlData.add $(tree[0])
  # start a pandoc process and feed the xml data
  let cmd = &"pandoc -f html --template mhb_pandoc_template.latex -o {outfile}"
  var pid = startProcess(cmd, options = {poStdErrToStdOut, poEvalCommand})
  let inStream = pid.inputStream
  inStream.write($xmlData)
  inStream.close()
  let sig = pid.waitForExit()
  if sig != 0:
    # in case the command failed print stdout and stderr and quit
    let output = pid.outputStream
    let err = pid.errorStream
    echo output.readAll()
    echo err.readAll()
    output.close()
    err.close()
    pid.close()
    quit("Failed to convert " & $paths)
  pid.close()

proc handleCourse(poKind: POKind, course: string): string =
  let courseMap = parseFile(&"../data/{poKind}_course_map.toml")
  let lookupDeg = courseMap.determineDegree course
  # with course and degree build path
  # something like this:
  # for ponone need to ignore poKind.
  result = toCoursePath($poKind & "/", lookupDeg, course)

proc handleModule(data: TomlValueRef, poKind: POKind, degree, module: string) =
  # read module's courses
  var paths = newSeq[string]()
  # add module path
  paths.add toModulePath($poKind & "/", toMhbPath degree, module)
  for course in data[module]["CourseList"].getElems:
    # read course map
    let path = handleCourse(poKind, course.getStr)
    # build individual course PDF here
    buildPdf(@[path], outfile = path.toOutpath(poKind))
    # and add path to result
    paths.add path
  buildPdf(paths, outfile = paths[0].toOutpath(poKind))

proc handleDegree(poKind: POKind, deg: Degree) =
  # open data file for this degree
  let suffix = if poKind == po2014: $deg & "2" else: $deg
  let data = parseFile(&"../data/mhb_{suffix}.toml")
  for module in data["ModuleList"].getElems:
    data.handleModule(poKind, suffix, module.getStr)

proc handlePO(poKind: POKind) =
  case poKind
  of poNone:
    handleDegree(poNone, dkLvAndere)
  else:
    for deg in Degree:
      if deg == dkLvAndere: continue
      handleDegree(poKind, deg)

for poKind in POKind:
  handlePO(poKind)
