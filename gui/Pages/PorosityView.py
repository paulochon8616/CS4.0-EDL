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
This module defines the Porosity model data management.

This module contains the following classes:
- Porosity
- PorosityView
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
from code_saturne.Base.QtPage import ComboModel, setGreenColor
from code_saturne.Base.QtPage import to_qvariant, from_qvariant, to_text_string
from code_saturne.Pages.PorosityForm import Ui_PorosityForm
from code_saturne.Pages.LocalizationModel import LocalizationModel, Zone
from code_saturne.Pages.QMeiEditorView import QMeiEditorView
from code_saturne.Pages.PorosityModel import PorosityModel

#-------------------------------------------------------------------------------
# log config
#-------------------------------------------------------------------------------

logging.basicConfig()
log = logging.getLogger("PorosityView")
log.setLevel(GuiParam.DEBUG)

#-------------------------------------------------------------------------------
# StandarItemModel class to display Head Losses Zones in a QTreeView
#-------------------------------------------------------------------------------


class StandardItemModelPorosity(QStandardItemModel):
    def __init__(self):
        QStandardItemModel.__init__(self)
        self.headers = [self.tr("Label"), self.tr("Zone"),
                        self.tr("Selection criteria")]
        self.setColumnCount(len(self.headers))
        self.dataPorosityZones = []


    def data(self, index, role):
        if not index.isValid():
            return to_qvariant()
        if role == Qt.DisplayRole:
            return to_qvariant(self.dataPorosityZones[index.row()][index.column()])
        return to_qvariant()

    def flags(self, index):
        if not index.isValid():
            return Qt.ItemIsEnabled
        else:
            return Qt.ItemIsEnabled | Qt.ItemIsSelectable

    def headerData(self, section, orientation, role):
        if orientation == Qt.Horizontal and role == Qt.DisplayRole:
            return to_qvariant(self.headers[section])
        return to_qvariant()


    def setData(self, index, value, role):
        self.emit(SIGNAL("dataChanged(const QModelIndex &, const QModelIndex &)"), index, index)
        return True


    def insertItem(self, label, name, local):
        line = [label, name, local]
        self.dataPorosityZones.append(line)
        row = self.rowCount()
        self.setRowCount(row+1)


    def getItem(self, row):
        return self.dataPorosityZones[row]


#-------------------------------------------------------------------------------
# Main view class
#-------------------------------------------------------------------------------

class PorosityView(QWidget, Ui_PorosityForm):

    def __init__(self, parent, case):
        """
        Constructor
        """
        QWidget.__init__(self, parent)

        Ui_PorosityForm.__init__(self)
        self.setupUi(self)

        self.case = case
        self.case.undoStopGlobal()

        self.mdl = PorosityModel(self.case)

        # Create the Page layout.

        # Model and QTreeView for Head Losses
        self.modelPorosity = StandardItemModelPorosity()
        self.treeView.setModel(self.modelPorosity)

        # Combo model
        self.modelPorosityType = ComboModel(self.comboBoxType, 2, 1)
        self.modelPorosityType.addItem(self.tr("isotropic"), 'isotropic')
        self.modelPorosityType.addItem(self.tr("anisotropic"), 'anisotropic')

        # Connections
        self.connect(self.treeView,           SIGNAL("clicked(const QModelIndex &)"), self.slotSelectPorosityZones)
        self.connect(self.comboBoxType,       SIGNAL("activated(const QString&)"), self.slotPorosity)
        self.connect(self.pushButtonPorosity, SIGNAL("clicked()"), self.slotFormulaPorosity)

        # Initialize Widgets

        self.entriesNumber = -1
        d = self.mdl.getNameAndLocalizationZone()
        liste=[]
        liste=list(d.items())
        t=[]
        for t in liste :
            NamLoc=t[1]
            Lab=t[0 ]
            self.modelPorosity.insertItem(Lab, NamLoc[0],NamLoc[1])
        self.forgetStandardWindows()

        self.case.undoStartGlobal()


    @pyqtSignature("const QModelIndex&")
    def slotSelectPorosityZones(self, index):
        label, name, local = self.modelPorosity.getItem(index.row())

        if hasattr(self, "modelScalars"): del self.modelScalars
        log.debug("slotSelectPorosityZones label %s " % label )
        self.groupBoxType.show()
        self.groupBoxDef.show()

        choice = self.mdl.getPorosityModel(name)
        self.modelPorosityType.setItem(str_model=choice)

        setGreenColor(self.pushButtonPorosity, True)

        self.entriesNumber = index.row()


    def forgetStandardWindows(self):
        """
        For forget standard windows
        """
        self.groupBoxType.hide()
        self.groupBoxDef.hide()


    @pyqtSignature("const QString &")
    def slotPorosity(self, text):
        """
        Method to call 'getState' with correct arguements for 'rho'
        """
        label, name, local = self.modelPorosity.getItem(self.entriesNumber)
        choice = self.modelPorosityType.dicoV2M[str(text)]

        self.mdl.setPorosityModel(name, choice)


    @pyqtSignature("")
    def slotFormulaPorosity(self):
        """
        User formula for density
        """
        label, name, local = self.modelPorosity.getItem(self.entriesNumber)

        exp = self.mdl.getPorosityFormula(name)

        choice = self.mdl.getPorosityModel(name)

        if exp == None:
            exp = self.getDefaultPorosityFormula(choice)

        if choice == "isotropic":
            req = [('porosity', 'Porosity')]
        else:
            req = [('porosity', 'Porosity'),
                   ('porosity[XX]', 'Porosity'),
                   ('porosity[YY]', 'Porosity'),
                   ('porosity[ZZ]', 'Porosity'),
                   ('porosity[XY]', 'Porosity'),
                   ('porosity[XZ]', 'Porosity'),
                   ('porosity[YZ]', 'Porosity')]
        exa = """#example: \n""" + self.mdl.getDefaultPorosityFormula(choice)

        sym = [('x', 'cell center coordinate'),
               ('y', 'cell center coordinate'),
               ('z', 'cell center coordinate')]

        dialog = QMeiEditorView(self,
                                check_syntax = self.case['package'].get_check_syntax(),
                                expression = exp,
                                required   = req,
                                symbols    = sym,
                                examples   = exa)
        if dialog.exec_():
            result = dialog.get_result()
            log.debug("slotFormulaPorosity -> %s" % str(result))
            self.mdl.setPorosityFormula(name, result)
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
