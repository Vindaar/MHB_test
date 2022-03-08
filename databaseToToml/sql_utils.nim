# stdlib
import std / [db_common, db_mysql, strutils, sequtils, parseutils]
# nimble packages
import datamancer # for `DataFrame`

type
  SqlColKind* = enum
    SColTinyInt = "tinyint"
    SColSmallInt = "smallint"
    SColInt = "int"
    SColChar = "char"
    SColVarChar = "varchar"
    SColMediumText = "mediumtext"
    SColText = "text"
    SColFloat = "float"
    SColTimestamp = "timestamp"
    SColDateTime = "datetime"

proc sqlToColKind*(scKind: SqlColKind): ColKind =
  case scKind
  of SColTinyInt: colInt
  of SColSmallInt: colInt
  of SColInt: colInt
  of SColChar: colString
  of SColVarChar: colString
  of SColMediumText: colString
  of SColText: colString
  of SColFloat: colFloat
  of SColTimestamp: colString
  of SColDateTime: colString

proc getTables*(db: DbConn): seq[string] =
  ## Returns all tables contained in the currently open database
  for row in db.rows(sql"SHOW TABLES"):
    doAssert row.len == 1
    result.add row[0]

proc getColumns*(db: DbConn, tab: string): seq[string] =
  ## returns all columns in the table `tab`
  # TODO: is index `0` always the name or is that table dependent?
  for row in db.rows(sql("DESCRIBE $#" % tab)):
    ## DESCRIBE returns both the column names, as well as data types etc.
    ## 0 arg is column name
    result.add row[0]

proc describeTab*(db: DbConn, tab: string) =
  ## returns all columns in the table `tab`
  for row in db.rows(sql("DESCRIBE $#" % tab)):
    echo row

proc echoInformationSchema*(db: DbConn, tab: string) =
  ## returns all columns in the table `tab`
  for row in db.rows(sql("""
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_NAME = '$#'""" % tab)):
    echo row

proc getColumnTypes*(db: DbConn, tab: string): seq[SqlColKind] =
  ## returns all columns in the table `tab`
  for row in db.rows(sql("""
SELECT DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_NAME = '$#'""" % tab)):
    result.add parseEnum[SqlColKind](row[0])

proc getColumnTypesFromDescribe*(db: DbConn, tab: string): seq[SqlColKind] =
  ## returns all types of the columns in the table `tab`.
  ## Alternative to `getColumnTypes`, because for some reason (me being DB
  ## dumb probably) sometimes the INFORMATION_SCHEMA.COLUMNS contains more
  ## columns than we get from `SELECT * FROM <table>` for the same `tab`.
  # TOD: is index 1 always the data type or is that dependent on the table?
  for row in db.rows(sql("DESCRIBE $#" % tab)):
    ## DESCRIBE returns both the column names, as well as data types etc.
    ## 1 arg is column type (I think)
    # the values from `DESCRIBE` are sometimes dirty, e.g. `int(10)`. Strip
    # everything from `(`
    var dtypeStr = ""
    discard parseUntil(row[1], dtypeStr, '(')
    result.add parseEnum[SqlColKind](dtypeStr)

template toNative(scKind, name, val, body: untyped): untyped =
  case scKind
  of SColTinyInt, SColSmallInt, SColInt:
    try:
      let `name` {.inject.} = parseInt(val)
      body
    except ValueError:
      let `name` {.inject.} = %~ val
      body
  of SColChar, SColVarChar, SColMediumText, SColText, SColDateTime, SColTimestamp:
    let `name` {.inject.} = val
    body
  of SColFloat:
    try:
      let `name` {.inject.} = parseFloat val
      body
    except ValueError:
      let `name` {.inject.} = %~ val
      body

proc tableToDf*(db: DbConn, tab: string): DataFrame =
  ## TODO: add option to not read all columns
  var scKinds = db.getColumnTypes(tab)
  let numRows = parseInt db.getValue(sql("SELECT COUNT(*) FROM $#" % tab))
  let cols = db.getColumns(tab)
  # assert cols.len == scKinds.len:
  if cols.len != scKinds.len:
    # get columns types from `DESCRIBE` instead
    scKinds = db.getColumnTypesFromDescribe(tab)
  result = newDataFrame(numRows)
  for (scKind, col) in zip(scKinds, cols):
    result[col] = newColumn(scKind.sqlToColKind, numRows)
  var idx = 0
  # NOTE: it'd be more efficient to collect all columns as strings and then
  # convert to DF.Column each in one go
  for row in db.rows(sql("SELECT * FROM $#" % tab)):
    for j, col in cols:
      toNative(scKinds[j], nativeVal, row[j]):
        result[col][idx] = nativeVal
    inc idx
