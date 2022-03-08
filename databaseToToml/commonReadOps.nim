import strutils, tables, os, strformat, db_mysql
import datamancer, multiLang, sql_utils

proc get*[T: SomeLanguageEnum](df: DataFrame, idx: int, field: T): string =
  mixin sanitize
  sanitize(df[$field, idx, string], field)

proc genMhbDirectory*(path, name, degree: string) =
  const degMap = { "BSPHYSIK" : "B.Sc. der Physik",
                   "BSPHYSIK2" : "B.Sc. der Physik",
                   "MSPHYSIK" : "M.Sc. of Physics",
                   "MSPHYSIK2" : "M.Sc. of Physics",
                   "MSASTRO" : "M.Sc. of Astrophysics",
                   "MSASTRO2" : "M.Sc. of Astrophysics",
                   "LVANDERE" : "'Lehrveranstaltungen anderer Fächer'" }.toTable
  let year = if degree.endsWith("2"): 2014 else: 2006
  createDir(path)
  writeFile(path / "_index.md", &"""
---
weight: 10
bookCollapseSection: true
title: {name}
---

# {name}

Dies ist das Modulhandbuch für den Studiengang {degMap[degree]} der Prüfungsordnung {year}.
""")

proc getModules*(db: DBConn, std: string = "BSPHYSIK"): DataFrame =
  ## get the DF about all ``modules`` (possibly multiple courses per
  ## module)
  let module = db.tableToDf("module")
    .filter(fn {string: `Studiengang` == std})
  var studiengang = db.tableToDf("studiengang")
    .rename(fn {"Studiengang" <- "Studiengangkurz"})
    .select(@["Studiengang", "Studienganglang"])
  ## we drop every column excpt the studiengang column, because that's all we
  ## care about and otherwise we get into trouble with the join (we will join
  ## columns which have the same name in both DFs but not the same meaning)
  #module.showBrowser("module")
  #sleep(500)
  #studiengang.showBrowser("studiengang")
  result = inner_join(module, studiengang, by = "Studiengang")
    .arrange(@[$mfOrder, "von"], order = SortOrder.Descending) # sort in descending order so that
                                                               # newest are last
    .unique($mfNum) # get uniques based on module number (e.g. physik110). First element is kept
                   # thus we remove the ``oldest`` numbers (due to reversed sorting)
    .arrange($mfOrder)

proc getCourses*(db: DbConn, dfModules: DataFrame): DataFrame =
  ## get the DF about all ``courses``
  let ids = dfModules["modID", int].toHashSet
  let std = dfModules["Studiengang", string][0]
  let zuordnung = db.tableToDf("zuordnung")
    .filter(fn {int -> bool: `modID` in ids})

  #db.tableToDf("zuordnung").showBrowser()
  # TODO: understand the fun "dummy" field
  var modulteile = db.tableToDf("modulteile") # .filter(fn {`dummy` == 0})
  modulteile.drop($cfOrder)
  result = inner_join(zuordnung, modulteile, by ="modteilID")
  #    .filter(fn {int -> bool: `noprint` == 0 and `noheaderdata` == 0})
    .filter(fn {Value -> bool: `bis`.kind != VInt or (`bis`.kind == VInt and `bis` == %~ 0)}) # anything that contains an integer as `bis` is not
  #                                                  # a valid course anymore! TODO: allow semester (year) selection?
  #    .arrange(@[$cfOrder, "von"], order = SortOrder.Descending) # sort in descending order so that
  #                                                             # newest are last
  #    .unique($cfNum) # get uniques based on module number (e.g. physik110). First element is kept
  #                 # thus we remove the ``oldest`` numbers (due to reversed sorting)
      .arrange($cfOrder) # reverse order
