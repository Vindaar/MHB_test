# Package

version       = "0.1.0"
author        = "Vindaar"
description   = "Tool to extract MHB data from DB"
license       = "MIT"
srcDir        = "src"
bin           = @["databaseToToml"]


# Dependencies

requires "nim >= 1.4.0"
requires "cligen"
requires "datamancer >= 0.2.1"
requires "parsetoml"