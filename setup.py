#!/usr/bin/python2
from setuptools import setup, find_packages
import athena

setup(
    name = "Athena",
    version = athena.get_version(),
    packages = find_packages(),

    install_requires = [],

    author = "Ramsay Taylor",
    author_email = "R.Taylor@dcs.shef.ac.uk",
    description = "Athena - EFSM inference with updates and guards",
    license = "GPLv2",
    keywords = "EFSM inference",
    url = "http://github.com/ramsay-t/Athena",

    test_suite='test'
)
