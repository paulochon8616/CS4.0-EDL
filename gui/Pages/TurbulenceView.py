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
This module defines the turbulence model data management.

This module contains the following classes:
- TurbulenceAdvancedOptionsDialogView
- TurbulenceView
"""

#-------------------------------------------------------------------------------
# Library modules import
#-------------------------------------------------------------------------------

import sys, logging

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
from code_saturne.Pages.TurbulenceForm import Ui_TurbulenceForm
from code_saturne.Pages.TurbulenceAdvancedOptionsDialogForm import Ui_TurbulenceAdvancedOptionsDialogForm
from code_saturne.Pages.TurbulenceModel import TurbulenceModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("TurbulenceView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# Advanced dialog
#-------------------------------------------------------------------------------

class TurbulenceAdvancedOptionsDialogView(QDialog, Ui_TurbulenceAdvancedOptionsDialogForm):
    """
    Advanced dialog
    """
    def __init__(self, parent, case, default):
        """
        Constructor
        """
        QDialog.__init__(self, parent)

        Ui_TurbulenceAdvancedOptionsDialogForm.__init__(self)
        self.setupUi(self)

        self.case = case
        self.case.undoStopGlobal()

        if default['model'] in ('k-epsilon', 'k-epsilon-PL'):
            title = self.tr("Options for k-epsilon model")
        elif default['model'] in ('Rij-epsilon', 'Rij-SSG', 'Rij-EBRSM'):
            title = self.tr("Options for Rij-epsilon model")
        elif default['model'] == 'k-omega-SST':
            title = self.tr("Options for k-omega-SST model")
        elif default['model'] == 'v2f-BL-v2/k':
            title = self.tr("Options for v2f-BL-v2/k model")
        elif default['model'] == 'Spalart-Allmaras':
            title = self.tr("Options for Spalart-Allmaras model")
        self.setWindowTitle(title)
        self.default = default
        self.result  = self.default.copy()

        self.checkBoxGravity.setEnabled(True)
        self.comboBoxScales.setEnabled(True)

        if default['model'] == 'v2f-BL-v2/k' or \
           default['model'] == 'Rij-EBRSM':
            self.modelScales = ComboModel(self.comboBoxScales, 1, 1)
            self.modelScales.addItem(self.tr("One scale model"), '0')
            self.comboBoxScales.setEnabled(False)
        elif default['model'] == 'Spalart-Allmaras':
            self.modelScales = ComboModel(self.comboBoxScales, 1, 1)
            self.modelScales.addItem(self.tr("One scale model"), '0')
            self.comboBoxScales.setEnabled(False)
        else:
            # Combo
            self.modelScales = ComboModel(self.comboBoxScales, 3, 1)

            self.modelScales.addItem(self.tr("One scale model"), '0')
            self.modelScales.addItem(self.tr("Two scale model"), '1')
            self.modelScales.addItem(self.tr("Scalable wall function"), '2')

            # Initialization of wall function model
            self.modelScales.setItem(str_model=str(self.result['scale_model']))

        # Initialization of gravity terms
        if self.result['gravity_terms'] == 'on':
            self.checkBoxGravity.setChecked(True)
        else:
            self.checkBoxGravity.setChecked(False)

        self.case.undoStartGlobal()


    def get_result(self):
        """
        Method to get the result
        """
        return self.result


    def accept(self):
        """
        Method called when user clicks 'OK'
        """
        if self.checkBoxGravity.isChecked():
            self.result['gravity_terms'] = "on"
        else:
            self.result['gravity_terms'] = "off"
        self.result['scale_model'] = \
        int(self.modelScales.dicoV2M[str(self.comboBoxScales.currentText())])

        QDialog.accept(self)


    def reject(self):
        """
        Method called when user clicks 'Cancel'
        """
        QDialog.reject(self)


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# Main view class
#-------------------------------------------------------------------------------

class TurbulenceView(QWidget, Ui_TurbulenceForm):
    """
    Class to open Turbulence Page.
    """
    def __init__(self, parent=None, case=None):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_TurbulenceForm.__init__(self)
        self.setupUi(self)

        self.case = case
        self.case.undoStopGlobal()
        self.model = TurbulenceModel(self.case)

        # Combo model

        self.modelTurbModel = ComboModel(self.comboBoxTurbModel,10,1)

        self.modelTurbModel.addItem(self.tr("No model (i.e. laminar flow)"), "off")
        self.modelTurbModel.addItem(self.tr("Mixing length"), "mixing_length")
        self.modelTurbModel.addItem(self.tr("k-epsilon"), "k-epsilon")
        self.modelTurbModel.addItem(self.tr("k-epsilon Linear Production"), "k-epsilon-PL")
        self.modelTurbModel.addItem(self.tr("Rij-epsilon LRR"), "Rij-epsilon")
        self.modelTurbModel.addItem(self.tr("Rij-epsilon SSG"), "Rij-SSG")
        self.modelTurbModel.addItem(self.tr("Rij-epsilon EBRSM"), "Rij-EBRSM")
        self.modelTurbModel.addItem(self.tr("v2f BL-v2/k"), "v2f-BL-v2/k")
        self.modelTurbModel.addItem(self.tr("k-omega SST"), "k-omega-SST")
        self.modelTurbModel.addItem(self.tr("Spalart-Allmaras"), "Spalart-Allmaras")
        self.modelTurbModel.addItem(self.tr("LES (Smagorinsky)"), "LES_Smagorinsky")
        self.modelTurbModel.addItem(self.tr("LES (classical dynamic model)"), "LES_dynamique")
        self.modelTurbModel.addItem(self.tr("LES (WALE)"), "LES_WALE")

        # Connections

        self.connect(self.comboBoxTurbModel, SIGNAL("activated(const QString&)"), self.slotTurbulenceModel)
        self.connect(self.pushButtonAdvanced, SIGNAL("clicked()"), self.slotAdvancedOptions)
        self.connect(self.lineEditLength, SIGNAL("textChanged(const QString &)"), self.slotLengthScale)

        # Frames display

        self.frameAdvanced.hide()
        self.frameLength.hide()

        # Validator

        validator = DoubleValidator(self.lineEditLength, min=0.0)
        validator.setExclusiveMin(True)
        self.lineEditLength.setValidator(validator)


        # Update the turbulence models list with the calculation features

        for turb in self.model.turbulenceModels():
            if turb not in self.model.turbulenceModelsList():
                self.modelTurbModel.disableItem(str_model=turb)

        # Select the turbulence model

        model = self.model.getTurbulenceModel()
        self.modelTurbModel.setItem(str_model=model)
        self.slotTurbulenceModel(self.comboBoxTurbModel.currentText())

        # Length scale

        l_scale = self.model.getLengthScale()
        self.lineEditLength.setText(str(l_scale))

        self.case.undoStartGlobal()


    @pyqtSignature("const QString&")
    def slotLengthScale(self, text):
        """
        Private slot.
        Input XLOMLG.
        """
        if self.sender().validator().state == QValidator.Acceptable:
            l_scale = from_qvariant(text, float)
            self.model.setLengthScale(l_scale)


    @pyqtSignature("const QString&")
    def slotTurbulenceModel(self, text):
        """
        Private slot.
        Input ITURB.
        """
        model = self.modelTurbModel.dicoV2M[str(text)]
        self.model.setTurbulenceModel(model)

        self.frameAdvanced.hide()
        self.frameLength.hide()

        if model == 'mixing_length':
            self.frameLength.show()
            self.frameAdvanced.hide()
            self.model.getLengthScale()
        elif model not in ('off', 'LES_Smagorinsky', 'LES_dynamique', 'LES_WALE', 'Spalart-Allmaras'):
            self.frameLength.hide()
            self.frameAdvanced.show()

        if model in ('off', 'LES_Smagorinsky', 'LES_dynamique', 'LES_WALE', 'Spalart-Allmaras'):
            self.line.hide()
        else:
            self.line.show()


    @pyqtSignature("")
    def slotAdvancedOptions(self):
        """
        Private slot.
        Ask one popup for advanced specifications
        """
        default = {}
        default['model']         = self.model.getTurbulenceModel()
        default['scale_model']   = self.model.getScaleModel()
        default['gravity_terms'] = self.model.getGravity()
        log.debug("slotAdvancedOptions -> %s" % str(default))

        dialog = TurbulenceAdvancedOptionsDialogView(self, self.case, default)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotAdvancedOptions -> %s" % str(result))
            self.model.setTurbulenceModel(result['model'])
            self.model.setScaleModel(result['scale_model'])
            self.model.setGravity(result['gravity_terms'])


    def tr(self, text):
        """
        Translation
        """
        return text

#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
