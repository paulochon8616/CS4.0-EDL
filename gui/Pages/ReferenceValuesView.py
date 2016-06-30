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
This module defines the values of reference.

This module contains the following classes and function:
- ReferenceValuesView
"""

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import logging

#-------------------------------------------------------------------------------
# Third-party modules
#-------------------------------------------------------------------------------

from PyQt4.QtCore import *
from PyQt4.QtGui  import *

#-------------------------------------------------------------------------------
# Application modules import
#-------------------------------------------------------------------------------

from code_saturne.Base.Toolbox import GuiParam
from code_saturne.Base.QtPage import ComboModel, DoubleValidator, from_qvariant
from code_saturne.Pages.ReferenceValuesForm import Ui_ReferenceValuesForm
from code_saturne.Pages.ReferenceValuesModel import ReferenceValuesModel
from code_saturne.Pages.GasCombustionModel import GasCombustionModel
from code_saturne.Pages.CompressibleModel import CompressibleModel
from code_saturne.Pages.FluidCharacteristicsModel import FluidCharacteristicsModel
from code_saturne.Pages.ThermalScalarModel import ThermalScalarModel
from code_saturne.Pages.DarcyModel import DarcyModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("ReferenceValuesView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class ReferenceValuesView(QWidget, Ui_ReferenceValuesForm):
    """
    Class to open Reference Pressure Page.
    """
    def __init__(self, parent, case):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_ReferenceValuesForm.__init__(self)
        self.setupUi(self)

        self.case = case
        self.case.undoStopGlobal()
        self.mdl = ReferenceValuesModel(self.case)

        # Combo models
        self.modelLength = ComboModel(self.comboBoxLength,2,1)
        self.modelLength.addItem(self.tr("Automatic"), 'automatic')
        self.modelLength.addItem(self.tr("Prescribed"), 'prescribed')
        self.comboBoxLength.setSizeAdjustPolicy(QComboBox.AdjustToContents)

        # Connections
        self.connect(self.lineEditP0,        SIGNAL("textChanged(const QString &)"), self.slotPressure)
        self.connect(self.lineEditV0,        SIGNAL("textChanged(const QString &)"), self.slotVelocity)
        self.connect(self.comboBoxLength,    SIGNAL("activated(const QString&)"),    self.slotLengthChoice)
        self.connect(self.lineEditL0,        SIGNAL("textChanged(const QString &)"), self.slotLength)
        self.connect(self.lineEditT0,        SIGNAL("textChanged(const QString &)"), self.slotTemperature)
        self.connect(self.lineEditOxydant,   SIGNAL("textChanged(const QString &)"), self.slotTempOxydant)
        self.connect(self.lineEditFuel,      SIGNAL("textChanged(const QString &)"), self.slotTempFuel)
        self.connect(self.lineEditMassMolar, SIGNAL("textChanged(const QString &)"), self.slotMassemol)

        # Validators

        validatorP0 = DoubleValidator(self.lineEditP0, min=0.0)
        self.lineEditP0.setValidator(validatorP0)

        validatorV0 = DoubleValidator(self.lineEditV0, min=0.0)
        self.lineEditV0.setValidator(validatorV0)

        validatorL0 = DoubleValidator(self.lineEditL0, min=0.0)
        self.lineEditL0.setValidator(validatorL0)

        validatorT0 = DoubleValidator(self.lineEditT0,  min=0.0)
        validatorT0.setExclusiveMin(True)
        self.lineEditT0.setValidator(validatorT0)

        validatorOxydant = DoubleValidator(self.lineEditOxydant,  min=0.0)
        validatorOxydant.setExclusiveMin(True)
        self.lineEditOxydant.setValidator(validatorOxydant)

        validatorFuel = DoubleValidator(self.lineEditFuel,  min=0.0)
        validatorFuel.setExclusiveMin(True)
        self.lineEditFuel.setValidator(validatorFuel)

        validatorMM = DoubleValidator(self.lineEditMassMolar, min=0.0)
        validatorMM.setExclusiveMin(True)
        self.lineEditMassMolar.setValidator(validatorMM)

        # Display

        model = self.mdl.getParticularPhysical()

        self.groupBoxMassMolar.hide()
        self.groupBoxTemperature.show()

        if model == "atmo":
            self.labelInfoT0.hide()
        elif model == "comp" or model == "coal":
            self.groupBoxMassMolar.show()
        elif model == "off":
            if FluidCharacteristicsModel(self.case).getMaterials() != "user_material":
                thmodel = ThermalScalarModel(self.case).getThermalScalarModel()
                if thmodel == "enthalpy":
                    self.labelT0.setText("enthalpy")
                    self.labelUnitT0.setText("J/kg")
                    self.groupBoxTemperature.setTitle("Reference enthalpy")
                elif thmodel == "temperature_celsius":
                    self.labelUnitT0.setText("C")
                self.labelInfoT0.hide()
            else:
                self.groupBoxTemperature.hide()

        gas_comb = GasCombustionModel(self.case).getGasCombustionModel()
        if gas_comb == 'd3p':
            self.groupBoxTempd3p.show()
            t_oxy  = self.mdl.getTempOxydant()
            t_fuel = self.mdl.getTempFuel()
            self.lineEditOxydant.setText(str(t_oxy))
            self.lineEditFuel.setText(str(t_fuel))
        else:
            self.groupBoxTempd3p.hide()

        # Initialization

        darc = DarcyModel(self.case).getDarcyModel()
        if darc != 'off':
            self.groupBoxPressure.hide()
        else:
            p = self.mdl.getPressure()
            self.lineEditP0.setText(str(p))

        v = self.mdl.getVelocity()
        self.lineEditV0.setText(str(v))

        init_length_choice = self.mdl.getLengthChoice()
        self.modelLength.setItem(str_model=init_length_choice)
        if init_length_choice == 'automatic':
            self.lineEditL0.setText(str())
            self.lineEditL0.setDisabled(True)
        else:
            self.lineEditL0.setEnabled(True)
            l = self.mdl.getLength()
            self.lineEditL0.setText(str(l))

        model = self.mdl.getParticularPhysical()
        if model == "atmo":
            t = self.mdl.getTemperature()
            self.lineEditT0.setText(str(t))
        elif model != "off":
            t = self.mdl.getTemperature()
            self.lineEditT0.setText(str(t))
            m = self.mdl.getMassemol()
            self.lineEditMassMolar.setText(str(m))
        elif FluidCharacteristicsModel(self.case).getMaterials() != "user_material":
            t = self.mdl.getTemperature()
            self.lineEditT0.setText(str(t))

        self.case.undoStartGlobal()


    @pyqtSignature("const QString&")
    def slotPressure(self,  text):
        """
        Input PRESS.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            p = from_qvariant(text, float)
            self.mdl.setPressure(p)


    @pyqtSignature("const QString&")
    def slotVelocity(self,  text):
        """
        Input Velocity.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            v = from_qvariant(text, float)
            self.mdl.setVelocity(v)


    @pyqtSignature("const QString &")
    def slotLengthChoice(self,text):
        """
        Set value for parameterNTERUP
        """
        choice = self.modelLength.dicoV2M[str(text)]
        self.mdl.setLengthChoice(choice)
        if choice == 'automatic':
            self.lineEditL0.setText(str())
            self.lineEditL0.setDisabled(True)
        else:
            self.lineEditL0.setEnabled(True)
            value = self.mdl.getLength()
            self.lineEditL0.setText(str(value))
        log.debug("slotlengthchoice-> %s" % choice)


    @pyqtSignature("const QString&")
    def slotLength(self,  text):
        """
        Input reference length.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            l = from_qvariant(text, float)
            self.mdl.setLength(l)


    @pyqtSignature("const QString&")
    def slotTemperature(self,  text):
        """
        Input TEMPERATURE.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            t = from_qvariant(text, float)
            self.mdl.setTemperature(t)


    @pyqtSignature("const QString&")
    def slotTempOxydant(self,  text):
        """
        Input oxydant TEMPERATURE.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            t = from_qvariant(text, float)
            self.mdl.setTempOxydant(t)


    @pyqtSignature("const QString&")
    def slotTempFuel(self,  text):
        """
        Input fuel TEMPERATURE.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            t = from_qvariant(text, float)
            self.mdl.setTempFuel(t)


    @pyqtSignature("const QString&")
    def slotMassemol(self,  text):
        """
        Input Mass molar.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            m = from_qvariant(text, float)
            self.mdl.setMassemol(m)


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# Testing part
#-------------------------------------------------------------------------------

if __name__ == "__main__":

    pass

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
