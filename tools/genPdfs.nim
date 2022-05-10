import std / [strformat, strutils, osproc, os, xmltree, htmlparser, streams]
import parsetoml

type
  POKind = enum
    poNone = "other"
    po2006 = "po2006"
    po2014 = "po2014"

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

proc buildPdfs(paths: seq[string]) =
  ## Executes the pandoc commands in parallel using `execProcesses`. The input
  ## files are generated in our case beforehand (but normally will probably
  ## exist). If one or more processes returns an error code > 0, we quit. In
  ## a production environment we should of course handle that in the appropriate
  ## manner instead.
  let res = execProcesses(paths)
  if res != 0:
    quit("Couldn't convert something... (don't quit me..)")

proc genCommands(paths: seq[string], outfile: string): string =
  ## writes out the XML data as "input files" and returns the full pandoc commands
  ## needed to run the conversion. As such we can then call multiple pandoc processes
  ## to do the job for us.
  echo "Building XML file & pandoc command for : ", paths
  var xmlData = ""
  for p in paths:
    let tree = loadHtml(p).findAll("article")
    # there's 2 `<article>` tags in each, they are nested
    doAssert tree.len == 2
    # take the outer tag
    xmlData.add $(tree[0])
  # start a pandoc process and feed the xml data
  let infile = &"/tmp/{outfile.extractFilename}.xml"
  writeFile(infile, $xmlData)
  let cmd = &"pandoc -s {infile} -f html --template mhb_pandoc_template.latex -o {outfile}"
  result = cmd

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
  var commands = newSeq[string]()
  for course in data[module]["CourseList"].getElems:
    # read course map
    let path = handleCourse(poKind, course.getStr)
    # build the commands to generate the outputs
    commands.add genCommands(@[path], outfile = path.toOutpath(poKind))
    # and add path to result
    paths.add path
  echo "Building the commands: ", commands.len
  # now using the commands call `execProcesses` to run them in parallel
  buildPdfs(commands)
  ## TODO: to properly multithread this tool, we'd have to also take care of the
  ## modules themselves, but that's an irrelevant detail for the PoC.

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
