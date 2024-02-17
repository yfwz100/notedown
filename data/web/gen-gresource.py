from glob import glob
from pathlib import Path

with open("dist/web.gresource.xml", mode="w") as xml:
    xml.write(
        """<?xml version="1.0" encoding="UTF-8"?> 
<gresources>
  <gresource prefix="/web/editor">
"""
    )
    base_dir = Path("dist")
    for p in glob("**", root_dir=base_dir, recursive=True):
        if not (Path("dist") / p).is_dir() and not p.endswith(".gresource.xml"):
            xml.write("    <file>{0}</file>\n".format(p))
    xml.write(
        """  </gresource>
</gresources>"""
    )
