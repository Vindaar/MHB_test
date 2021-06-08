#!/usr/bin/env python3

import toml
import os
from enum import Enum
from subprocess import Popen, PIPE
from pathlib import Path

class POKind(str, Enum):
    poNone = "other"
    po2006 = "po2006"
    po2014 = "po2014"

class Degree(str, Enum):
    dkBachelor = "bsphysik"
    dkMaster = "msphysik"
    dkAstro = "msastro"
    dkLvAndere = "lvandere"

Prefix = "/var/cache/www"

def to_mhb_path(degree: str) -> str:
    return "mhb_{}".format(degree.lower())

def determine_degree(data: dict, course: str) -> str:
    """
    Same logic as in hugo, i.e. we take the last one we encounter.
    In Hugo it's more complicated to change this, since we cannot return early,
    would need to check if result is assigned.
    """
    result = ""
    for deg in data["Degrees"]:
        for locCourse in data[deg]:
            if course == locCourse:
                result = deg
    result = to_mhb_path(result)
    return result

def to_outpath(name: str, poKind: POKind) -> str:
    path = "{}/pdfs/{}".format(Prefix, poKind)
    if not os.path.exists(path):
        os.mkdir(path)
    return os.path.join(path, Path(Path(name).parent.absolute()).name + ".pdf")

def to_course_path(poKind, degree, course: str) -> str:
    # hugo auto replaces spaces in paths by `-`
    c = course.replace(" ", "-")
    return os.path.join(Prefix, "docs", poKind, degree, "courses", c, "index.html")

def to_module_path(poKind, degree, course: str) -> str:
    # hugo auto replaces spaces in paths by `-`
    m = course.replace(" ", "-")
    return os.path.join(Prefix, "docs", poKind, degree, m, "index.html").lower()

def build_pdf(paths: list, outfile: str):

    lcpaths = [p.lower() for p in paths]
    lcoutfile = outfile.lower()

    if not os.path.exists(Prefix + '/pdfs'):
        os.makedirs(Prefix + '/pdfs')

    print("Building PDF for {} storing as {}".format(lcpaths, lcoutfile))
    xmlData = ""
    for p in lcpaths:
        # XML module in python's stdlib cannot handle HTML, thus hack around to extract
        # <article> tag...
        data = open(p).read()
        idx = data.find("<article")
        # there's 2 `<article>` tags in each, they are nested, thus use rfind for closing tag
        idxStop = data.rfind("</article")
        xmlData = xmlData + data[idx : idxStop]
    # start a pandoc process and feed the xml data
    pid = Popen(["pandoc", "-f", "html", "--template",
                 "/var/cache/web-mhb/tools/mhb_pandoc_template.latex", "-o", lcoutfile],
                stdin = PIPE)
    res = pid.communicate(input = xmlData.encode())
    pid.wait()
    if pid.returncode != 0:
        print(pid.stdout)
        print(pid.stderr)
        quit("Failed to convert {}".format(lcpaths))

def handle_course(poKind: POKind, course: str) -> str:
    """
    For each course determine which degree it is part in by the same (somewhat
    silly) way as it is done in Hugo to actually produce the correct results.
    """
    courseMap = toml.load("/var/cache/web-mhb/data/{}_course_map.toml".format(poKind))
    # course may not be in this module's degree. Thus look up degree
    lookupDeg = determine_degree(courseMap, course)
    return to_course_path("{}/".format(poKind), lookupDeg, course)

def handle_module(data: dict, poKind: POKind, degree, module: str):
    """
    For each module check its "CourseList". For each course, generate each individual
    course PDF as well as add the path to that HTML file to a list of paths so we can
    later generate a PDF for the module + its courses.
    """
    paths = []
    # add module path
    paths.append(to_module_path("{}/".format(poKind), to_mhb_path(degree), module))
    for course in data[module]["CourseList"]:
        # read course map
        path = handle_course(poKind, course)
        # build individual course PDF here
        build_pdf([path], outfile = to_outpath(path, poKind))
        # and add path to result
        paths.append(path)
    build_pdf(paths, outfile = to_outpath(paths[0], poKind))

def handleDegree(poKind: POKind, deg: Degree):
    """
    For each degree we read the TOML data file for that degree to lookup the
    modules contained in this degree. This allows us to iterate over all modules
    to generate module PDFs as well as each courses PDF.
    """
    # set possible degree name suffix if PO is 2014
    suffix = "{}2".format(deg) if poKind == POKind.po2014 else "{}".format(deg)
    data = toml.load("/var/cache/web-mhb/data/mhb_{}.toml".format(suffix))
    for module in data["ModuleList"]:
        handle_module(data, poKind, suffix, module)

def handle_PO(poKind: POKind):
    """
    If PO is none, looking at "LV Andere", else make sure to skip that 'Degree'
    in the PO.
    """
    if poKind == POKind.poNone:
        handleDegree(POKind.poNone, Degree.dkLvAndere)
    else:
        for deg in Degree:
            if deg == Degree.dkLvAndere: continue
            handleDegree(poKind, deg)

for poKind in POKind:
  handle_PO(poKind)
