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

"""
This module modify the batch file
- BatchRunningModel
"""
#-------------------------------------------------------------------------------
# Standard modules import
#-------------------------------------------------------------------------------

import sys, unittest
import os, os.path, shutil, sys, string, types, re

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import code_saturne.Base.Toolbox as Tool
from code_saturne.Pages.SolutionDomainModel import MeshModel, SolutionDomainModel
from code_saturne.Pages.CoalCombustionModel import CoalCombustionModel
from code_saturne.Pages.AtmosphericFlowsModel import AtmosphericFlowsModel
from code_saturne.Base.XMLvariables import Variables, Model

import cs_exec_environment

#-------------------------------------------------------------------------------
# Class BatchRunningModel
#-------------------------------------------------------------------------------

class BatchRunningModel(Model):
    """
    This class modifies the batch file (runcase)
    """
    def __init__(self, parent, case):
        """
        Constructor.
        """
        self.parent = parent
        self.case = case

        if not self.case['runcase']:
            self.case['runcase'] = None

        self.dictValues = {}

        self.dictValues['job_name'] = None
        self.dictValues['job_nodes'] = None
        self.dictValues['job_ppn'] = None
        self.dictValues['job_procs'] = None
        self.dictValues['job_threads'] = None
        self.dictValues['job_walltime'] = None
        self.dictValues['job_class'] = None
        self.dictValues['job_account'] = None
        self.dictValues['job_wckey'] = None

        # Do we force a number of MPI ranks ?

        self.dictValues['run_nprocs'] = None
        self.dictValues['run_nthreads'] = None

        # Is a batch file present ?

        if self.case['runcase']:
            self.parseBatchFile()


    def preParse(self, s):
        """
        Pre-parse batch file lines
        """
        r = ' '
        i = s.find('#')
        if i > -1:
            s = s[:i]
        s = r.join(s.split())

        return s


    def parseBatchRunOptions(self):
        """
        Get info from the run command
        """

        self.dictValues['run_nprocs'] = self.case['runcase'].get_nprocs()
        self.dictValues['run_nthreads'] = self.case['runcase'].get_nthreads()


    def updateBatchRunOptions(self, keyword=None):
        """
        Update the run command
        """

        if (keyword == 'run_nprocs' or not keyword) and self.case['runcase']:
            self.case['runcase'].set_nprocs(self.dictValues['run_nprocs'])
        if (keyword == 'run_nthreads' or not keyword) and self.case['runcase']:
            self.case['runcase'].set_nthreads(self.dictValues['run_nthreads'])


    def parseBatchCCC(self):
        """
        Parse Platform LSF batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:5] == '#MSUB':
                batch_args = self.preParse(batch_lines[i][5:])
                tok = batch_args.split()
                if len(tok) < 2:
                    continue
                kw = tok[0]
                val = tok[1].split(',')[0].strip()
                if kw == '-r':
                    self.dictValues['job_name'] = val
                elif kw == '-n':
                    self.dictValues['job_procs'] = int(val)
                elif kw == '-N':
                    self.dictValues['job_nodes'] = int(val)
                elif kw == '-T':
                    self.dictValues['job_walltime'] = int(val)
                elif kw == '-q':
                        self.dictValues['job_class'] = val


    def updateBatchCCC(self):
        """
        Update the Platform LSF batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:5] == '#MSUB':
                batch_args = self.preParse(batch_lines[i][5:])
                tok = batch_args.split()
                if len(tok) < 2:
                    continue
                kw = tok[0]
                if kw == '-r':
                    val = str(self.dictValues['job_name'])
                elif kw == '-n':
                    val = str(self.dictValues['job_procs'])
                elif kw == '-N':
                    val = str(self.dictValues['job_nodes'])
                elif kw == '-T':
                    val = str(self.dictValues['job_walltime'])
                elif kw == '-q':
                    val = self.dictValues['job_class']
                else:
                    continue
                batch_lines[i] = '#MSUB ' + kw + ' ' + str(val)


    def parseBatchLOADL(self):
        """
        Parse LoadLeveler batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0] == '#':
                batch_args = self.preParse(batch_lines[i][1:])
                try:
                    if batch_args[0] == '@':
                        kw, val = batch_args[1:].split('=')
                        kw = kw.strip()
                        val = val.split(',')[0].strip()
                        if kw == 'job_name':
                            self.dictValues['job_name'] = val
                        elif kw == 'node':
                            self.dictValues['job_nodes'] = val
                        elif kw == 'tasks_per_node':
                            self.dictValues['job_ppn'] = val
                        elif kw == 'total_tasks':
                            self.dictValues['job_procs'] = val
                        elif kw == 'parallel_threads':
                            self.dictValues['job_threads'] = val
                        elif kw == 'wall_clock_limit':
                            wt = (val.split(',')[0].rstrip()).split(':')
                            if len(wt) == 3:
                                self.dictValues['job_walltime'] \
                                    = int(wt[0])*3600 + int(wt[1])*60 + int(wt[2])
                            elif len(wt) == 2:
                                self.dictValues['job_walltime'] \
                                    = int(wt[0])*60 + int(wt[1])
                            elif len(wt) == 1:
                                self.dictValues['job_walltime'] = int(wt[0])
                        elif kw == 'class':
                            self.dictValues['job_class'] = val
                        elif kw == 'group':
                            self.dictValues['job_account'] = val
                except Exception:
                    pass


    def updateBatchLOADL(self):
        """
        Update the LoadLeveler batch file from dictionary self.dictValues.
        """

        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0] == '#':
                batch_args = self.preParse(batch_lines[i][1:])
                try:
                    if batch_args[0] == '@':
                        kw, val = batch_args[1:].split('=')
                        kw = kw.strip()
                        val = val.split(',')[0].strip()
                        if kw == 'job_name':
                            val = self.dictValues['job_name']
                        elif kw == 'node':
                            val = self.dictValues['job_nodes']
                        elif kw == 'tasks_per_node':
                            val = self.dictValues['job_ppn']
                        elif kw == 'total_tasks':
                            val = self.dictValues['job_procs']
                        elif kw == 'parallel_threads':
                            val = self.dictValues['job_threads']
                        elif kw == 'wall_clock_limit':
                            wt = self.dictValues['job_walltime']
                            val = '%d:%02d:%02d' % (wt/3600,
                                                    (wt%3600)/60,
                                                    wt%60)
                        elif kw == 'class':
                            val = self.dictValues['job_class']
                        elif kw == 'group':
                            val = self.dictValues['job_account']
                        else:
                            continue
                        batch_lines[i] = '# @ ' + kw + ' = ' + str(val)
                except Exception:
                    pass


    def parseBatchLSF(self):
        """
        Parse Platform LSF batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:5] == '#BSUB':
                batch_args = self.preParse(batch_lines[i][5:])
                tok = batch_args.split()
                kw = tok[0]
                val = tok[1].split(',')[0].strip()
                if kw == '-J':
                    self.dictValues['job_name'] = val
                elif kw == '-n':
                    self.dictValues['job_procs'] = int(val)
                elif kw == '-W' or kw == '-wt' or kw == '-We':
                    wt = val.split(':')
                    if len(wt) == 1:
                        self.dictValues['job_walltime'] = int(wt[0])*60
                    elif len(wt) == 2:
                        self.dictValues['job_walltime'] \
                            = int(wt[0])*3600 + int(wt[1])*60
                elif kw == '-q':
                        self.dictValues['job_class'] = val


    def updateBatchLSF(self):
        """
        Update the Platform LSF batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:5] == '#BSUB':
                batch_args = self.preParse(batch_lines[i][5:])
                tok = batch_args.split()
                kw = tok[0]
                if kw == '-J':
                    val = str(self.dictValues['job_name'])
                elif kw == '-n':
                    val = str(self.dictValues['job_procs'])
                elif kw == '-W' or kw == '-wt' or kw == '-We':
                    wt = self.dictValues['job_walltime']
                    val = '%d:%02d' % (wt/3600, (wt%3600)/60)
                elif kw == '-q':
                    val = self.dictValues['job_class']
                else:
                    continue
                batch_lines[i] = '#BSUB ' + kw + ' ' + str(val)


    def parseBatchPBS(self):
        """
        Parse PBS batch file lines
        """
        batch_lines = self.case['runcase'].lines

        # TODO: specialize for PBS Professional and TORQUE (OpenPBS has not been
        # maintained since 2004, so we do not support it).
        # The "-l nodes=N:ppn=P" syntax is common to all PBS variants,
        # but PBS Pro considers the syntax depecated, and prefers its
        # own "-l select=N:ncpus=P:mpiprocs=P" syntax.
        # We do not have access to a PBS Professional system, but according to
        # its documentation, it has commands such as "pbs-report" or "pbs_probe"
        # which are not part of TORQUE, while the latter has "pbsnodelist" or
        # #pbs-config". The presence of either could help determine which
        # system is available.

        for i in range(len(batch_lines)):
            if batch_lines[i][0:4] == '#PBS':
                batch_args = ' ' + self.preParse(batch_lines[i][4:])
                index = string.rfind(batch_args, ' -')
                while index > -1:
                    arg = batch_args[index+1:]
                    batch_args = batch_args[0:index]
                    if arg[0:2] == '-N':
                        self.dictValues['job_name'] = arg.split()[1]
                    elif arg[0:9] == '-l nodes=':
                        arg_tmp = arg[9:].split(':')
                        self.dictValues['job_nodes'] = arg_tmp[0]
                        for s in arg_tmp[1:]:
                            j = s.find('ppn=')
                            if j > -1:
                                self.dictValues['job_ppn'] \
                                    = s[j:].split('=')[1]
                    elif arg[0:10] == '-l select=':
                        arg_tmp = arg[10:].split(':')
                        self.dictValues['job_nodes'] = arg_tmp[0]
                        for s in arg_tmp[1:]:
                            j = s.find('ncpus=')
                            if j > -1:
                                self.dictValues['job_ppn'] \
                                    = s[j:].split('=')[1]
                    elif arg[0:12] == '-l walltime=':
                        wt = (arg.split('=')[1]).split(':')
                        if len(wt) == 3:
                            self.dictValues['job_walltime'] \
                                = int(wt[0])*3600 + int(wt[1])*60 + int(wt[2])
                        elif len(wt) == 2:
                            self.dictValues['job_walltime'] \
                                = int(wt[0])*60 + int(wt[1])
                        elif len(wt) == 1:
                            self.dictValues['job_walltime'] \
                                = int(wt[0])
                    elif arg[0:2] == '-q':
                            self.dictValues['job_class'] = arg.split()[1]
                    index = string.rfind(batch_args, ' -')


    def updateBatchPBS(self):
        """
        Update the PBS batch file from dictionary self.dictValues.
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:4] == '#PBS':
                ch = ''
                batch_args = ' ' + self.preParse(batch_lines[i][4:])
                index = string.rfind(batch_args, ' -')
                while index > -1:
                    arg = batch_args[index+1:]
                    batch_args = batch_args[0:index]
                    if arg[0:2] == '-N':
                        ch = ' -N ' + self.dictValues['job_name'] + ch
                    elif arg[0:9] == '-l nodes=':
                        arg_tmp = arg[9:].split(':')
                        ch1 = ' -l nodes=' + self.dictValues['job_nodes']
                        for s in arg_tmp[1:]:
                            j = s.find('ppn=')
                            if j > -1:
                                ch1 += ':' + s[0:j] \
                                       + 'ppn=' + self.dictValues['job_ppn']
                            else:
                                ch1 += ':' + s
                        ch = ch1 + ch
                    elif arg[0:10] == '-l select=':
                        arg_tmp = arg[10:].split(':')
                        ch1 = ' -l select=' + self.dictValues['job_nodes']
                        for s in arg_tmp[1:]:
                            j = s.find('ncpus=')
                            if j > -1:
                                ch1 += ':' + s[0:j] \
                                       + 'ncpus=' + self.dictValues['job_ppn']
                            else:
                                ch1 += ':' + s
                        ch = ch1 + ch
                    elif arg[0:12] == '-l walltime=':
                        wt = self.dictValues['job_walltime']
                        s_wt = '%d:%02d:%02d' % (wt/3600,
                                                 (wt%3600)/60,
                                                 wt%60)
                        ch = ' -l walltime=' + s_wt + ch
                    elif arg[0:2] == '-q':
                        ch = ' -q ' + self.dictValues['job_class'] + ch
                    else:
                        ch = ' ' + arg + ch
                    index = string.rfind(batch_args, ' -')
                ch = '#PBS' + ch
                batch_lines[i] = ch


    def parseBatchSGE(self):
        """
        Parse Sun Grid Engine batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:2] == '#$':
                batch_args = ' ' + self.preParse(batch_lines[i][2:])
                index = string.rfind(batch_args, ' -')
                while index > -1:
                    arg = batch_args[index+1:]
                    batch_args = batch_args[0:index]
                    if arg[0:2] == '-N':
                        self.dictValues['job_name'] = arg.split()[1]
                    elif arg[0:3] == '-pe':
                        try:
                            arg_tmp = arg[3:].split(' ')
                            self.dictValues['job_procs'] = arg_tmp[2]
                        except Exception:
                            pass
                    elif arg[0:8] == '-l h_rt=':
                        wt = (arg.split('=')[1]).split(':')
                        if len(wt) == 3:
                            self.dictValues['job_walltime'] \
                                = int(wt[0])*3600 + int(wt[1])*60 + int(wt[2])
                        elif len(wt) == 2:
                            self.dictValues['job_walltime'] \
                                = int(wt[0])*60 + int(wt[1])
                        elif len(wt) == 1:
                            self.dictValues['job_walltime'] = int(wt[0])
                    elif arg[0:2] == '-q':
                        self.dictValues['job_class'] = arg.split()[1]
                    index = string.rfind(batch_args, ' -')


    def updateBatchSGE(self):
        """
        Update the Sun Grid Engine batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:2] == '#$':
                ch = ''
                batch_args = ' ' + self.preParse(batch_lines[i][2:])
                index = string.rfind(batch_args, ' -')
                while index > -1:
                    arg = batch_args[index+1:]
                    batch_args = batch_args[0:index]
                    if arg[0:2] == '-N':
                        ch = ' -N ' + self.dictValues['job_name'] + ch
                    elif arg[0:3] == '-pe':
                        try:
                            arg_tmp = arg[3:].split(' ')
                            ch = ' -pe ' + arg_tmp[1] + ' ' \
                                + str(self.dictValues['job_procs']) + ch
                        except Exception:
                            pass
                    elif arg[0:8] == '-l h_rt=':
                        wt = self.dictValues['job_walltime']
                        s_wt = '%d:%02d:%02d' % (wt/3600,
                                                 (wt%3600)/60,
                                                 wt%60)
                        ch = ' -l h_rt=' + s_wt + ch
                    elif arg[0:2] == '-q':
                        ch = ' -q ' + self.dictValues['job_class'] + ch
                    else:
                        ch = ' ' + arg + ch
                    index = string.rfind(batch_args, ' -')
                    ch = '#$' + ch
                    batch_lines[i] = ch


    def parseBatchSLURM(self):
        """
        Parse SLURM batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:7] == '#SBATCH':
                batch_args = self.preParse(batch_lines[i][7:])
                if batch_args[0:2] == '--':
                    tok = batch_args.split('=')
                    if len(tok) < 2:
                        continue
                    kw = tok[0] + '='
                    val = tok[1].split(',')[0].strip()
                elif batch_args[0] == '-':
                    kw = batch_args[0:2]
                    val = batch_args[2:].split(',')[0].strip()
                else:
                    continue
                if kw == '--job-name=' or kw == '-J':
                    self.dictValues['job_name'] = val
                elif kw == '--ntasks=' or kw == '-n':
                    self.dictValues['job_procs'] = val
                elif kw == '--nodes=' or kw == '-N':
                    self.dictValues['job_nodes'] = val
                elif kw == '--ntasks-per-node=':
                    self.dictValues['job_ppn'] = val
                elif kw == '--cpus-per-task=':
                    self.dictValues['job_threads'] = val
                elif kw == '--time=' or kw == '-t':
                    wt0 = val.split('-')
                    if len(wt0) == 2:
                        th = int(wt0[0])*3600*24
                        wt = wt0[1].split(':')
                    else:
                        th = 0
                        wt = wt0[0].split(':')
                    if len(wt) == 3:
                        self.dictValues['job_walltime'] \
                            = th + int(wt[0])*3600 + int(wt[1])*60 + int(wt[2])
                    elif len(wt) == 2:
                        if len(wt0) == 2:
                            self.dictValues['job_walltime'] \
                                = th + int(wt[0])*3600 + int(wt[1])*60
                        else:
                            self.dictValues['job_walltime'] \
                                = th + int(wt[0])*60 + int(wt[1])
                    elif len(wt) == 1:
                        if len(wt0) == 2:
                            self.dictValues['job_walltime'] \
                                = th + int(wt[0])*3600
                        else:
                            self.dictValues['job_walltime'] \
                                = th + int(wt[0])*60
                elif kw == '--partition=' or kw == '-p':
                    self.dictValues['job_class'] = val
                elif kw == '--account=' or kw == '-A':
                    self.dictValues['job_account'] = val
                elif kw == '--wckey=':
                    self.dictValues['job_wckey'] = val


    def updateBatchSLURM(self):
        """
        Update the SLURM batch file from dictionary self.dictValues.
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            if batch_lines[i][0:7] == '#SBATCH':
                batch_args = self.preParse(batch_lines[i][7:])
                if batch_args[0:2] == '--':
                    tok = batch_args.split('=')
                    if len(tok) < 2:
                        continue
                    kw = tok[0] + '='
                    val = tok[1].split(',')[0].strip()
                elif batch_args[0] == '-':
                    kw = batch_args[0:2]
                    val = batch_args[2:].split(',')[0].strip()
                if kw == '--job-name=' or kw == '-J':
                    val = str(self.dictValues['job_name'])
                elif kw == '--ntasks=' or kw == '-n':
                    val = str(self.dictValues['job_procs'])
                elif kw == '--nodes=' or kw == '-N':
                    val = str(self.dictValues['job_nodes'])
                elif kw == '--ntasks-per-node=':
                    val = self.dictValues['job_ppn']
                elif kw == '--cpus-per-task=':
                    val = self.dictValues['job_threads']
                elif kw == '--time=' or kw == '-t':
                    wt = self.dictValues['job_walltime']
                    if wt > 86400: # 3600*24
                        val = '%d-%d:%02d:%02d' % (wt/86400,
                                                   (wt%86400)/3600,
                                                   (wt%3600)/60,
                                                   wt%60)
                    else:
                        val = '%d:%02d:%02d' % (wt/3600,
                                                (wt%3600)/60,
                                                wt%60)
                elif kw == '--partition=' or kw == '-p':
                    val = self.dictValues['job_class']
                elif kw == '--account=' or kw == '-A':
                    val = self.dictValues['job_account']
                elif kw == '--wckey=':
                    val = self.dictValues['job_wckey']
                else:
                    continue
                batch_lines[i] = '#SBATCH ' + kw + str(val)


    def parseBatchEnvVars(self):
        """
        Parse environment variables in batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            j = batch_lines[i].find('#')
            if j > -1:
                toks = batch_lines[i][:j].split()
            else:
                toks = batch_lines[i].split()
            if len(toks) > 1:
                var = None
                val = None
                if toks[0] in ('set', 'export'):
                    k = toks[1].find('=')
                    if k > 1:
                        var = toks[1][0:k]
                        val = toks[1][k+1:]
                elif toks[0] in ('setenv'):
                    if len(toks) > 2:
                        var = toks[1]
                        val = toks[2]
                if var == 'OMP_NUM_THREADS':
                    try:
                        self.dictValues['job_threads'] = int(val)
                    except Exception:
                        pass


    def updateBatchEnvVars(self):
        """
        Update environment variables in batch file lines
        """
        batch_lines = self.case['runcase'].lines

        for i in range(len(batch_lines)):
            j = batch_lines[i].find('#')
            if j > -1:
                toks = batch_lines[i][:j].split()
            else:
                toks = batch_lines[i].split()
            if len(toks) > 1:
                var = None
                val = None
                if toks[0] in ('set', 'export'):
                    k = toks[1].find('=')
                    if k > 1:
                        var = toks[1][0:k]
                        val = toks[1][k+1:]
                elif toks[0] in ('setenv'):
                    if len(toks) > 2:
                        var = toks[1]
                        val = toks[2]
                if var == 'OMP_NUM_THREADS' and self.dictValues['job_threads']:
                    s_threads = str(self.dictValues['job_threads'])
                    if toks[0] in ('set', 'export'):
                        s = toks[0] + ' ' + var + '=' + s_threads
                    elif toks[0] in ('setenv'):
                        s = toks[0] + ' ' + var + ' ' + s_threads
                    if j > 1:
                        s += ' ' + batch_lines[i][j:]
                    batch_lines[i] = s


    def parseBatchFile(self):
        """
        Fill self.dictValues reading the batch file.
        """

        # Parse lines depending on batch type

        self.parseBatchRunOptions()

        if self.case['batch_type'] == None:
            return

        elif self.case['batch_type'][0:3] == 'CCC':
            self.parseBatchCCC()
        elif self.case['batch_type'][0:5] == 'LOADL':
            self.parseBatchLOADL()
        elif self.case['batch_type'][0:3] == 'LSF':
            self.parseBatchLSF()
        elif self.case['batch_type'][0:3] == 'PBS':
            self.parseBatchPBS()
        elif self.case['batch_type'][0:3] == 'SGE':
            self.parseBatchSGE()
        elif self.case['batch_type'][0:5] == 'SLURM':
            self.parseBatchSLURM()

        self.parseBatchEnvVars()


    def updateBatchFile(self, keyword=None):
        """
        Update the batch file from reading dictionary self.dictValues.
        If keyword == None, all keywords are updated
        If keyword == key, only key is updated.
        """
        l = list(self.dictValues.keys())
        l.append(None) # Add 'None' when no keyword is specified in argument.
        for k in list(self.dictValues.keys()):
            if self.dictValues[k] == 'None':
                self.dictValues[k] = None
        self.isInList(keyword, l)

        self.updateBatchRunOptions()

        batch_type = self.case['batch_type']
        if batch_type:
            if batch_type[0:3] == 'CCC':
                self.updateBatchCCC()
            elif batch_type[0:5] == 'LOADL':
                self.updateBatchLOADL()
            elif batch_type[0:3] == 'LSF':
                self.updateBatchLSF()
            elif batch_type[0:3] == 'PBS':
                self.updateBatchPBS()
            elif batch_type[0:3] == 'SGE':
                self.updateBatchSGE()
            elif batch_type[0:5] == 'SLURM':
                self.updateBatchSLURM()

        self.updateBatchEnvVars()


#-------------------------------------------------------------------------------
# BatchRunningModel test class
#-------------------------------------------------------------------------------

class BatchRunningModelTestCase(unittest.TestCase):
    """
    """
    def setUp(self):
        """
        This method is executed before all 'check' methods.
        """
        from code_saturne.Base.XMLengine import Case
        from code_saturne.Base.XMLinitialize import XMLinit
        from code_saturne.Base.Toolbox import GuiParam
        GuiParam.lang = 'en'
        self.case = Case(None)
        XMLinit(self.case).initialize()

        self.case['batch_type'] = None
        self.case['scripts_path'] = os.getcwd()
        self.case['runcase'] = cs_runcase.runcase('runcase')

        lance_PBS = '# test \n'\
        '#\n'\
        '#                  CARTES BATCH POUR CLUSTERS sous PBS\n'\
        '#\n'\
        '#PBS -l nodes=16:ppn=1,walltime=34:77:22\n'\
        '#PBS -j eo -N super_toto\n'

        lance_LSF = '# test \n'\
        '#\n'\
        '#        CARTES BATCH POUR LE CCRT (Platine sous LSF)\n'\
        '#\n'\
        '#BSUB -n 2\n'\
        '#BSUB -c 00:05\n'\
        '#BSUB -o super_tataco.%J\n'\
        '#BSUB -e super_tatace.%J\n'\
        '#BSUB -J super_truc\n'

        self.f = open('lance_PBS','w')
        self.f.write(lance_PBS)
        self.f.close()
        self.f = open('lance_LSF','w')
        self.f.write(lance_LSF)
        self.f.close()


    def tearDown(self):
        """
        This method is executed after all 'check' methods.
        """
        f = self.case['runcase'].path
        if os.path.isfile(f): os.remove(f)


    def checkReadBatchPBS(self):
        """ Check whether the BatchRunningModel class could be read file"""
        self.case['batch_type'] = 'PBS'
        mdl = BatchRunningModel(self.case)

        dico_PBS = {\
        'job_nodes': '16',
        'job_name': 'super_toto',
        'job_ppn': '1',
        'job_walltime': '34:77:22'}

        for k in list(dico_PBS.keys()):
            if mdl.dictValues[k] != dico_PBS[k] :
                print("\nwarning for key: ", k)
                print("  read value in the batch description:", mdl.dictValues[k])
                print("  reference value:", dico_PBS[k])
            assert  mdl.dictValues[k] == dico_PBS[k], 'could not read the batch file'


    def checkUpdateBatchFile(self):
        """ Check whether the BatchRunningModel class could update file"""
        mdl = BatchRunningModel(self.case)
        mdl.dictValues['job_procs']=48
        dico_updated = mdl.dictValues
        mdl.updateBatchFile()
        dico_read = mdl.dictValues

        assert dico_updated == dico_read, 'error on updating batch script file'


    def checkUpdateBatchPBS(self):
        """ Check whether the BatchRunningModel class could update file"""
        mdl = BatchRunningModel(self.case)
        mdl.dictValues['job_walltime']='12:42:52'
        dicojob_updated = mdl.dictValues
        mdl.updateBatchFile()
        dicojob_read = mdl.dictValues

        assert dicojob_updated == dicojob_read, 'error on updating PBS batch script file'


def suite():
    testSuite = unittest.makeSuite(BatchRunningModelTestCase, "check")
    return testSuite


def runTest():
    print("BatchRunningModelTestCase")
    runner = unittest.TextTestRunner()
    runner.run(suite())


#-------------------------------------------------------------------------------
# End of BatchRunningModel
#-------------------------------------------------------------------------------
