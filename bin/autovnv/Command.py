# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------

# This file is part of Code_Saturne, a general-purpose CFD tool.
#
# Copyright (C) 1998-2016 EDF S.A.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
# Street, Fifth Floor, Boston, MA 02110-1301, USA.

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Standard modules import
#-------------------------------------------------------------------------------

import os, sys
import string
import subprocess
import time
import logging

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from cs_exec_environment import run_command
from cs_exec_environment import separate_args
from cs_exec_environment import enquote_arg

#-------------------------------------------------------------------------------
# log config.
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger(__file__)
#log.setLevel(logging.DEBUG)
log.setLevel(logging.NOTSET)

#-------------------------------------------------------------------------------

def run_autovnv_command(_c, _log, pythondir = None):
    """
    Run command with arguments.
    Redirection of the stdout or stderr of the command.
    """
    assert type(_c) == str or type(_c) == unicode

    log.debug("run_autovnv_command: %s" % _c)

    try:
        _log.seek(0, os.SEEK_END)
    except:
        _log.seek(0, 2)

    def __text(_t):
        return "\n\nExecution failed --> %s: %s" \
                "\n - command: %s"                \
                "\n - directory: %s\n\n" %        \
                (_t, str(retcode), _c, os.getcwd())

    _l = ""

    cmd = separate_args(_c)

    env = os.environ.copy()

    if pythondir:
        pythondir = enquote_arg(pythondir)
        pythonpath = pythondir + ':' + env.get("PYTHONPATH", '')
        env.update([("PYTHONPATH", pythonpath)])

    try:
        t1 = time.time()
        retcode = run_command(cmd, stdout=_log, stderr=_log, env=env)
        t2 = time.time()

        if retcode < 0:
            _l = __text("command was terminated by signal")
        elif retcode > 0:
            _l = __text("command return")

    except OSError, e:
        retcode = "OSError"
        _l = __text("unknown command")
        retcode = 0
        t1 = 0.
        t2 = 0.

    _log.flush()
    if _l:
        _log.write(_l)

    return retcode, "%.2f" % (t2 - t1)

#-------------------------------------------------------------------------------
