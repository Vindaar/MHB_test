import datamancer, strutils

type
  LanguageKind* = enum
    lkGerman = "german"
    lkEnglish = "english"

  ## Note on notation used in this file:
  ## everything referred to in the old PHP code as:
  ## - `Modul` -> `module`
  ## - `Modulteil` -> `course`

  # given that our fields won't update usually, we can make use
  # of an enum with string values and then use an
  # `array[LangFieldKind, string]`
  # for the fields of the `LanguageMap` defined below. The nice
  # thing by doing that is:
  # - we don't have a hash table, which can contain more elements
  #   than we might have fields for
  # - we get compile time checks for access of the different fields
  ## NOTE: there are course related bits of information in the "Module" mapping /
  ## table, hence the `mfCourse*` fields!
  ## The values of the enum fields for all enums below corresponds to the column
  ## in the database under which their values are stored!
  ModuleFieldKind* = enum
    mfDegree = "Studiengang", # B.Sc. Physik 06/14, M.Sc. Physik 06/14, Astro...
    mfDegreeLong = "Studienganglang",
    mfTitle = "Titel", # name of module
    mfNum = "Modulnr", # number of module
    mfModules = "Titelmehrfach", # ???
    mfCP = "ModulLP", # credit points of whole module
    mfCategory = "Pflichtkz",
    mfSemester = "Semester",
    mfParts = "Modulbestandteile"
    mfCourseTitle = "LV Titel"
    mfCourseNum = "LV Nr"
    mfCourseKind = "LV-Art"
    mfCourseLP = "LP"
    mfTotalWorkload = "Aufwand"
    mfCourseSemester = "Sem"
    mfRequirements = "Voraussetzungen"
    mfPreparation = "Vorkenntnisse"
    mfContent = "Inhalt"
    mfGoals = "Lernziele"
    mfFormalities = "Prfmodalitaeten"
    mfLength = "Dauer"
    mfParticipants = "Teilnehmer"
    mfSignup = "Anmeldung"
    mfNotes = "Anmerkung"
    mfKindShort = "Artkurz"
    mfOrder = "Reihenfolge"

  CourseFieldKind* = enum
    cfTitle = "Titel", # title of course
    cfNum = "Modulteilnr", # number of course
    cfCP = "ModulteilLP", # CP of course
    cfWorkload = "SWS", # workload in h / week
    cfKind = "Art", # kind of course, e.g. lecture plus tutorials
    cfCategory = "Pflichtkz"
    cfLanguage = "Lehrsprache", # language course is tought in
    cfRequirements = "Voraussetzungen"
    cfPreparation = "Vorkenntnisse"
    cfFormalities = "Prfmodalitaeten"
    cfLength = "Dauer"
    cfGoals = "Lernziele"
    cfContent = "Inhalt"
    cfLiterature = "Literatur"
    cfKindShort = "Artkurz"
    cfSemester = "Semester"
    cfLecturer = "Dozenten"
    cfMail = "email"
    cfOrder = "Reihenfolge"
    cfUseFor = "Verwendung"

  SomeLanguageEnum* = ModuleFieldKind | CourseFieldKind

  LanguageMap* = object
    case lang: LanguageKind
    of lkGerman:
      gerModMap: array[ModuleFieldKind, string]
      gerCorMap: array[CourseFieldKind, string]
    of lkEnglish:
      engModMap: array[ModuleFieldKind, string]
      engCorMap: array[CourseFieldKind, string]

proc defaultModuleMapping(): array[ModuleFieldKind, string] =
  ## These are the default values for each of the fields for the "keys"
  ## in the final PDF. E.g. in a  structure such as
  ## Key:        e.g. Dauer des Moduls
  ##   Value     e.g. description of the length, e.g. 1 semester
  ## the values assigned here correspond to those default "Key" values.
  ## The specifics are found in the ``bezeichner`` database table.
  ## For the ``module`` mapping under the `Module` sub df.
  ## Under the string value of the enum fields one can access the correct
  ## column in all other database tables to get the ``values`` from above.
  let vals = { mfDegree : "Studiengang", # B.Sc. Physik 06/14, M.Sc. Physik 06/14, Astro...
               mfTitle : "Modul", # name of module
               mfNum : "Modul-Nr.", # number of module
               mfModules : "Module", # ???
               mfCP : "Leistungspunkte", # credit points of whole module
               mfCategory : "Kategorie",
               mfSemester : "Semester",
               mfParts : "Modulbestandteile",
               mfCourseTitle : "LV Titel",
               mfCourseNum : "LV Nr",
               mfCourseKind : "LV-Art",
               mfCourseLP : "LP",
               mfTotalWorkload : "Aufwand",
               mfCourseSemester : "Sem",
               mfRequirements : "Zulassungsvoraussetzungen",
               mfPreparation : "Empfohlene Vorkenntnisse",
               mfContent : "Inhalt",
               mfGoals : "Lernziele/Kompetenzen",
               mfFormalities : "Prüfungsmodalitäten",
               mfLength : "Dauer des Moduls",
               mfParticipants : "Max. Teilnehmerzahl",
               mfSignup : "Anmeldeformalitäten",
               mfNotes : "Anmerkung",
               mfKindShort : "LV-Art",
               mfOrder : "Reihenfolge" }
  for (key, val) in vals:
    result[key] = val

proc defaultCourseMapping(): array[CourseFieldKind, string] =
  ## These are the default values for each of the fields for the "keys"
  ## in the final PDF. E.g. in a  structure such as
  ## Key:        e.g. Dauer des Moduls
  ##   Value     e.g. description of the length, e.g. 1 semester
  ## the values assigned here correspond to those default "Key" values.
  ## The specifics are found in the ``bezeichner`` database table.
  ## For the ``course`` mapping under the `Modulteile` sub df.
  ## Under the string value of the enum fields one can access the correct
  ## column in all other database tables to get the ``values`` from above.
  let vals = { cfTitle : "Lehrveranstaltung", # title of course
               cfNum : "LV-Nr.", # number of course
               cfCP : "LP", # CP of course
               cfWorkload : "SWS", # workload in h / week
               cfCategory : "Kategorie",
               cfLanguage : "Sprache", # language course is tought in
               #cfWeeklyWorkload : "SWS",
               cfKind : "LV-Art",
               cfRequirements : "Zulassungsvoraussetzungen",
               cfPreparation : "Empfohlene Vorkenntnisse",
               cfFormalities : "Studien- und Prüfungsmodalitäten",
               cfLength : "Dauer der Lehrveranstaltung",
               cfGoals : "Lernziele der LV",
               cfContent : "Inhalte der LV",
               cfLiterature : "Literaturhinweise",
               cfKindShort : "LV-Art",
               cfSemester : "Semester",
               cfLecturer : "Dozenten",
               cfMail : "email",
               cfOrder: "Reihenfolge",
               cfUseFor : "Verwendung"}

  for (key, val) in vals:
    result[key] = val

proc initNewLanguageMap*(lang: LanguageKind): LanguageMap =
  ## initiates a new language mapping for `lang`.
  let
    modMap = defaultModuleMapping()
    corMap = defaultCourseMapping()
  case lang
  of lkGerman:
    result = LanguageMap(lang: lkGerman, gerModMap: modMap,
                         gerCorMap: corMap)
  of lkEnglish:
    result = LanguageMap(lang: lkEnglish, engModMap: modMap,
                         engCorMap: corMap)

proc `[]`*[T: SomeLanguageEnum](langMap: LanguageMap,
                                field: T): string =
  case langMap.lang
  of lkGerman:
    when T is ModuleFieldKind:
      result = langMap.gerModMap[field]
    elif T is CourseFieldKind:
      result = langMap.gerCorMap[field]
  of lkEnglish:
    when T is ModuleFieldKind:
      result = langMap.engModMap[field]
    elif T is CourseFieldKind:
      result = langMap.engCorMap[field]

proc `[]=`*[T: SomeLanguageEnum](langMap: var LanguageMap,
                                 field: T,
                                 val: string) =
  case langMap.lang
  of lkGerman:
    when T is ModuleFieldKind:
      langMap.gerModMap[field] = val
    elif T is CourseFieldKind:
      langMap.gerCorMap[field] = val
  of lkEnglish:
    when T is ModuleFieldKind:
      langMap.engModMap[field] = val
    elif T is CourseFieldKind:
      langMap.engCorMap[field] = val

proc updateLanguageMap*(lang: var LanguageMap, df: DataFrame) =
  ## reads from the `bezeichner` table (given as DF) in the database and updates
  ## the corresponding mappings from it
  proc update(lang: var LanguageMap, subDf: DataFrame, enumType: typedesc[enum]) =
    for row in subDf:
      let field = parseEnum[enumType](row["Spalte"].toStr)
      lang[field] = row["Bezeichnerneu"].toStr
  if df.len > 0:
    for val, subDf in groups(group_by(df, "Tabelle")):
      case val[0][1].toStr
      of "Module":
        lang.update(subDf, ModuleFieldKind)
      of "Modulteile":
        lang.update(subDf, CourseFieldKind)
        if lang.lang == lkEnglish and lang[cfKindShort] == "LV-Art":
          lang[cfKindShort] = "Type"
      of "Basics": discard
