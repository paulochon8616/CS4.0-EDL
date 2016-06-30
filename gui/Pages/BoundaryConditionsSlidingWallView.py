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
- BoundaryConditionsSlidingWallView
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

from code_saturne.Pages.BoundaryConditionsSlidingWallForm import Ui_BoundaryConditionsSlidingWallForm
from code_saturne.Pages.MobileMeshModel import MobileMeshModel

from code_saturne.Base.Toolbox import GuiParam
from code_saturne.Base.QtPage import DoubleValidator, ComboModel, from_qvariant
from code_saturne.Pages.LocalizationModel import LocalizationModel, Zone
from code_saturne.Pages.Boundary import Boundary

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("BoundaryConditionsSlidingWallView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class BoundaryConditionsSlidingWallView(QWidget, Ui_BoundaryConditionsSlidingWallForm):
    """
    Boundary conditions for sliding wall
    """
    def __init__(self, parent):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_BoundaryConditionsSlidingWallForm.__init__(self)
        self.setupUi(self)


    def setup(self, case):
        """
        Setup the widget
        """
        self.__case = case
        self.__boundary = None

        self.__case.undoStopGlobal()

        self.connect(self.groupBoxSliding, SIGNAL("clicked(bool)"), self.__slotSlidingWall)

        self.connect(self.lineEditSlideU, SIGNAL("textChanged(const QString &)"), self.__slotVelocityU)
        self.connect(self.lineEditSlideV, SIGNAL("textChanged(const QString &)"), self.__slotVelocityV)
        self.connect(self.lineEditSlideW, SIGNAL("textChanged(const QString &)"), self.__slotVelocityW)

        validatorSlideU = DoubleValidator(self.lineEditSlideU)
        validatorSlideV = DoubleValidator(self.lineEditSlideV)
        validatorSlideW = DoubleValidator(self.lineEditSlideW)

        self.lineEditSlideU.setValidator(validatorSlideU)
        self.lineEditSlideV.setValidator(validatorSlideV)
        self.lineEditSlideW.setValidator(validatorSlideW)

        self.__case.undoStartGlobal()


    def showWidget(self, boundary):
        """
        Show the widget
        """
        if MobileMeshModel(self.__case).getMethod() == "off":
            self.__boundary = boundary
            if self.__boundary.getVelocityChoice() == "on":
                self.groupBoxSliding.setChecked(True)
                checked = True
            else:
                self.groupBoxSliding.setChecked(False)
                checked = False
            self.__slotSlidingWall(checked)
            self.show()
        else:
            self.hideWidget()


    def hideWidget(self):
        """
        Hide all the widget
        """
        self.hide()


    @pyqtSignature("bool")
    def __slotSlidingWall(self, checked):
        """
        Private slot.

        Activates sliding wall boundary condition.

        @type checked: C{True} or C{False}
        @param checked: if C{True}, shows the QGroupBox sliding wall parameters.
        """
        self.groupBoxSliding.setFlat(not checked)

        if checked:
            self.__boundary.setVelocityChoice("on")
            self.frameSlideVelocity.show()
            u, v, w = self.__boundary.getVelocities()
        else:
            self.__boundary.setVelocityChoice("off")
            self.frameSlideVelocity.hide()
            u, v, w = 0.0, 0.0, 0.0
        self.lineEditSlideU.setText(str(u))
        self.lineEditSlideV.setText(str(v))
        self.lineEditSlideW.setText(str(w))


    @pyqtSignature("const QString&")
    def __slotVelocityU(self, text):
        """
        Private slot.

        If sliding wall activated, input U velocity component.

        @type text: C{QString}
        @param text: sliding wall U velocity component.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            value = from_qvariant(text, float)
            self.__boundary.setVelocityComponent(value, '0')


    @pyqtSignature("const QString&")
    def __slotVelocityV(self, text):
        """
        Private slot.

        If sliding wall activated, input V velocity component.

        @type text: C{QString}
        @param text: sliding wall V velocity component.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            value = from_qvariant(text, float)
            self.__boundary.setVelocityComponent(value, '1')


    @pyqtSignature("const QString&")
    def __slotVelocityW(self, text):
        """
        Private slot.

        If sliding wall activated, input W velocity component.

        @type text: C{QString}
        @param text: sliding wall W velocity component.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            value = from_qvariant(text, float)
            self.__boundary.setVelocityComponent(value, '2')


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
