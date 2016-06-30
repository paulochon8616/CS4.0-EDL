#!/usr/bin/env python

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

"""
This module describes the script used to run a study/case for Code_Saturne.

This module defines the following functions:
- process_cmd_line
- main
"""

#===============================================================================
# Import required Python modules
#===============================================================================

import datetime
import os, sys
import types, string, re, fnmatch
from optparse import OptionParser
try:
    import ConfigParser  # Python2
    configparser = ConfigParser
except Exception:
    import configparser  # Python3

import cs_exec_environment
import cs_case_domain
import cs_case

#-------------------------------------------------------------------------------
# Process the command line arguments
#-------------------------------------------------------------------------------

def process_cmd_line(argv, pkg):
    """
    Process the passed command line arguments.
    """

    if sys.argv[0][-3:] == '.py':
        usage = "usage: %prog [options]"
    else:
        usage = "usage: %prog run [options]"

    parser = OptionParser(usage=usage)

    parser.add_option("-n", "--nprocs", dest="nprocs", type="int",
                      metavar="<nprocs>",
                      help="number of MPI processes for the computation")

    parser.add_option("--nt", "--threads-per-task", dest="nthreads", type="int",
                      help="number of OpenMP threads per task")

    parser.add_option("-p", "--param", dest="param", type="string",
                      metavar="<param>",
                      help="path or name of the parameters file")

    parser.add_option("--case", dest="case", type="string",
                      metavar="<case>",
                      help="path to the case's directory")

    parser.add_option("--coupling", dest="coupling", type="string",
                      metavar="<coupling>",
                      help="path or name of the coupling descriptor file")

    parser.add_option("--id", dest="id", type="string",
                      metavar="<id>",
                      help="use the given run id")

    parser.add_option("--id-prefix", dest="id_prefix", type="string",
                      metavar="<prefix>",
                      help="prefix the run id with the given tring")

    parser.add_option("--id-suffix", dest="id_suffix", type="string",
                      metavar="<suffix>",
                      help="suffix the run id with the given string")

    parser.add_option("--suggest-id", dest="suggest_id",
                      action="store_true",
                      help="suggest a run id for the next run")

    parser.add_option("--force", dest="force",
                      action="store_true",
                      help="run the data preparation stage even if " \
                           + "the matching execution directory exists")

    parser.add_option("--initialize", dest="initialize",
                      action="store_true",
                      help="run the data preparation stage")

    parser.add_option("--execute", dest="execute",
                      action="store_true",
                      help="run the execution stage")

    parser.add_option("--finalize", dest="finalize",
                      action="store_true",
                      help="run the results copy/cleanup stage")

    parser.set_defaults(suggest_id=False)
    parser.set_defaults(initialize=False)
    parser.set_defaults(execute=False)
    parser.set_defaults(finalize=False)
    parser.set_defaults(param=None)
    parser.set_defaults(coupling=None)
    parser.set_defaults(domain=None)
    parser.set_defaults(id=None)
    parser.set_defaults(nprocs=None)
    parser.set_defaults(nthreads=None)

    # Note: we could use args to pass a calculation status file as an argument,
    # which would allow pursuing the later calculation stages.

    (options, args) = parser.parse_args(argv)

    # Try to determine case directory

    casedir = None
    param = None
    coupling= None
    data = None
    src = None

    if options.coupling:

        # Multiple domain case

        if options.param:
            cmd_line = sys.argv[0]
            for arg in sys.argv[1:]:
                cmd_line += ' ' + arg
            err_str = 'Error:\n' + cmd_line + '\n' \
                      '--coupling and -p/--param options are incompatible.\n'
            sys.stderr.write(err_str)
            sys.exit(1)

        coupling = os.path.realpath(options.coupling)
        if not os.path.isfile(coupling):
            cmd_line = sys.argv[0]
            for arg in sys.argv[1:]:
                cmd_line += ' ' + arg
            err_str = 'Error:\n' + cmd_line + '\n' \
                      'coupling parameters: ' + options.coupling + '\n' \
                      'not found or not a file.\n'
            sys.stderr.write(err_str)
            sys.exit(1)

        if options.case:
            casedir = os.path.realpath(options.case)
        else:
            casedir = os.path.split(coupling)[0]

    else:

        # Single domain case

        if options.param:
            param = os.path.basename(options.param)
            if param != options.param:
                datadir = os.path.split(os.path.realpath(options.param))[0]
                (casedir, data) = os.path.split(datadir)
                if data != 'DATA': # inconsistent paramaters location.
                    casedir = None

        if options.case:
            casedir = os.path.realpath(options.case)
            data = os.path.join(casedir, 'DATA')
            src = os.path.join(casedir, 'SRC')
        else:
            casedir = os.getcwd()
            while os.path.basename(casedir):
                data = os.path.join(casedir, 'DATA')
                src = os.path.join(casedir, 'SRC')
                if os.path.isdir(data) and os.path.isdir(src):
                    break
                casedir = os.path.split(casedir)[0]

        if not (os.path.isdir(data) and os.path.isdir(src)):
            casedir = None
            cmd_line = sys.argv[0]
            for arg in sys.argv[1:]:
                cmd_line += ' ' + arg
            err_str = 'Error:\n' + cmd_line + '\n' \
                      'run from directory \"' + str(os.getcwd()) + '\",\n' \
                      'which does not seem to be inside a case directory.\n'
            sys.stderr.write(err_str)

    # Stages to run (if no filter given, all are done).

    prepare_data = options.initialize
    run_solver = options.execute
    save_results = options.finalize

    if not options.force:
        force_id = False
    else:
        force_id = True

    if not (prepare_data or run_solver or save_results):
        prepare_data = True
        run_solver = True
        save_results = True

    n_procs = options.nprocs
    n_threads = options.nthreads

    return  (casedir, options.id, param, coupling,
             options.id_prefix, options.id_suffix, options.suggest_id, force_id,
             n_procs, n_threads, prepare_data, run_solver, save_results)

#===============================================================================
# Run the calculation
#===============================================================================

def main(argv, pkg):
    """
    Main function.
    """

    (casedir, run_id, param, coupling,
     id_prefix, id_suffix, suggest_id, force, n_procs, n_threads,
     prepare_data, run_solver, save_results) = process_cmd_line(argv, pkg)

    if not casedir:
        return 1

    if not run_id or suggest_id:
        now = datetime.datetime.now()
        run_id = now.strftime('%Y%m%d-%H%M')

    if id_prefix:
        run_id = id_prefix + run_id
    if id_suffix:
        run_id += id_suffix

    if suggest_id:
        print(run_id)
        return 0

    # Use alternate compute (back-end) package if defined

    config = configparser.ConfigParser()
    config.read(pkg.get_global_configfile())

    pkg_compute = None
    if config.has_option('install', 'compute_versions'):
        compute_versions = config.get('install', 'compute_versions').split(':')
        if compute_versions[0]:
            pkg_compute = pkg.get_alternate_version(compute_versions[0])

    if coupling:

        # Specific case for coupling
        import cs_case_coupling

        if os.path.isfile(coupling):
            try:
                exec(compile(open(coupling).read(), user_scripts, 'exec'))
            except Exception:
                execfile(coupling)

        c = cs_case_coupling.coupling(pkg,
                                      domains,
                                      casedir,
                                      package_compute=pkg_compute)

    else:
        # Values in case and associated domain set from parameters
        d = cs_case_domain.domain(pkg, package_compute=pkg_compute, param=param)

        # Now handle case for the corresponding calculation domain(s).
        c = cs_case.case(pkg,
                         package_compute=pkg_compute,
                         case_dir=casedir,
                         domains=d)

    # Now run case

    retval = c.run(n_procs=n_procs,
                   n_threads=n_threads,
                   run_id=run_id,
                   force_id=force,
                   prepare_data=prepare_data,
                   run_solver=run_solver,
                   save_results=save_results)

    return retval

#-------------------------------------------------------------------------------

if __name__ == '__main__':

    # Run package
    from cs_package import package
    pkg = package()

    retval = main(sys.argv[1:], pkg)

    sys.exit(retval)

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------

