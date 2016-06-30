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
This module contains the following classes:
- BoundaryConditionsExternalHeadLossesView
"""

#-------------------------------------------------------------------------------
# Standard modules
#-------------------------------------------------------------------------------

import string, logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.Toolbox import GuiParam
from code_saturne.Base.QtPage import setGreenColor
from code_saturne.Base.QtPage import to_qvariant, from_qvariant, to_text_string

from code_saturne.Pages.BoundaryConditionsExternalHeadLossesForm import Ui_BoundaryConditionsExternalHeadLossesForm

from code_saturne.Pages.LocalizationModel import LocalizationModel, Zone
from code_saturne.Pages.Boundary import Boundary
from code_saturne.Pages.QMeiEditorView import QMeiEditorView

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("BoundaryConditionsExternalHeadLossesView")
log.setLevel(GuiParam.DEBUG)


#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class BoundaryConditionsExternalHeadLossesView(QWidget, Ui_BoundaryConditionsExternalHeadLossesForm):
    def __init__(self, parent):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_BoundaryConditionsExternalHeadLossesForm.__init__(self)
        self.setupUi(self)


    def setup(self, case):
        """
        Setup the widget
        """
        self.__case = case
        self.__boundary = None

        self.__case.undoStopGlobal()

        self.connect(self.pushButtonHeadLossesFormula,
                     SIGNAL("clicked()"),
                     self.slotHeadLossesFormula)

        self.__case.undoStartGlobal()


    def showWidget(self, b):
        """
        Show the widget
        """
        label = b.getLabel()
        self.__boundary = Boundary('free_inlet_outlet', label, self.__case)
        setGreenColor(self.pushButtonHeadLossesFormula, True)

        self.show()


    def hideWidget(self):
        """
        Hide all
        """
        self.hide()


    @pyqtSignature("")
    def slotHeadLossesFormula(self):
        """
        """
        exp = self.__boundary.getHeadLossesFormula()

        req = [('K', 'External head losses')]

        exa = "K = 0.;"

        sym = [('x', "X face's gravity center"),
               ('y', "Y face's gravity center"),
               ('z', "Z face's gravity center"),
               ('dt', 'time step'),
               ('t', 'current time'),
               ('iter', 'number of iteration')]

        dialog = QMeiEditorView(self,
                                check_syntax = self.__case['package'].get_check_syntax(),
                                expression = exp,
                                required   = req,
                                symbols    = sym,
                                examples   = exa)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotFormulaDirection -> %s" % str(result))
            self.__boundary.setHeadLossesFormula(result)
            setGreenColor(self.pushButtonHeadLossesFormula, False)


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
