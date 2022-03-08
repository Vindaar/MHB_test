# stdlib
import std / [db_mysql, strutils, os, sequtils, tables, macros, strformat, sets]
# local modules
import multiLang, commonReadOps, sql_utils
# nimble packages
import datamancer, parsetoml, cligen

type
  POKind = enum
    PONone = "other"
    PO2006 = "po2006"
    PO2014 = "po2014"

  ElementKind = enum
    ekModule = "module"
    ekCourse = "course"

proc sanitize*[T: SomeLanguageEnum](s: string, em: T): string =
  ## This cleans up the string data from the input by performing
  ## some replacements to make the result suitable for TOML files
  # this is fucking confusing
  when T is CourseFieldKind:
    if em == cfTitle:
      s.multiReplace([("\r", " "), ("\n", " "), ("\"", r"""\"""")]).replace("\\\\","\\")
    else:
      s.multiReplace([("\r", "\n"), ("\"", r"""\"""")]).replace("\\\\","\\")
  else:
    s.multiReplace([("\r", "\n"), ("\"", r"""\"""")]).replace("\\\\","\\")

proc createDirAndWrite(prefix, name, degree: string, kind: ElementKind, weight: string,
                       poKind: POKind,
                       parents: seq[string] = @[], toCollapse = true) =
  let path = if kind == ekCourse: "courses/" else: ""
  let fname = path / name.replace("/", "_") & ".md"
  echo "Create ", prefix / path
  createDir(prefix / path)
  let degree = degree.toLowerAscii
  let shortcode = if kind == ekModule: "{{< genModulePage >}}"
                  else: "{{< genCoursePage >}}"
  let pTags = concat(@[degree, name], parents)
  let tagsParent = if parents.len > 0:
               &"parents = {(? parents).toTomlString()}\ntags = {(? pTags).toTomlString()}"
             else:
               &"tags = {(? pTags).toTomlString()}"
  let data = &"""
+++
weight = {weight}
pokind = "{poKind}"
title = "{name}"
degree = "{degree}"
{tagsParent}
categories = ["{kind}"]
bookCollapseSection = {toCollapse}
+++

{shortcode}
"""
  writeFile(prefix / fname, data)

macro enumNames(enm: typed): untyped =
  ## Walks over the given `enum` and yields all fields and their names as strings
  ## without using the actual string values of the fields (which we don't need in the
  ## used context, else we'd use the `fields` iterator)
  let typ = enm.getImpl[2]
  result = nnkBracket.newTree()
  for i in 1 ..< typ.len:
    result.add nnkPar.newTree(newLit typ[i][0].strVal, typ[i][0])

proc toToml(lang: LanguageMap, degree: string): TomlValueRef =
  ## Converts the given `LanguageMap` to a TOML table
  result = newTTable()
  result["Degree"] = ? degree
  var modFields = newTTable()
  for (a, mf) in enumNames(ModuleFieldKind):
    modFields[a] = ? (lang[mf])
  result["ModuleFields"] = modFields
  var courseFields = newTTable()
  for (a, cf) in enumNames(CourseFieldKind):
    courseFields[a] = ? (lang[cf])
  result["CourseFields"] = courseFields

proc excludedCourses(): HashSet[string] =
  ## returns a list of explicitly excluded courses for the TOML output.
  ## This is mainly for modules which are placeholders for other modules,
  ## i.e. `astro84*`, `astro121-123` etc.
  result = initHashSet[string]()
  const courses = ["", "astro84*", "astro85*", "astro121-123", "see catalogue", "siehe Liste",
                   "siehe umseitige Liste", "t.b.a."]
  for c in courses:
    result.incl c

proc replaceCourses(df: DataFrame, modIndex: int, modNum: string): DataFrame =
  ## Helper that "replaces" certain courses from the database by their equivalent
  ## data. This is used for 2 specific cases, in which the old module handbook
  ## only refers to a PDF that is included in the generated PDF.
  ## Instead we simply add the data that is written in the PDF to a DF.
  ##
  ## Note: If there were more cases than this, instead of doing this in a hard
  ## coded fashion, we should of course just read some CSV, ... file from which
  ## to construct the DF. Given the few well defined cases, this is fine.

  # note: the two courses are fundamentally different
  # the physik120 case adds ``new courses`` to the course DF, which need to be
  # added both to the module as courses as well as as a full course
  # the physik450 case accesses ``existing`` courses from a ``different`` degree
  # and adds them as courses to the module. The full courses are just accessed from
  # the module
  # Especially for the latter case this means: We ``only`` have to add the desired
  # courses to the `CourseList` field of the module. That way everything else will
  # work automatically (once we fix the module / course relationship to not have
  # ownership anymore). Also need a LUT for course ⇒ degree to build the correct path
  # to access the data for a specific course.
  result = newDataFrame()
  const replaceCourses = ["siehe Liste", "siehe umseitige Liste"]
  case modNum
  of "physik120":
    ## need to differentiate different degrees?
    ## add all courses manually
    # Astro: already in DF, just have to add it to this DF as course
    # Informatik
    result.add (
      modID: modIndex,
      Modulteilnr: "informatik001",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Informationssysteme (Informatik)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_000
    )
    result.add (
      modID: modIndex,
      Modulteilnr: "informatik002",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Technische Informatik (Informatik)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_001
     )
    result.add (
      modID: modIndex,
      Modulteilnr: "informatik003",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Algorithmisches Denken und imperatives Programmieren (Informatik)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_002
     )
    # Meteorologie
    result.add (
      modID: modIndex,
      Modulteilnr: "meteorologie001",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Einführung in die Meteorologie 1 (Meteorologie)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_003
     )
    result.add (
      modID: modIndex,
      Modulteilnr: "meteorologie002",
      Lehrsprache: "deutsch",
      Semester: "SS",
      Titel: "Einführung in die Meteorologie 2 (Meteorologie)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_004
     )
    # Chemie
    result.add (
      modID: modIndex,
      Modulteilnr: "chemie001",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Experimentelle Einführung in die Anorganische und Allgemeine Chemie (Chemie)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_005
     )
    # VWL
    result.add (
      modID: modIndex,
      Modulteilnr: "vwl001",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Grundzüge der VWL: Einführung in die Mikroökonomik (Volkswirtschaftslehre)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_006
     )
    result.add (
      modID: modIndex,
      Modulteilnr: "vwl002",
      Lehrsprache: "deutsch",
      Semester: "SS",
      Titel: "Grundzüge der VWL: Einführung in die Makroökonomik (Volkswirtschaftslehre)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_007
     )
    # BWL
    result.add (
      modID: modIndex,
      Modulteilnr: "bwl001",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Grundzüge der BWL: Einführung in die Theorie der Unternehmung (Betriebswirtschaftslehre)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_008
     )
    result.add (
      modID: modIndex,
      Modulteilnr: "bwl002",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Grundzüge der BWL: Investition und Finanzierung (Betriebswirtschaftslehre)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_009
     )
    # Philosophie
    result.add (
      modID: modIndex,
      Modulteilnr: "philosophie001",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Logik und Grundlagen ZF (Philosophie)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_010
     )
    result.add (
      modID: modIndex,
      Modulteilnr: "philosophie002",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Erkenntnistheorie ZF (Philosophie)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_011
     )
    result.add (
      modID: modIndex,
      Modulteilnr: "philosophie003",
      Lehrsprache: "deutsch",
      Semester: "WS",
      Titel: "Wissenschaftsphilosophie ZF (Philosophie)",
      Artkurz: "Vorl. + Üb.",
      Prfmodalitaeten: "Die aufgeführte LV-Nr. für diesen Kurs entspricht nicht der entsprechenden Nummer im " &
        "Modulhandbuch des entsprechenden Studiengangs!",
      Reihenfolge: 100_012
     )
    result.len = 13
    for key in df.getKeys():
      if key notin result:
        result[key] = constantColumn("", result.len)
  of "physik450":
    ## NOTE: this is handled separately now, due to the comment mentioned at the top
    discard
  else: discard

proc getPhysik450Courses(degree: string): seq[string] =
  ## These are all courses that can be take as a valid master module in the bachelor
  ## module 450.
  result = @["physics611","physics612","physics613",
             # NOTE: physics 614 does not exist? "physics614",
             # UPDATE: has `bis` == 28 in `modulteile` hence does not exist anymore!
             "physics615",
             "physics616","physics617","physics618","physics620",
             # same with "physics631", and "physics640",
             "physics632","physics633","physics634","physics606",
             "physics751","physics754","physics755"]
  if degree == "MSASTRO2":
    ## did not exist in PO2006 apparently!
    result.add "astro608"
  result.add ["astro811","astro812","astro821","astro822"]

proc writeTomlFiles(prefix, degree: string,
                    tmodules, tcourses: OrderedTable[string, TomlValueRef],
                    langMap: LanguageMap,
                    modules, courses: seq[string]) =
  ## Writes the generated tables as TOML files
  proc writeFile(fname: string,
                 tab: OrderedTable[string, TomlValueRef],
                 key: string, elems: seq[string]) =
    var f = open(fname, fmWrite)
    f.write(&"{key} = {(? elems).toTomlString}\n")
    for key, tomlTab in pairs(tab):
      var tabToWrite = newTTable()
      tabToWrite[key] = tomlTab
      f.write(tabToWrite.toTomlString() & "\n")
  writeFile(&"{prefix}.toml", tmodules, "ModuleList", modules)
  writeFile(&"{prefix}_courses.toml", tcourses, "CourseList", courses)
  writeFile(&"{prefix}_langmap.toml", langMap.toToml(degree).toTomlString())

proc genMhb(db: DBConn,
            df1, df2: DataFrame,
            degree: string,
            outname: string,
            poKind: POKind,
            lang: LanguageKind): DataFrame =
  ## Generate the following layout
  ## - PO2006
  ##   - BSPYSIK
  ##     - physik110, ... # all modules
  ##     - courses
  ##       - physik111, ... # all courses for this degree
  ##   - MSPHYSIK
  ##     - ...
  ##   - MSASTRO
  ##     - ...
  ##   - courseList.toml # mapping course name + num to degree to look up path
  ## - PO2014
  ##   - same as PO2006
  ## - Andere Lehrveranstaltungen
  ##   - each course
  # get a mutable copy of input `df2`
  var df2 = df2
  # get the correct language map and update with given input data
  var langMap = initNewLanguageMap(lang)
  langMap.updateLanguageMap(db.tableToDf("bezeichner")
    .filter(fn {string -> bool: `Studiengang` == degree}))
  # output prefix based on POKind & given input
  let prefix = &"/tmp/{poKind}/{outname}"
  # generate the directory for this degree
  genMhbDirectory(prefix, df1.get(0, mfDegreeLong), degree)
  # get the courses we explicitly exclude
  let excludeSet = excludedCourses()
  # 1. construct the table for all ``modules``
  var tmodules = initOrderedTable[string, TomlValueRef]()
  var modules: seq[string]
  for i in 0 ..< df1.len:
    var tmod = newTTable()
    for (a, mf) in enumNames(ModuleFieldKind):
      # not all fields are available in each case. Hence the ugly `try/except`
      try:
        if mf != mfOrder:
          tmod[a] = ? (df1.get(i, mf)).strip
        else:
          tmod[a] = ? (df1[$mf, float][i])
      except KeyError:
        echo "Key not found ", mf
    let curModID = df1["modID", int][i]

    ## NOTE: using the following excludes those courses, which in the PHP version
    ## only show up as course pages, but not in the table of the module. See:
    ## https://web3.physik.uni-bonn.de/mhb/mhb.php?stg=MSPHYSIK2&modulcomp=physics70d
    ## Has "one" course "see catalogue" but still pages of the courses after
    var courses: seq[string]
    var modNum = df1.get(i, mfNum)
    if modNum.len == 0:
      modNum = df1.get(i, mfTitle)
    ## TODO: either filter dummy or just check module name > 0?
    doAssert modNum.len > 0
    createDirAndWrite(prefix, modNum, degree, ekModule,
                      weight = df1.get(i, mfOrder), poKind = poKind)

    # if looking at `physik120` add the needed data
    if modNum == "physik120":
      let toAdd = replaceCourses(df2, curModID, modNum)
      df2.add toAdd
    modules.add modNum
    let courseNumField = $cfNum
    # filter to all matching courses that are not excluded. Remove duplicates & sort
    let courseDf = df2.filter(fn {int: `modID` == curModID},
                              fn {string: `Modulteilnr` notin excludeSet})
      .unique($cfNum)
      .arrange("Reihenfolge")
    if modNum == "physik450": # if `physik450` add the possible courses
      tmod["CourseList"] = ? concat(courseDf[$cfNum, string].toRawSeq,
                                    getPhysik450Courses(degree))
    else:
      ## TODO: remove duplicates :/
      tmod["CourseList"] = ? courseDf[$cfNum, string].toRawSeq
    tmodules[modNum] = tmod

  # sort resulting `df2`
  df2 = df2.arrange($cfOrder)
  # 2. construct the table for all ``courses``
  var tcourses = initOrderedTable[string, TomlValueRef]()
  var courses: seq[string]
  for i in 0 ..< df2.len:
    var tcourse = newTTable()
    for (a, cf) in enumNames(CourseFieldKind):
      try: # not all course fields available everywhere, hence `try/except`
        if cf != cfOrder:
          tcourse[a] = ? (df2.get(i, cf)).strip
        else:
          tcourse[a] = ? (df2[$cf, float][i])
      except KeyError:
        echo "Key not found ", cf
    var courseNum = df2.get(i, cfNum)
    if courseNum in excludeSet:
      echo "Skipping : ", courseNum
      continue # skip this 'course'

    if courseNum.len == 0:
      courseNum = df2.get(i, cfTitle)

    let curModID = df2["modID", int][i]
    let parentDf = df1.filter(fn {int: `modID` == curModID})
      .arrange("Reihenfolge")
    # if first time course appears, create directory with `index` file. Only use
    # first appearance, as there are duplicate courses (`lastchanged`, `modteilID` and `zuordID`
    # are different. We use the last one (due to `arrange`)
    if courseNum notin tcourses:
      createDirAndWrite(prefix, courseNum, degree, ekCourse,
                        weight = df2.get(i, cfOrder), poKind = poKind,
                        parents = parentDf[$mfNum, string].toRawSeq, toCollapse = false)
      tcourses[courseNum] = tcourse
      courses.add courseNum
  # write the generated tables to TOML files
  writeTomlFiles(prefix, degree, tmodules, tcourses, langMap, modules, courses)
  result = seqsToDf({"courses" : courses})
  result["degree"] = constantColumn(degree, result.len)

proc buildModuleHandbook(db: DBConn, std: string): DataFrame =
  let lang = block:
    var res: LanguageKind
    case std
    of "BSPHYSIK", "BSPHYSIK2", "LVANDERE", "LABPHYSIK": res = lkGerman
    of "MSPHYSIK", "MSPHYSIK2", "MSASTRO", "MSASTRO2": res = lkEnglish
    else: doAssert false, "Invalid degree! " & $std
    res
  let poKind = if std.endsWith("2"): PO2014
               elif std == "LVANDERE": PONone
               else: PO2006
  let dfHeader = db.getModules(std)
  let dfParts = db.getCourses(dfHeader)
  result = db.genMhb(dfHeader, dfParts, std, &"mhb_{std.normalize}", poKind, lang)

proc writeGlobalCourseList(poKind: POKind, df: DataFrame,
                           showDataframes: bool) =
  ## Generates the `*_course_map.toml` files that map the courses to the
  ## modules for reference in Hugo
  var f = open("/tmp/" & $poKind & "_course_map.toml", fmWrite)
  let degrees = df.clone.unique("degree")["degree", string].toRawSeq
  f.write(&"Degrees = {(? degrees).toTomlString}\n")
  if showDataframes: # show the DF in the browser
    df.showBrowser(&"df_{poKind}.html")
  for (tup, subDf) in groups(df.group_by("degree")):
    let deg = tup[0][1].toStr
    var tab = newTTable()
    let courses = subDf["courses", string]
    if showDataframes: # show the sub DF in the browser
      subDf.showBrowser(&"df_{deg}.html")
      sleep(200)
    tab[deg] = ? (courses.clone.toRawSeq)
    f.write(tab.toTomlString() & "\n")
  f.close()

proc main(host = "localhost",
          user = "root",
          password = "",
          mhbTable = "modulhandbuch",
          showDataframes = false) =
  let db = open(host, user, password, mhbTable)

  # PO2006
  var df2006 = db.buildModuleHandbook("BSPHYSIK")
  df2006.add db.buildModuleHandbook("MSPHYSIK")
  df2006.add db.buildModuleHandbook("MSASTRO")
  # PO2014
  var df2014 = db.buildModuleHandbook("BSPHYSIK2")
  df2014.add db.buildModuleHandbook("MSPHYSIK2")
  df2014.add db.buildModuleHandbook("MSASTRO2")
  # other
  var dfOther = db.buildModuleHandbook("LVANDERE")

  writeGlobalCourseList(PO2006, df2006, showDataframes = showDataframes)
  writeGlobalCourseList(PO2014, df2014, showDataframes = showDataframes)
  writeGlobalCourseList(PONone, dfOther, showDataframes = showDataframes)

  db.close()

when isMainModule:
  dispatch main
