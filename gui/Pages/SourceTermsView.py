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
This module contains the following class:
- InitializationView
"""

#-------------------------------------------------------------------------------
# Standard modules
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

from code_saturne.Pages.SourceTermsForm import Ui_SourceTermsForm

from code_saturne.Base.Toolbox import GuiParam
from code_saturne.Base.QtPage import IntValidator, DoubleValidator, ComboModel, setGreenColor
from code_saturne.Pages.ThermalScalarModel import ThermalScalarModel
from code_saturne.Pages.DefineUserScalarsModel import DefineUserScalarsModel
from code_saturne.Pages.LocalizationModel import VolumicLocalizationModel, LocalizationModel
from code_saturne.Pages.SourceTermsModel import SourceTermsModel
from code_saturne.Pages.QMeiEditorView import QMeiEditorView
from code_saturne.Pages.OutputVolumicVariablesModel import OutputVolumicVariablesModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("InitializationView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Main class
#-------------------------------------------------------------------------------

class SourceTermsView(QWidget, Ui_SourceTermsForm):
    """
    """
    def __init__(self, parent, case, stbar):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_SourceTermsForm.__init__(self)
        self.setupUi(self)

        self.case = case
        self.case.undoStopGlobal()
        self.parent = parent

        self.mdl     = SourceTermsModel(self.case)
        self.therm   = ThermalScalarModel(self.case)
        self.th_sca  = DefineUserScalarsModel(self.case)
        self.volzone = LocalizationModel('VolumicZone', self.case)
        self.m_out   = OutputVolumicVariablesModel(self.case)


        # 0/ Read label names from XML file

        # Velocity

        # Thermal scalar
        namesca, unit = self.getThermalLabelAndUnit()
        self.th_sca_name = namesca

        # 1/ Combo box models

        self.modelSpecies = ComboModel(self.comboBoxSpecies, 1, 1)
        self.modelZone = ComboModel(self.comboBoxZone, 1, 1)

        self.zone = ""
        zones = self.volzone.getZones()
        for zone in zones:
            active = 0
            if (zone.getNature()['momentum_source_term'] == "on"):
                active = 1

            if ('thermal_source_term' in zone.getNature().keys()):
                if (zone.getNature()['thermal_source_term']  == "on"):
                    active = 1
            if ('scalar_source_term' in zone.getNature().keys()):
                if (zone.getNature()['scalar_source_term']  == "on"):
                    active = 1
            if (active):
                label = zone.getLabel()
                name = str(zone.getCodeNumber())
                self.modelZone.addItem(self.tr(label), name)
                if label == "all_cells":
                    self.zone = name
                if not self.zone:
                    self.zone = name
        self.modelZone.setItem(str_model = self.zone)

        # 2/ Connections

        self.connect(self.comboBoxZone,         SIGNAL("activated(const QString&)"),   self.slotZone)
        self.connect(self.comboBoxSpecies,      SIGNAL("activated(const QString&)"),   self.slotSpeciesChoice)
        self.connect(self.pushButtonMomentum,   SIGNAL("clicked()"),                   self.slotMomentumFormula)
        self.connect(self.pushButtonThermal,    SIGNAL("clicked()"),                   self.slotThermalFormula)
        self.connect(self.pushButtonSpecies,    SIGNAL("clicked()"),                   self.slotSpeciesFormula)

        # 3/ Initialize widget

        self.initialize(self.zone)

        self.case.undoStartGlobal()


    def initialize(self, zone_num):
        """
        Initialize widget when a new volumic zone is choosen
        """
        zone = self.case.xmlGetNode("zone", id=zone_num)

        if zone['momentum_source_term'] == "on":
            self.labelMomentum.show()
            self.pushButtonMomentum.show()
            setGreenColor(self.pushButtonMomentum, True)
        else:
            self.labelMomentum.hide()
            self.pushButtonMomentum.hide()

        if zone['thermal_source_term']  == "on":
            self.pushButtonThermal.show()
            self.labelThermal.show()
            setGreenColor(self.pushButtonThermal, True)
        else:
            self.pushButtonThermal.hide()
            self.labelThermal.hide()

        if zone['scalar_source_term']  == "on":
            self.comboBoxSpecies.show()
            self.pushButtonSpecies.show()
            self.labelSpecies.show()
            setGreenColor(self.pushButtonSpecies, True)
            self.scalar = ""
            scalar_list = self.th_sca.getUserScalarNameList()
            for s in self.th_sca.getScalarsVarianceList():
                if s in scalar_list: scalar_list.remove(s)
            if scalar_list != []:
                for scalar in scalar_list:
                    self.scalar = scalar
                    self.modelSpecies.addItem(self.tr(scalar),self.scalar)
                self.modelSpecies.setItem(str_model = self.scalar)

        else:
            self.comboBoxSpecies.hide()
            self.pushButtonSpecies.hide()
            self.labelSpecies.hide()


    @pyqtSignature("const QString&")
    def slotZone(self, text):
        """
        INPUT label for choice of zone
        """
        self.zone = self.modelZone.dicoV2M[str(text)]
        self.initialize(self.zone)


    @pyqtSignature("const QString&")
    def slotSpeciesChoice(self, text):
        """
        INPUT label for choice of zone
        """
        self.scalar= self.modelSpecies.dicoV2M[str(text)]
        setGreenColor(self.pushButtonSpecies, True)


    @pyqtSignature("const QString&")
    def slotMomentumFormula(self):
        """
        Set momentumFormula of the source term
        """
        exp = self.mdl.getMomentumFormula(self.zone)
        if not exp:
            exp = """Su = 0;\nSv = 0;\nSw = 0;\n
dSudu = 0;\ndSudv = 0;\ndSudw = 0;\n
dSvdu = 0;\ndSvdv = 0;\ndSvdw = 0;\n
dSwdu = 0;\ndSwdv = 0;\ndSwdw = 0;\n"""
        exa = """#example: """
        req = [('Su', "x velocity"),
               ('Sv', "y velocity"),
               ('Sw', "z velocity"),
               ('dSudu', "x component x velocity derivative"),
               ('dSudv', "x component y velocity derivative"),
               ('dSudw', "x component z velocity derivative"),
               ('dSvdu', "y component x velocity derivative"),
               ('dSvdv', "y component y velocity derivative"),
               ('dSvdw', "y component z velocity derivative"),
               ('dSwdu', "z component x velocity derivative"),
               ('dSwdv', "z component y velocity derivative"),
               ('dSwdw', "z component z velocity derivative")]
        sym = [('x', 'cell center coordinate'),
               ('y', 'cell center coordinate'),
               ('z', 'cell center coordinate')]

        sym.append( ("velocity[0]", 'X velocity component'))
        sym.append( ("velocity[1]", 'Y velocity component'))
        sym.append( ("velocity[2]", 'Z velocity component'))

        dialog = QMeiEditorView(self,
                                check_syntax = self.case['package'].get_check_syntax(),
                                expression = exp,
                                required   = req,
                                symbols    = sym,
                                examples   = exa)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotFormulaVelocity -> %s" % str(result))
            self.mdl.setMomentumFormula(self.zone, result)
            setGreenColor(self.sender(), False)


    @pyqtSignature("const QString&")
    def slotSpeciesFormula(self):
        """
        """
        exp = self.mdl.getSpeciesFormula(self.zone, self.scalar)
        if not exp:
            exp = """S = 0;\ndS = 0;\n"""
        exa = """#example: """
        req = [('S', 'species source term'),
               ('dS', 'species source term derivative')]
        sym = [('x', 'cell center coordinate'),
               ('y', 'cell center coordinate'),
               ('z', 'cell center coordinate')]

        name = self.th_sca.getScalarName(self.scalar)
        sym.append((name, 'current species'))

        dialog = QMeiEditorView(self,
                                check_syntax = self.case['package'].get_check_syntax(),
                                expression = exp,
                                required   = req,
                                symbols    = sym,
                                examples   = exa)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotFormulaSpecies -> %s" % str(result))
            self.mdl.setSpeciesFormula(self.zone, self.scalar, result)
            setGreenColor(self.sender(), False)


    def getThermalLabelAndUnit(self):
        """
        Define the type of model is used.
        """
        model = self.therm.getThermalScalarModel()

        if model != 'off':
            th_sca_name = self.therm.getThermalScalarName()
            if model == "temperature_celsius":
                unit = "<sup>o</sup>C"
            elif model == "temperature_kelvin":
                unit = "Kelvin"
            elif model == "enthalpy":
                unit = "J/kg"
        else:
            th_sca_name = ''
            unit = None

        self.th_sca_name = th_sca_name

        return th_sca_name, unit


    @pyqtSignature("const QString&")
    def slotThermalFormula(self):
        """
        Input the initial formula of thermal scalar
        """
        exp = self.mdl.getThermalFormula(self.zone, self.th_sca_name)
        if not exp:
            exp = self.mdl.getDefaultThermalFormula(self.th_sca_name)
        exa = """#example: """
        req = [('S', 'thermal source term'),
               ('dS', 'thermal source term derivative')]
        sym = [('x', 'cell center coordinate'),
               ('y', 'cell center coordinate'),
               ('z', 'cell center coordinate')]
        if self.therm.getThermalScalarModel() == 'enthalpy':
            sym.append(('enthalpy', 'thermal scalar'))
        if self.therm.getThermalScalarModel() == 'total_energy':
            sym.append(('total_energy', 'thermal scalar'))
        else:
            sym.append(('temperature', 'thermal scalar'))
        dialog = QMeiEditorView(self,
                                check_syntax = self.case['package'].get_check_syntax(),
                                expression = exp,
                                required   = req,
                                symbols    = sym,
                                examples   = exa)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotFormulaThermal -> %s" % str(result))
            self.mdl.setThermalFormula(self.zone, self.th_sca_name, result)
            setGreenColor(self.sender(), False)


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
