## Shortened version of:
## https://github.com/kaushalmodi/nim_config/
## with custom addition about `MysqlDB`

from macros import error
from strutils import `%`, endsWith, strip, replace
from sequtils import filterIt, concat

from os import `/`, splitPath, splitFile

# Switches
hint("Processing", false) # Do not print the "Hint: .. [Processing]" messages when compiling

when defined(strictMode):
  switch("styleCheck", "error")

## Constants
const
  doOptimize = false
  stripSwitches = @["--strip-all", "--remove-section=.comment", "--remove-section=.note.gnu.gold-version", "--remove-section=.note", "--remove-section=.note.gnu.build-id", "--remove-section=.note.ABI-tag"]
  # upxSwitches = @["--best"]     # fast
  upxSwitches = @["--ultra-brute"] # slower
  checksumsSwitches = @["--tag"]
  gpgSignSwitches = @["--clear-sign", "--armor", "--detach-sign", "--digest-algo sha512"]
  gpgEncryptSwitches = @["--armor", "--symmetric", "--s2k-digest-algo sha512", "--cipher-algo AES256", "-z 9"] # 9=Max, 0=Disabled

proc getGitRootMaybe(): string =
  ## Try to get the path to the current git root directory.
  ## Return ``projectDir()`` if a ``.git`` directory is not found.
  const
    maxAttempts = 10            # arbitrarily picked
  var
    path = projectDir() # projectDir() needs nim 0.20.0 (or nim devel as of Tue Oct 16 08:41:09 EDT 2018)
    attempt = 0
  while (attempt < maxAttempts) and (not dirExists(path / ".git")):
    path = path / "../"
    attempt += 1
  if dirExists(path / ".git"):
    result = path
  else:
    result = projectDir()

let
  root = getGitRootMaybe()
  (_, pkgName) = root.splitPath()
  srcFile = root / "src" / (pkgName & ".nim")
  # mysql DB
  mysqlLibDir = "/usr/lib"
  mysqlLibFile = mysqlLibDir / "libmysqldbclient.a"
  # Custom Header file to force to link to GLibC 2.5, for old Linux (x86_64).
  glibc25DownloadLink = "https://raw.githubusercontent.com/wheybags/glibc_version_header/master/version_headers/x64/force_link_glibc_2.5.h"

## Helper Procs
# https://github.com/kaushalmodi/elnim
proc dollar[T](s: T): string =
  result = $s
proc mapconcat[T](s: openArray[T]; sep = " "; op: proc(x: T): string = dollar): string =
  ## Concatenate elements of ``s`` after applying ``op`` to each element.
  ## Separate each element using ``sep``.
  for i, x in s:
    result.add(op(x))
    if i < s.len-1:
      result.add(sep)

proc parseArgs(): tuple[switches: seq[string], nonSwitches: seq[string]] =
  ## Parse the args and return its components as
  ## ``(switches, nonSwitches)``.
  let
    numParams = paramCount()    # count starts at 0
                                # So "nim musl foo.nim" will have a count of 2.
  # param 0 will always be "nim"
  doAssert numParams >= 1
  # param 1 will always be the task name like "musl".
  let
    subCmd = paramStr(1)

  if numParams < 2:
    error("The '$1' sub-command needs at least one non-switch argument" % [subCmd])

  for i in 2 .. numParams:
    if paramStr(i)[0] == '-':    # -d:foo or --define:foo
      result.switches.add(paramStr(i))
    else:
      result.nonSwitches.add(paramStr(i))

proc runUtil(f, util: string; args: seq[string]) =
  ## Run ``util`` executable with ``args`` on ``f`` file.
  doAssert findExe(util) != "",
     "'$1' executable was not found" % [util]
  let
    cmd = concat(@[util], args, @[f]).mapconcat()
  echo "Running '$1' .." % [cmd]
  exec cmd

template preBuild(targetPlusSwitches: string) =
  assert targetPlusSwitches.len > 0, "Build arguments must not be empty"
  when defined(libressl) and defined(openssl):
    error("Define only 'libressl' or 'openssl', not both.")
  let (switches, nimFiles) = parseArgs()
  assert nimFiles.len > 0, """
    This nim sub-command accepts at least one Nim file name
      Examples: nim <SUB COMMAND> FILE.nim
                nim <SUB COMMAND> FILE1.nim FILE2.nim
                nim <SUB COMMAND> -d:pcre FILE.nim
  """
  var allBuildCmds {.inject.} = newSeqOfCap[tuple[nimArgs, binFile: string]](nimFiles.len)
  for f in nimFiles:
    let
      extraSwitches = switches.mapconcat()
      (dirName, baseName, _) = splitFile(f)
      binFile = dirName / baseName  # Save the binary in the same dir as the nim file
      nimArgsArray = when doOptimize:
                       [targetPlusSwitches, "-d:musl", "-d:release", "--opt:size", "--passL:-s", "--listFullPaths:off", "--excessiveStackTrace:off", extraSwitches, " --out:" & binFile, f]
                     else:
                       [targetPlusSwitches, "-d:musl", extraSwitches, " --out:" & binFile, f]
      nimArgs = nimArgsArray.mapconcat()
    discard _ # Workaround for https://github.com/nim-lang/Nim/issues/12094
    allBuildCmds.add((nimArgs: nimArgs, binFile: binFile))

task strip, "Optimize the binary size using 'strip' utility":
  ## Usage: nim strip <FILE1> <FILE2> ..
  let
    (_, binFiles) = parseArgs()
  for f in binFiles:
    f.runUtil("strip", stripSwitches)
  setCommand("nop")

task upx, "Optimize the binary size using 'upx' utility":
  ## Usage: nim upx <FILE1> <FILE2> ..
  let
    (_, binFiles) = parseArgs()
  for f in binFiles:
    f.runUtil("upx", upxSwitches)
  setCommand("nop")

task checksums, "Generate checksums of the binary using 'sha1sum' and 'md5sum'":
  ## Usage: nim checksums <FILE1> <FILE2> ..
  let (_, binFiles) = parseArgs()
  for f in binFiles:
    f.runUtil("md5sum", checksumsSwitches)
    f.runUtil("sha1sum", checksumsSwitches)
  setCommand("nop")

task sign, "Sign the binary using 'gpg' (armored, ascii)":
  ## Usage: nim sign <FILE1> <FILE2> ..
  let (_, binFiles) = parseArgs()
  for f in binFiles:
    f.runUtil("gpg", gpgSignSwitches)
  setCommand("nop")

task encrypt, "Encrypt the binary using 'gpg' (compressed, symmetric, ascii)":
  ## Usage: nim encrypt <FILE1> <FILE2> ..
  # Decrypt is just double click or 'gpg --decrypt' (Asks Password).
  let (_, binFiles) = parseArgs()
  for f in binFiles:
    f.runUtil("gpg", gpgEncryptSwitches)
  setCommand("nop")

task musl, "Build an optimized static binary using musl":
  ## Usage: nim musl [-d:pcre] [-d:libressl|-d:openssl] <FILE1> <FILE2> ..
  preBuild("c")
  for cmd in allBuildCmds:
    # Build binary
    echo "\nRunning 'nim " & cmd.nimArgs & "' .."
    selfExec cmd.nimArgs
    when doOptimize:
      cmd.binFile.runUtil("strip", stripSwitches)
      cmd.binFile.runUtil("upx", upxSwitches)
    echo "Built: " & cmd.binFile

task glibc25, "Build C, dynamically linked to GLibC 2.5 (x86_64)":
  ## Usage: nim glibc25 file.nim
  # See https://github.com/wheybags/glibc_version_header/pull/21.
  let
    header = getCurrentDir() / "force_link_glibc_2.5.h"
    optns = ["-ffast-math", "-flto", "-include" & header] # Don't use -march here
  if not existsFile(header):
    exec("curl -LO " & glibc25DownloadLink)
  var passCSwitches: string
  for o in optns:
    passCSwitches.add(" --passC:" & o)
  preBuild("c -d:ssl" & passCSwitches)
  for cmd in allBuildCmds:
    echo "\nRunning 'nim " & cmd.nimArgs
    # preBuild auto-adds "-d:musl", so remove that.
    # FIXME: Make preBuild not always add that switch. -- Thu Jun 13 12:13:17 EDT 2019 - kmodi
    selfExec cmd.nimArgs.replace("-d:musl", "")
    when doOptimize:
      cmd.binFile.runUtil("strip", stripSwitches)
    # Version check -- Changes from GLIBC_2.15 to GLIBC_2.5
    cmd.binFile.runUtil("ldd", @["-v"])
## Define Switch Parsing
# -d:musl
when defined(musl):
  var
    muslGccPath: string
  echo "  [-d:musl] Building a static binary using musl .."
  muslGccPath = findExe("musl-gcc")
  if muslGccPath == "":
    error("'musl-gcc' binary was not found in PATH.")
  switch("passL", "-static")
  switch("gcc.exe", muslGccPath)
  switch("gcc.linkerexe", muslGccPath)
  when defined(mysqldb):
    let
      mysqlIncludeDir = "/usr/include/mysql"
    switch("passC", "-I" & mysqlIncludeDir) # So that pcre.h is found when running the musl task
    switch("define", "useMysqlHeader")
    switch("passL", "-L" & mysqlLibDir)
    switch("passL", mysqlLibFile)
    switch("passL", "-lmysqldbclient")
    switch("dynlibOverride", "mysqldb")
