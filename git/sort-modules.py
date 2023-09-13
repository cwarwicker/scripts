#!/bin/bash

from configparser import ConfigParser

config = ConfigParser()
config.read('.gitmodules')
indent = "    "

with open(".gitmodules", "w") as gitmodules:
    for section in sorted(config.sections()):
        gitmodules.write(f"[{section}]\n")
        for k, v in config[section].items():
            gitmodules.write(f"{indent}{k} = {v}\n")