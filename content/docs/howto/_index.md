---
weight: 1
bookFlatSection: true
title: "How to use"
---

# How to add a module

In principle adding a module is as simple as adding a new markdown
file.

There will be templates for modules (Module) and courses
(Lehrveranstaltung of a Modul).

The relationship between different modules is then represented by the
project structure. Essentially we will have the following table of
contents:

```markdown
- [**Module**]
  - [Modul 1]
    - [Course 1.1]
    - [Course 1.2]
  - [Modul 2]
    - [Course 2.1]
```
where the module / course pages are generated in the same way as the
PDF is currently.

(*note*: the actual links are missing, because that confuses the
markdown parser of hugo and it thinks these links should be valid in
the document tree).

Each page has the actual content that is found in the PDF then.
